import Foundation
import OSLog
import SwiftData
import ZIPFoundation

/// Builds and reads Burrow backup packages: a zip holding `data.json` plus a
/// `media/` folder with the actual pictures, audio and video files.
enum ExportImportService {
    enum Scope: Equatable {
        case everything
        case profile(UUID)
    }

    /// What to do when the device already holds profiles or tiles.
    enum ImportStrategy: Equatable {
        /// Add what is missing and leave existing records untouched.
        case merge
        /// Remove everything first, then insert the package as-is.
        case replace
    }

    enum ExportImportError: LocalizedError {
        case couldNotPrepareWorkspace(String)
        case couldNotWriteArchive(String)
        case couldNotReadArchive(String)
        case missingDataFile
        case unsupportedFormat(Int)

        var errorDescription: String? {
            switch self {
            case .couldNotPrepareWorkspace(let detail):
                return String(
                    localized: "Burrow could not prepare the export: \(detail)",
                    comment: "Export failure"
                )
            case .couldNotWriteArchive(let detail):
                return String(
                    localized: "Burrow could not write the backup file: \(detail)",
                    comment: "Export failure"
                )
            case .couldNotReadArchive(let detail):
                return String(
                    localized: "Burrow could not read this backup: \(detail)",
                    comment: "Import failure"
                )
            case .missingDataFile:
                return String(
                    localized: "This file is not a Burrow backup.",
                    comment: "Import failure"
                )
            case .unsupportedFormat(let version):
                return String(
                    localized: "This backup was made with a newer version of Burrow (format \(version)).",
                    comment: "Import failure"
                )
            }
        }
    }

    /// Summary of what an import would bring in, shown before anything changes.
    struct ImportPreview: Equatable {
        var profileCount: Int
        var tileCount: Int
        var mediaItemCount: Int
        var exportedAt: Date
    }

    private static let logger = Logger(subsystem: "com.pvd.burrow", category: "ExportImport")
    private static let fileManager = FileManager.default

    // MARK: - Export

    /// Writes a complete package and returns the archive URL. Every export is
    /// built from scratch; there are no incremental backups.
    @MainActor
    static func export(scope: Scope, context: ModelContext, now: Date = Date()) throws -> URL {
        let workspace = try makeWorkspace()
        defer { try? fileManager.removeItem(at: workspace.root) }

        let profiles = try fetchProfiles(scope: scope, context: context)
        let tiles = try fetchTiles(scope: scope, profiles: profiles, context: context)

        var tileRecords: [ExportPackage.TileRecord] = []
        tileRecords.reserveCapacity(tiles.count)

        for tile in tiles {
            var imageFileName: String?
            if !tile.imageData.isEmpty {
                let name = "tile-\(tile.id.uuidString).img"
                let destination = workspace.media.appending(path: name, directoryHint: .notDirectory)
                do {
                    try tile.imageData.write(to: destination, options: .atomic)
                    imageFileName = name
                } catch {
                    logger.error("Could not write tile artwork: \(error.localizedDescription, privacy: .public)")
                }
            }

            for item in tile.orderedMediaItems {
                guard let fileName = item.localFileName, !fileName.isEmpty else { continue }
                let source = MediaLibrary.shared.url(forFileNamed: fileName)
                guard fileManager.fileExists(atPath: source.path(percentEncoded: false)) else { continue }
                let destination = workspace.media.appending(path: fileName, directoryHint: .notDirectory)
                if !fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
                    try? fileManager.copyItem(at: source, to: destination)
                }
            }

            tileRecords.append(ExportPackage.TileRecord(tile: tile, imageFileName: imageFileName))
        }

        let package = ExportPackage(
            exportedAt: now,
            profiles: profiles.map(ExportPackage.ProfileRecord.init(profile:)),
            tiles: tileRecords
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(package)
            try data.write(
                to: workspace.root.appending(path: ExportPackage.dataFileName, directoryHint: .notDirectory),
                options: .atomic
            )
        } catch {
            throw ExportImportError.couldNotPrepareWorkspace(error.localizedDescription)
        }

        let archiveURL = exportsDirectory().appending(
            path: archiveName(now: now),
            directoryHint: .notDirectory
        )
        try? fileManager.removeItem(at: archiveURL)

        do {
            try fileManager.zipItem(at: workspace.root, to: archiveURL, shouldKeepParent: false)
        } catch {
            throw ExportImportError.couldNotWriteArchive(error.localizedDescription)
        }

        return archiveURL
    }

    // MARK: - Import

    /// Unpacks an archive and reads its manifest without changing anything yet.
    static func inspect(archiveAt url: URL) throws -> (package: ExportPackage, unpackedRoot: URL, preview: ImportPreview) {
        let needsScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if needsScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let destination = importsDirectory().appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )

        do {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
            try fileManager.unzipItem(at: url, to: destination)
        } catch {
            throw ExportImportError.couldNotReadArchive(error.localizedDescription)
        }

        let dataURL = destination.appending(path: ExportPackage.dataFileName, directoryHint: .notDirectory)
        guard fileManager.fileExists(atPath: dataURL.path(percentEncoded: false)) else {
            throw ExportImportError.missingDataFile
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let package: ExportPackage
        do {
            let data = try Data(contentsOf: dataURL)
            package = try decoder.decode(ExportPackage.self, from: data)
        } catch {
            throw ExportImportError.couldNotReadArchive(error.localizedDescription)
        }

        guard package.formatVersion <= ExportPackage.currentFormatVersion else {
            throw ExportImportError.unsupportedFormat(package.formatVersion)
        }

        let preview = ImportPreview(
            profileCount: package.profiles.count,
            tileCount: package.tiles.count,
            mediaItemCount: package.tiles.reduce(0) { $0 + $1.mediaItems.count },
            exportedAt: package.exportedAt
        )

        return (package, destination, preview)
    }

    /// Applies a previously inspected package.
    @MainActor
    static func apply(
        package: ExportPackage,
        unpackedRoot: URL,
        strategy: ImportStrategy,
        context: ModelContext
    ) throws {
        defer { try? fileManager.removeItem(at: unpackedRoot) }

        let mediaRoot = unpackedRoot.appending(path: ExportPackage.mediaFolderName, directoryHint: .isDirectory)

        if strategy == .replace {
            try removeEverything(in: context)
        }

        let existingProfileIDs = Set(try context.fetch(FetchDescriptor<ChildProfile>()).map(\.id))
        let existingTileIDs = Set(try context.fetch(FetchDescriptor<Tile>()).map(\.id))

        for record in package.profiles where !existingProfileIDs.contains(record.id) {
            context.insert(record.makeModel())
        }

        for record in package.tiles where !existingTileIDs.contains(record.id) {
            let imageData = imageData(for: record, in: mediaRoot)

            let tile = Tile(
                id: record.id,
                title: record.title,
                imageData: imageData,
                category: record.resolvedCategory,
                ownerProfileID: record.ownerProfileID,
                sortOrder: record.sortOrder,
                shufflePlaylist: record.shufflePlaylist,
                loopPlaylist: record.loopPlaylist,
                isHidden: record.isHidden
            )
            context.insert(tile)

            for itemRecord in record.mediaItems.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                let storedName = adoptedFileName(for: itemRecord, in: mediaRoot)
                let item = MediaItem(
                    id: itemRecord.id,
                    type: itemRecord.resolvedType,
                    title: itemRecord.title,
                    localFileName: storedName,
                    youtubeVideoID: itemRecord.youtubeVideoID,
                    appleMusicItemID: itemRecord.appleMusicItemID,
                    sortOrder: itemRecord.sortOrder
                )
                context.insert(item)
                // `append` also enforces that the source type fits the category.
                if !tile.append(item) {
                    context.delete(item)
                }
            }
        }

        if let error = ModelSaver.save(context, describing: "importing a backup") {
            throw error
        }
    }

    // MARK: - Helpers

    private static func imageData(for record: ExportPackage.TileRecord, in mediaRoot: URL) -> Data {
        guard let name = record.imageFileName else { return Data() }
        let url = mediaRoot.appending(path: name, directoryHint: .notDirectory)
        return (try? Data(contentsOf: url)) ?? Data()
    }

    private static func adoptedFileName(for record: ExportPackage.MediaItemRecord, in mediaRoot: URL) -> String? {
        guard let fileName = record.localFileName, !fileName.isEmpty else { return nil }
        let source = mediaRoot.appending(path: fileName, directoryHint: .notDirectory)
        guard fileManager.fileExists(atPath: source.path(percentEncoded: false)) else { return nil }

        if MediaLibrary.shared.fileExists(named: fileName) {
            // Already present from an earlier import or from this device.
            return fileName
        }
        return try? MediaLibrary.shared.adoptFile(at: source, preferredName: fileName)
    }

    @MainActor
    private static func removeEverything(in context: ModelContext) throws {
        let tiles = try context.fetch(FetchDescriptor<Tile>())
        for tile in tiles {
            TrashService.permanentlyDelete(tile, in: context)
        }
        try context.delete(model: ChildProfile.self)
        try context.delete(model: UsageSession.self)
    }

    @MainActor
    private static func fetchProfiles(scope: Scope, context: ModelContext) throws -> [ChildProfile] {
        let all = try context.fetch(
            FetchDescriptor<ChildProfile>(sortBy: [SortDescriptor(\.sortOrder)])
        )
        switch scope {
        case .everything:
            return all
        case .profile(let id):
            return all.filter { $0.id == id }
        }
    }

    @MainActor
    private static func fetchTiles(
        scope: Scope,
        profiles: [ChildProfile],
        context: ModelContext
    ) throws -> [Tile] {
        let all = try context.fetch(
            FetchDescriptor<Tile>(sortBy: [SortDescriptor(\.sortOrder)])
        ).filter { !$0.isTrashed }

        switch scope {
        case .everything:
            return all
        case .profile(let id):
            // A single-profile export carries the tiles this profile owns plus
            // the shared ones it can see, so the package is self-contained.
            let visible = Set(profiles.first { $0.id == id }?.visibleSharedTileIDs ?? [])
            return all.filter { $0.ownerProfileID == id || visible.contains($0.id) }
        }
    }

    private static func makeWorkspace() throws -> (root: URL, media: URL) {
        let root = fileManager.temporaryDirectory.appending(
            path: "BurrowExport-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        let media = root.appending(path: ExportPackage.mediaFolderName, directoryHint: .isDirectory)
        do {
            try fileManager.createDirectory(at: media, withIntermediateDirectories: true)
        } catch {
            throw ExportImportError.couldNotPrepareWorkspace(error.localizedDescription)
        }
        return (root, media)
    }

    private static func exportsDirectory() -> URL {
        let url = fileManager.temporaryDirectory.appending(path: "Exports", directoryHint: .isDirectory)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func importsDirectory() -> URL {
        let url = fileManager.temporaryDirectory.appending(path: "Imports", directoryHint: .isDirectory)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func archiveName(now: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "Burrow-\(formatter.string(from: now)).zip"
    }
}

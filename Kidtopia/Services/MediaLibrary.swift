import Foundation
import OSLog

/// Errors raised while copying media into, or reading media out of, the app's
/// own storage.
enum MediaLibraryError: LocalizedError {
    case couldNotAccessSourceFile
    case couldNotCopyFile(underlying: String)
    case fileMissing(name: String)

    var errorDescription: String? {
        switch self {
        case .couldNotAccessSourceFile:
            return String(
                localized: "Kidtopia could not open that file.",
                comment: "Media import failure"
            )
        case .couldNotCopyFile(let underlying):
            return String(
                localized: "Kidtopia could not save that file: \(underlying)",
                comment: "Media import failure with system message"
            )
        case .fileMissing(let name):
            return String(
                localized: "The file \(name) is no longer on this device.",
                comment: "Media playback failure, local file gone"
            )
        }
    }
}

/// Stores imported audio and video inside the app's Documents directory.
///
/// Only the relative file name is persisted on `MediaItem`, so the store stays
/// small and the same JSON export works on any device.
struct MediaLibrary {
    static let shared = MediaLibrary()

    private static let directoryName = "Media"
    private let logger = Logger(subsystem: "com.pvd.kidtopia", category: "MediaLibrary")
    private let fileManager = FileManager.default

    /// `Documents/Media`, created on first use.
    var directoryURL: URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL.temporaryDirectory
        return documents.appending(path: Self.directoryName, directoryHint: .isDirectory)
    }

    func ensureDirectoryExists() {
        let url = directoryURL
        guard !fileManager.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            logger.error("Could not create the media directory: \(error.localizedDescription, privacy: .public)")
        }
    }

    func url(forFileNamed name: String) -> URL {
        directoryURL.appending(path: name, directoryHint: .notDirectory)
    }

    func fileExists(named name: String) -> Bool {
        fileManager.fileExists(atPath: url(forFileNamed: name).path(percentEncoded: false))
    }

    /// Copies a file the parent picked (usually security scoped) into the app's
    /// media directory and returns the stored file name.
    func importFile(from sourceURL: URL) throws -> String {
        ensureDirectoryExists()

        let needsScopedAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if needsScopedAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard fileManager.isReadableFile(atPath: sourceURL.path(percentEncoded: false)) else {
            throw MediaLibraryError.couldNotAccessSourceFile
        }

        let storedName = uniqueFileName(basedOn: sourceURL)
        let destination = url(forFileNamed: storedName)

        do {
            try fileManager.copyItem(at: sourceURL, to: destination)
        } catch {
            throw MediaLibraryError.couldNotCopyFile(underlying: error.localizedDescription)
        }

        return storedName
    }

    /// Copies a file that is already inside an unpacked import package.
    func adoptFile(at sourceURL: URL, preferredName: String) throws -> String {
        ensureDirectoryExists()

        var storedName = preferredName
        if fileExists(named: storedName) {
            storedName = uniqueFileName(basedOn: sourceURL)
        }

        do {
            try fileManager.copyItem(at: sourceURL, to: url(forFileNamed: storedName))
        } catch {
            throw MediaLibraryError.couldNotCopyFile(underlying: error.localizedDescription)
        }
        return storedName
    }

    func deleteFile(named name: String) {
        let target = url(forFileNamed: name)
        guard fileManager.fileExists(atPath: target.path(percentEncoded: false)) else { return }
        do {
            try fileManager.removeItem(at: target)
        } catch {
            logger.error("Could not delete \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Every file currently stored, used by the export flow.
    func allFileNames() -> [String] {
        let url = directoryURL
        guard let contents = try? fileManager.contentsOfDirectory(atPath: url.path(percentEncoded: false)) else {
            return []
        }
        return contents.sorted()
    }

    private func uniqueFileName(basedOn sourceURL: URL) -> String {
        let fileExtension = sourceURL.pathExtension
        let base = UUID().uuidString
        return fileExtension.isEmpty ? base : "\(base).\(fileExtension)"
    }
}

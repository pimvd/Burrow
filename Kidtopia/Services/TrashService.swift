import Foundation
import OSLog
import SwiftData

/// Handles the 14-day trash for tiles.
///
/// The retention period is fixed and not configurable. When a tile is purged its
/// usage statistics and its local media files go with it.
enum TrashService {
    static let retentionDays = 14

    private static let logger = Logger(subsystem: "com.pvd.kidtopia", category: "Trash")

    static func expiryDate(for trashedAt: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: retentionDays, to: trashedAt) ?? trashedAt
    }

    static func daysRemaining(for tile: Tile, now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let trashedAt = tile.trashedAt else { return retentionDays }
        let expiry = expiryDate(for: trashedAt, calendar: calendar)
        let days = calendar.dateComponents([.day], from: now, to: expiry).day ?? 0
        return max(0, days)
    }

    /// Deletes tiles whose retention period has passed, together with their
    /// usage sessions and media files. Safe to call on every app launch and
    /// whenever the parent area opens.
    static func purgeExpiredTiles(in context: ModelContext, now: Date = Date(), calendar: Calendar = .current) {
        let descriptor = FetchDescriptor<Tile>(predicate: #Predicate { $0.isTrashed })

        do {
            let trashed = try context.fetch(descriptor)
            let expired = trashed.filter { tile in
                guard let trashedAt = tile.trashedAt else { return false }
                return expiryDate(for: trashedAt, calendar: calendar) <= now
            }
            guard !expired.isEmpty else { return }

            for tile in expired {
                permanentlyDelete(tile, in: context)
            }
            ModelSaver.save(context, describing: "purging expired tiles")
        } catch {
            logger.error("Could not read the trash: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Removes a tile for good: its media items, its local files, its statistics
    /// and every reference other profiles had to it.
    static func permanentlyDelete(_ tile: Tile, in context: ModelContext) {
        let tileID = tile.id

        for item in tile.orderedMediaItems {
            if let fileName = item.localFileName, !fileName.isEmpty {
                MediaLibrary.shared.deleteFile(named: fileName)
            }
        }

        deleteUsageSessions(forTileID: tileID, in: context)
        removeSharingReferences(toTileID: tileID, in: context)

        TileImageCache.shared.invalidate(tileID: tileID)
        context.delete(tile)
    }

    /// Statistics move to the trash with the tile and are removed together with
    /// it, so a purge never leaves orphaned rows behind.
    private static func deleteUsageSessions(forTileID tileID: UUID, in context: ModelContext) {
        do {
            try context.delete(model: UsageSession.self, where: #Predicate { $0.tileID == tileID })
        } catch {
            logger.error("Could not delete usage data: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func removeSharingReferences(toTileID tileID: UUID, in context: ModelContext) {
        do {
            let profiles = try context.fetch(FetchDescriptor<ChildProfile>())
            for profile in profiles where profile.visibleSharedTileIDs.contains(tileID) {
                profile.visibleSharedTileIDs.removeAll { $0 == tileID }
                profile.lastModified = Date()
            }
        } catch {
            logger.error("Could not update sharing: \(error.localizedDescription, privacy: .public)")
        }
    }
}

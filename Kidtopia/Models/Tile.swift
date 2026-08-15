import Foundation
import SwiftData

/// A large tappable card in the child interface. Opening a tile starts its
/// single-type playlist. Tiles are created and maintained by the parent only.
@Model
final class Tile {
    var id: UUID = UUID()
    var title: String = ""

    /// PNG/JPEG data of the tile artwork. Stored outside the database file so
    /// large images do not bloat the store.
    @Attribute(.externalStorage) var imageData: Data = Data()

    /// Stored as the raw value of `TileCategory` so the CloudKit schema stays a
    /// plain string. Use `category` to read and write it.
    var categoryRawValue: String = TileCategory.music.rawValue

    /// The profile that owns this tile. Other profiles can be given visibility
    /// through `ChildProfile.visibleSharedTileIDs`.
    var ownerProfileID: UUID = UUID()

    @Relationship(deleteRule: .cascade, inverse: \MediaItem.tile)
    var mediaItems: [MediaItem]?

    var sortOrder: Int = 0
    var shufflePlaylist: Bool = false
    var loopPlaylist: Bool = true

    /// Only meaningful for `.video` tiles containing YouTube items. When `false`
    /// the web view is kept off screen so only the audio is heard.
    var showYouTubeAsVideo: Bool = true

    /// The parent can temporarily hide a tile from the child view.
    var isHidden: Bool = false

    /// Soft delete. Named `isTrashed` rather than `isDeleted` because
    /// `PersistentModel` already vends an `isDeleted` property.
    var isTrashed: Bool = false
    var trashedAt: Date?

    /// Which playlist entry played last, so reopening the tile continues there.
    /// Playback of that entry always restarts at 0:00.
    var lastPlayedItemID: UUID?

    var lastModified: Date = Date()

    init(
        id: UUID = UUID(),
        title: String,
        imageData: Data = Data(),
        category: TileCategory,
        ownerProfileID: UUID,
        mediaItems: [MediaItem] = [],
        sortOrder: Int = 0,
        shufflePlaylist: Bool = false,
        loopPlaylist: Bool = true,
        showYouTubeAsVideo: Bool = true,
        isHidden: Bool = false,
        isTrashed: Bool = false,
        trashedAt: Date? = nil,
        lastPlayedItemID: UUID? = nil,
        lastModified: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.imageData = imageData
        self.categoryRawValue = category.rawValue
        self.ownerProfileID = ownerProfileID
        self.mediaItems = mediaItems
        self.sortOrder = sortOrder
        self.shufflePlaylist = shufflePlaylist
        self.loopPlaylist = loopPlaylist
        self.showYouTubeAsVideo = showYouTubeAsVideo
        self.isHidden = isHidden
        self.isTrashed = isTrashed
        self.trashedAt = trashedAt
        self.lastPlayedItemID = lastPlayedItemID
        self.lastModified = lastModified
    }
}

extension Tile {
    /// The tile category. Fixed at creation: the parent management UI never
    /// offers a way to change it, only to delete and recreate the tile.
    var category: TileCategory {
        TileCategory(rawValue: categoryRawValue) ?? .music
    }

    /// Playlist entries in the order the parent arranged them.
    var orderedMediaItems: [MediaItem] {
        (mediaItems ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    var mediaItemCount: Int { mediaItems?.count ?? 0 }

    /// `true` when every entry in this tile needs a network connection, which
    /// means the tile has to be hidden from the child while offline.
    var requiresNetwork: Bool {
        let items = orderedMediaItems
        guard !items.isEmpty else { return false }
        return items.allSatisfy { $0.type.requiresNetwork }
    }

    /// Errors recorded during playback, surfaced in the parent view only.
    var itemsWithErrors: [MediaItem] {
        orderedMediaItems.filter { $0.lastKnownErrorMessage?.isEmpty == false }
    }

    func canAdd(sourceType: MediaSourceType) -> Bool {
        category.allows(sourceType)
    }

    /// Appends an entry, keeping `sortOrder` contiguous. Returns `false` when the
    /// source type does not match the tile category.
    @discardableResult
    func append(_ item: MediaItem) -> Bool {
        guard canAdd(sourceType: item.type) else { return false }
        item.sortOrder = (orderedMediaItems.last?.sortOrder ?? -1) + 1
        var items = mediaItems ?? []
        items.append(item)
        mediaItems = items
        lastModified = Date()
        return true
    }

    func normalizeMediaItemOrder() {
        for (index, item) in orderedMediaItems.enumerated() where item.sortOrder != index {
            item.sortOrder = index
        }
    }

    func moveToTrash(on date: Date = Date()) {
        isTrashed = true
        trashedAt = date
        lastModified = date
    }

    func restoreFromTrash() {
        isTrashed = false
        trashedAt = nil
        lastModified = Date()
    }
}

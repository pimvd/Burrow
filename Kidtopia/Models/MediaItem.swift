import Foundation
import SwiftData

/// One entry in a tile's playlist.
@Model
final class MediaItem {
    var id: UUID = UUID()

    /// Raw value of `MediaSourceType`; use `type` to read and write it.
    var typeRawValue: String = MediaSourceType.localAudio.rawValue

    var title: String = ""

    /// Relative path inside the app's media directory, for `.localAudio` and
    /// `.localVideo` entries.
    var localFileName: String?

    var youtubeVideoID: String?
    var appleMusicItemID: String?
    var sortOrder: Int = 0

    /// Last playback failure for this entry, for example "Video unavailable".
    /// Shown as a badge in the parent management view and never to the child.
    var lastKnownErrorMessage: String?

    var lastModified: Date = Date()

    /// Inverse of `Tile.mediaItems`.
    var tile: Tile?

    init(
        id: UUID = UUID(),
        type: MediaSourceType,
        title: String,
        localFileName: String? = nil,
        youtubeVideoID: String? = nil,
        appleMusicItemID: String? = nil,
        sortOrder: Int = 0,
        lastKnownErrorMessage: String? = nil,
        lastModified: Date = Date()
    ) {
        self.id = id
        self.typeRawValue = type.rawValue
        self.title = title
        self.localFileName = localFileName
        self.youtubeVideoID = youtubeVideoID
        self.appleMusicItemID = appleMusicItemID
        self.sortOrder = sortOrder
        self.lastKnownErrorMessage = lastKnownErrorMessage
        self.lastModified = lastModified
    }
}

extension MediaItem {
    var type: MediaSourceType {
        get { MediaSourceType(rawValue: typeRawValue) ?? .localAudio }
        set { typeRawValue = newValue.rawValue }
    }

    /// `true` when the entry has everything it needs to be played.
    var isPlayable: Bool {
        switch type {
        case .localAudio, .localVideo:
            return localFileName?.isEmpty == false
        case .youtube:
            return youtubeVideoID?.isEmpty == false
        case .appleMusic:
            return appleMusicItemID?.isEmpty == false
        }
    }

    func recordError(_ message: String) {
        lastKnownErrorMessage = message
        lastModified = Date()
    }

    func clearError() {
        guard lastKnownErrorMessage != nil else { return }
        lastKnownErrorMessage = nil
        lastModified = Date()
    }
}

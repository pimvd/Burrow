import Foundation

/// A snapshot of one playlist entry, taken from a `MediaItem` when playback
/// starts. Using a value type keeps the playback service free of SwiftData
/// objects and safe to hand to views.
struct PlaybackEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let type: MediaSourceType
    let title: String
    let localFileName: String?
    let youtubeVideoID: String?
    let appleMusicItemID: String?

    init(mediaItem: MediaItem) {
        id = mediaItem.id
        type = mediaItem.type
        title = mediaItem.title
        localFileName = mediaItem.localFileName
        youtubeVideoID = mediaItem.youtubeVideoID
        appleMusicItemID = mediaItem.appleMusicItemID
    }
}

/// What happens when the playlist runs out, cycled by the repeat button in the
/// player the way Apple Music does it: off, the whole list, one entry.
enum RepeatMode: Equatable, Sendable {
    case off
    case all
    case one

    /// The mode one tap of the repeat button moves to.
    var next: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }
}

/// Everything the playback service needs to run one tile.
struct PlaybackPlaylist: Equatable, Sendable {
    let tileID: UUID
    let tileTitle: String
    let category: TileCategory
    let entries: [PlaybackEntry]
    let shuffle: Bool
    let loop: Bool
    let showYouTubeAsVideo: Bool

    /// The entry the tile stopped on last time, so reopening continues there.
    /// The entry itself always restarts at 0:00.
    let startEntryID: UUID?

    /// Mirrors `ChildProfile.lockScreenPlaybackEnabled`.
    let allowsLockScreenPlayback: Bool

    let profileID: UUID

    init(tile: Tile, profile: ChildProfile) {
        tileID = tile.id
        tileTitle = tile.title
        category = tile.category
        entries = tile.orderedMediaItems.map(PlaybackEntry.init(mediaItem:))
        shuffle = tile.shufflePlaylist
        loop = tile.loopPlaylist
        showYouTubeAsVideo = tile.category.showsYouTubeVideo
        startEntryID = tile.lastPlayedItemID
        allowsLockScreenPlayback = profile.lockScreenPlaybackEnabled
        profileID = profile.id
    }
}

import Foundation

/// The JSON half of an export package.
///
/// Binary data never goes into the JSON itself. Pictures and media files are
/// written next to it in a `media/` folder and referenced by file name, so the
/// package stays readable and reasonably small.
struct ExportPackage: Codable, Equatable {
    static let currentFormatVersion = 1
    static let dataFileName = "data.json"
    static let mediaFolderName = "media"

    var formatVersion: Int = ExportPackage.currentFormatVersion
    var exportedAt: Date
    var profiles: [ProfileRecord]
    var tiles: [TileRecord]

    struct ProfileRecord: Codable, Equatable {
        var id: UUID
        var name: String
        var avatarIconName: String
        var colorThemeName: String
        var sortOrder: Int
        var ageYears: Int
        var dailyScreenTimeLimitMinutes: Int?
        var lockScreenPlaybackEnabled: Bool
        var visibleSharedTileIDs: [UUID]

        init(profile: ChildProfile) {
            id = profile.id
            name = profile.name
            avatarIconName = profile.avatarIconName
            colorThemeName = profile.colorThemeName
            sortOrder = profile.sortOrder
            ageYears = profile.ageYears
            dailyScreenTimeLimitMinutes = profile.dailyScreenTimeLimitMinutes
            lockScreenPlaybackEnabled = profile.lockScreenPlaybackEnabled
            visibleSharedTileIDs = profile.visibleSharedTileIDs
        }

        func makeModel() -> ChildProfile {
            ChildProfile(
                id: id,
                name: name,
                avatarIconName: avatarIconName,
                colorThemeName: colorThemeName,
                sortOrder: sortOrder,
                ageYears: ageYears,
                dailyScreenTimeLimitMinutes: dailyScreenTimeLimitMinutes,
                lockScreenPlaybackEnabled: lockScreenPlaybackEnabled,
                visibleSharedTileIDs: visibleSharedTileIDs
            )
        }
    }

    struct TileRecord: Codable, Equatable {
        var id: UUID
        var title: String
        /// File name inside `media/`, or `nil` when the tile has no picture.
        var imageFileName: String?
        var category: String
        var ownerProfileID: UUID
        var sortOrder: Int
        var shufflePlaylist: Bool
        var loopPlaylist: Bool
        /// Legacy: packages written before YouTube audio-only became a property
        /// of the tile category still carry this. Decoded so old files import,
        /// never written and never read.
        var showYouTubeAsVideo: Bool?
        var isHidden: Bool
        var mediaItems: [MediaItemRecord]

        init(tile: Tile, imageFileName: String?) {
            id = tile.id
            title = tile.title
            self.imageFileName = imageFileName
            category = tile.categoryRawValue
            ownerProfileID = tile.ownerProfileID
            sortOrder = tile.sortOrder
            shufflePlaylist = tile.shufflePlaylist
            loopPlaylist = tile.loopPlaylist
            showYouTubeAsVideo = nil
            isHidden = tile.isHidden
            mediaItems = tile.orderedMediaItems.map(MediaItemRecord.init(item:))
        }

        var resolvedCategory: TileCategory {
            TileCategory(rawValue: category) ?? .music
        }
    }

    struct MediaItemRecord: Codable, Equatable {
        var id: UUID
        var type: String
        var title: String
        /// File name inside `media/` for local audio and video.
        var localFileName: String?
        var youtubeVideoID: String?
        var appleMusicItemID: String?
        var sortOrder: Int

        init(item: MediaItem) {
            id = item.id
            type = item.typeRawValue
            title = item.title
            localFileName = item.localFileName
            youtubeVideoID = item.youtubeVideoID
            appleMusicItemID = item.appleMusicItemID
            sortOrder = item.sortOrder
        }

        var resolvedType: MediaSourceType {
            MediaSourceType(rawValue: type) ?? .localAudio
        }
    }
}

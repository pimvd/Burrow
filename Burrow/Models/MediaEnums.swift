import Foundation

/// The kind of playlist a tile contains. A tile is single-type: it holds either
/// music items or video items, never a mix. The category is fixed at creation.
enum TileCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case music
    case video

    var id: String { rawValue }

    /// The media source types that may be added to a tile of this category.
    ///
    /// YouTube appears in both: a video tile plays the embed, a music tile keeps
    /// it off screen and plays only its sound.
    var allowedSourceTypes: [MediaSourceType] {
        switch self {
        case .music: return [.localAudio, .appleMusic, .youtube]
        case .video: return [.localVideo, .youtube]
        }
    }

    /// Whether a YouTube entry in a tile of this category shows its picture.
    /// Replaces the former per-tile `showYouTubeAsVideo` setting.
    var showsYouTubeVideo: Bool { self == .video }

    func allows(_ sourceType: MediaSourceType) -> Bool {
        allowedSourceTypes.contains(sourceType)
    }

    var symbolName: String {
        switch self {
        case .music: return "music.note"
        case .video: return "film"
        }
    }

    var localizedTitle: String {
        switch self {
        case .music: return String(localized: "Music", comment: "Tile category name")
        case .video: return String(localized: "Video", comment: "Tile category name")
        }
    }
}

/// Where the audio or video of a single playlist entry comes from.
enum MediaSourceType: String, Codable, CaseIterable, Identifiable, Sendable {
    case localAudio
    case localVideo
    case appleMusic
    case youtube

    var id: String { rawValue }

    /// Whether playing this source requires an active network connection.
    var requiresNetwork: Bool {
        switch self {
        case .localAudio, .localVideo: return false
        case .appleMusic, .youtube: return true
        }
    }

    var symbolName: String {
        switch self {
        case .localAudio: return "waveform"
        case .localVideo: return "video"
        case .appleMusic: return "music.note.list"
        case .youtube: return "play.rectangle"
        }
    }

    var localizedTitle: String {
        switch self {
        case .localAudio: return String(localized: "Audio file", comment: "Media source type")
        case .localVideo: return String(localized: "Video file", comment: "Media source type")
        case .appleMusic: return String(localized: "Apple Music", comment: "Media source type")
        case .youtube: return String(localized: "YouTube", comment: "Media source type")
        }
    }
}

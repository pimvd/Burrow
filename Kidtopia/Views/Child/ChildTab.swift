import Foundation

/// The three tabs of the child home screen.
///
/// Deliberately separate from `TileCategory`: that enum also decides which
/// media source types may be added to a tile, and games have no media at all.
enum ChildTab: Hashable, CaseIterable, Sendable {
    case music
    case video
    case games

    /// The tile category this tab shows, or `nil` for the games tab.
    var tileCategory: TileCategory? {
        switch self {
        case .music: return .music
        case .video: return .video
        case .games: return nil
        }
    }
}

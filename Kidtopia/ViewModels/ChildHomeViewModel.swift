import Foundation
import Observation

/// Decides which tiles a child may see right now, and keeps the child screen's
/// small amount of UI state.
@Observable
@MainActor
final class ChildHomeViewModel {
    var selectedCategory: TileCategory = .music

    /// The tile the child tapped, presented as a full screen player.
    var presentedTile: Tile?

    /// Filters the full tile list down to what this profile may see in one tab.
    ///
    /// - Owned tiles plus tiles explicitly shared with this profile.
    /// - Hidden and trashed tiles are never shown.
    /// - Tiles that can only play with a connection disappear while offline,
    ///   rather than failing in front of the child.
    func visibleTiles(
        from tiles: [Tile],
        profile: ChildProfile,
        category: TileCategory,
        isOnline: Bool
    ) -> [Tile] {
        tiles
            .filter { profile.canSee(tile: $0) }
            .filter { $0.category == category }
            .filter { $0.mediaItemCount > 0 }
            .filter { isOnline || !$0.requiresNetwork }
            .sorted { $0.sortOrder < $1.sortOrder }
    }
}

import Foundation
import Observation

/// Decides which tiles a child may see right now, and keeps the child screen's
/// small amount of UI state.
@Observable
@MainActor
final class ChildHomeViewModel {
    var selectedTab: ChildTab = .music

    /// The tile the child tapped, presented as a full screen player.
    var presentedTile: Tile?

    /// The game the child tapped, presented full screen.
    var presentedGame: GameCatalog.Game?

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

    /// The games this profile may play, in catalog order.
    ///
    /// The free limit is applied here as well as at the parent's toggle. A
    /// package exported from a paid device can carry more enabled games than
    /// the free tier allows, and nothing else would catch that. Extra games
    /// are hidden rather than switched off, so unlocking brings them back.
    func visibleGames(profile: ChildProfile, isPro: Bool) -> [GameCatalog.Game] {
        let enabled = Set(profile.enabledGameIDs)
        let games = GameCatalog.all.filter { enabled.contains($0.identifier) }
        let maximum = ProGate.Limit.gamesPerProfile.maximum(isPro: isPro)
        guard maximum != Int.max else { return games }
        return Array(games.prefix(maximum))
    }
}

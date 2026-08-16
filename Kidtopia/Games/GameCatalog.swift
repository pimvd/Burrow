import Foundation

/// The fixed set of games that ship with the app, in the shape of
/// `AvatarCatalog` and `ThemePalette`.
///
/// A game is code, not content: it is identical on every device and there is
/// nothing about it to sync. Only *which* games a profile may see is stored,
/// on `ChildProfile.enabledGameIDs`.
enum GameCatalog {
    struct Game: Identifiable, Hashable, Sendable {
        /// Stable string stored in `ChildProfile.enabledGameIDs`.
        let identifier: String

        /// A stable, hardcoded UUID. Usage rows use it in place of a tile ID,
        /// which is what lets `StatisticsService` treat a game exactly like a
        /// tile without knowing games exist. Never generate this at runtime:
        /// a fresh UUID would orphan every row written by an earlier launch.
        let id: UUID

        let symbolName: String
        let titleResource: LocalizedStringResource

        var localizedTitle: String { String(localized: titleResource) }

        // Hashed and compared on `id` alone. `LocalizedStringResource` is not
        // Hashable, and a game's stable UUID is its identity in any case.
        static func == (lhs: Game, rhs: Game) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    static let matchingPairs = "matchingPairs"

    static let all: [Game] = [
        Game(
            identifier: matchingPairs,
            id: UUID(uuidString: "9F1B7A2C-4E63-4C1E-9D5A-2B8F0C6D3A11")!,
            symbolName: "square.grid.2x2",
            titleResource: LocalizedStringResource("Matching Pairs", comment: "Game name")
        )
    ]

    static func game(identifier: String) -> Game? {
        all.first { $0.identifier == identifier }
    }

    static func game(id: UUID) -> Game? {
        all.first { $0.id == id }
    }
}

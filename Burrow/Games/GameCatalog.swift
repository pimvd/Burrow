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
    static let oddOneOut = "oddOneOut"
    static let patternMemory = "patternMemory"
    static let ticTacToe = "ticTacToe"
    static let connectFour = "connectFour"
    static let hangman = "hangman"

    /// Roughly easiest first: the games a three-year-old can play come before
    /// the ones that need turn taking, and reading comes last. This is the
    /// order the parent's list and the child's grid both use.
    static let all: [Game] = [
        Game(
            identifier: matchingPairs,
            id: UUID(uuidString: "9F1B7A2C-4E63-4C1E-9D5A-2B8F0C6D3A11")!,
            symbolName: "square.grid.2x2",
            titleResource: LocalizedStringResource("Matching Pairs", comment: "Game name")
        ),
        Game(
            identifier: oddOneOut,
            id: UUID(uuidString: "CCE55478-E983-4E24-9263-E33E1BCD8198")!,
            symbolName: "questionmark.circle",
            titleResource: LocalizedStringResource("Odd One Out", comment: "Game name")
        ),
        Game(
            identifier: patternMemory,
            id: UUID(uuidString: "35E39556-0CA1-479D-9C8C-D3B9D78DF53F")!,
            symbolName: "circle.grid.2x2",
            titleResource: LocalizedStringResource("Copy the Pattern", comment: "Game name")
        ),
        Game(
            identifier: ticTacToe,
            id: UUID(uuidString: "FAA8015C-3E14-4991-AF41-3DCD34B6C041")!,
            symbolName: "number",
            titleResource: LocalizedStringResource("Tic Tac Toe", comment: "Game name")
        ),
        Game(
            identifier: connectFour,
            id: UUID(uuidString: "CBCC8CFB-E981-4AA1-9EEA-8E75FCCDE3A2")!,
            symbolName: "circle.grid.3x3.fill",
            titleResource: LocalizedStringResource("Four in a Row", comment: "Game name")
        ),
        Game(
            identifier: hangman,
            id: UUID(uuidString: "AA3803A0-B90A-4B36-923A-28DA9994A944")!,
            symbolName: "textformat.abc",
            titleResource: LocalizedStringResource("Hangman", comment: "Game name")
        )
    ]

    static func game(identifier: String) -> Game? {
        all.first { $0.identifier == identifier }
    }

    static func game(id: UUID) -> Game? {
        all.first { $0.id == id }
    }
}

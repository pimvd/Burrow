import Foundation
import Testing
@testable import Kidtopia

@Suite("GameCatalog")
struct GameCatalogTests {
    @Test("The catalog is not empty")
    func hasGames() {
        #expect(!GameCatalog.all.isEmpty)
    }

    @Test("Identifiers are unique")
    func identifiersAreUnique() {
        let identifiers = GameCatalog.all.map(\.identifier)
        #expect(Set(identifiers).count == identifiers.count)
    }

    @Test("Stable UUIDs are unique")
    func idsAreUnique() {
        let ids = GameCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Every game has a title and a symbol")
    func gamesAreComplete() {
        for game in GameCatalog.all {
            #expect(!game.localizedTitle.isEmpty)
            #expect(!game.symbolName.isEmpty)
        }
    }

    /// A game dropped from the catalog silently disappears from every profile
    /// that had it switched on, so the list is pinned here.
    @Test("Every shipped game is in the catalog")
    func shipsEveryGame() {
        let expected = [
            GameCatalog.matchingPairs,
            GameCatalog.oddOneOut,
            GameCatalog.patternMemory,
            GameCatalog.ticTacToe,
            GameCatalog.connectFour,
            GameCatalog.hangman
        ]
        #expect(GameCatalog.all.map(\.identifier) == expected)
    }

    /// Usage rows written by an earlier launch resolve through these UUIDs.
    /// Changing one orphans a child's statistics, so they are spelled out.
    @Test("The stable UUIDs never change")
    func idsAreStable() {
        let expected: [String: String] = [
            GameCatalog.matchingPairs: "9F1B7A2C-4E63-4C1E-9D5A-2B8F0C6D3A11",
            GameCatalog.oddOneOut: "CCE55478-E983-4E24-9263-E33E1BCD8198",
            GameCatalog.patternMemory: "35E39556-0CA1-479D-9C8C-D3B9D78DF53F",
            GameCatalog.ticTacToe: "FAA8015C-3E14-4991-AF41-3DCD34B6C041",
            GameCatalog.connectFour: "CBCC8CFB-E981-4AA1-9EEA-8E75FCCDE3A2",
            GameCatalog.hangman: "AA3803A0-B90A-4B36-923A-28DA9994A944"
        ]

        for game in GameCatalog.all {
            #expect(game.id.uuidString == expected[game.identifier])
        }
    }

    @Test("Titles are distinct, so two games never read the same")
    func titlesAreDistinct() {
        let titles = GameCatalog.all.map(\.localizedTitle)
        #expect(Set(titles).count == titles.count)
    }

    @Test("Lookup by identifier finds the game")
    func lookupByIdentifier() {
        let game = GameCatalog.game(identifier: GameCatalog.matchingPairs)
        #expect(game?.identifier == GameCatalog.matchingPairs)
    }

    @Test("Lookup by stable UUID finds the game")
    func lookupByID() {
        let expected = GameCatalog.all[0]
        #expect(GameCatalog.game(id: expected.id)?.identifier == expected.identifier)
    }

    @Test("Unknown lookups return nil")
    func unknownLookupsReturnNil() {
        #expect(GameCatalog.game(identifier: "nope") == nil)
        #expect(GameCatalog.game(id: UUID()) == nil)
    }
}

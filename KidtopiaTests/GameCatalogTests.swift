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

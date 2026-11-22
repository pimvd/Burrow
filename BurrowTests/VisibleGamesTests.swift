import Testing
@testable import Burrow

@MainActor
@Suite("Visible games")
struct VisibleGamesTests {
    @Test("A profile with nothing enabled sees no games")
    func noneEnabled() {
        let model = ChildHomeViewModel()
        let profile = ChildProfile(name: "Melle")
        #expect(model.visibleGames(profile: profile, hasFullAccess: false).isEmpty)
    }

    @Test("An enabled game is visible")
    func enabledIsVisible() {
        let model = ChildHomeViewModel()
        let profile = ChildProfile(name: "Melle")
        profile.setGame(GameCatalog.matchingPairs, enabled: true)
        #expect(model.visibleGames(profile: profile, hasFullAccess: false).map(\.identifier)
            == [GameCatalog.matchingPairs])
    }

    @Test("An identifier no build knows about is ignored")
    func unknownIdentifierIgnored() {
        let model = ChildHomeViewModel()
        let profile = ChildProfile(name: "Melle", enabledGameIDs: ["fromTheFuture"])
        #expect(model.visibleGames(profile: profile, hasFullAccess: false).isEmpty)
    }

    // The parent UI enforces the limit at the toggle, but a package imported
    // from a paid device can carry more. The child tab holds the line too.
    @Test("A free profile over the limit sees only the first two")
    func freeTierClampsToLimit() {
        let model = ChildHomeViewModel()
        let all = GameCatalog.all.map(\.identifier)
        let profile = ChildProfile(name: "Melle", enabledGameIDs: all)
        let visible = model.visibleGames(profile: profile, hasFullAccess: false)
        #expect(visible.count == min(2, all.count))
    }

    @Test("A paid profile sees every enabled game")
    func paidSeesEverything() {
        let model = ChildHomeViewModel()
        let all = GameCatalog.all.map(\.identifier)
        let profile = ChildProfile(name: "Melle", enabledGameIDs: all)
        #expect(model.visibleGames(profile: profile, hasFullAccess: true).count == all.count)
    }

    @Test("Games come back in catalog order, not activation order")
    func catalogOrder() {
        let model = ChildHomeViewModel()
        let reversed = GameCatalog.all.map(\.identifier).reversed()
        let profile = ChildProfile(name: "Melle", enabledGameIDs: Array(reversed))
        let visible = model.visibleGames(profile: profile, hasFullAccess: true).map(\.identifier)
        #expect(visible == GameCatalog.all.map(\.identifier))
    }

    @Test("With nothing anywhere, only the music tab stays")
    func emptyProfileKeepsMusicTab() {
        let model = ChildHomeViewModel()
        let profile = ChildProfile(name: "Melle")
        #expect(model.visibleTabs(from: [], profile: profile, isOnline: true, hasFullAccess: false) == [.music])
    }

    @Test("A profile with games but no tiles sees only the games tab")
    func gamesOnly() {
        let model = ChildHomeViewModel()
        let profile = ChildProfile(name: "Melle")
        profile.setGame(GameCatalog.matchingPairs, enabled: true)
        #expect(model.visibleTabs(from: [], profile: profile, isOnline: true, hasFullAccess: false) == [.games])
    }
}

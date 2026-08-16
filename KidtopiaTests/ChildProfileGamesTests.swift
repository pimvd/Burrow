import Foundation
import Testing
@testable import Kidtopia

@Suite("ChildProfile game activation")
struct ChildProfileGamesTests {
    @Test("A new profile has no games enabled")
    func startsEmpty() {
        let profile = ChildProfile(name: "Melle")
        #expect(profile.enabledGameIDs.isEmpty)
    }

    @Test("Enabling a game adds it")
    func enableAdds() {
        let profile = ChildProfile(name: "Melle")
        profile.setGame("matchingPairs", enabled: true)
        #expect(profile.enabledGameIDs == ["matchingPairs"])
    }

    @Test("Enabling the same game twice does not duplicate it")
    func enableIsIdempotent() {
        let profile = ChildProfile(name: "Melle")
        profile.setGame("matchingPairs", enabled: true)
        profile.setGame("matchingPairs", enabled: true)
        #expect(profile.enabledGameIDs == ["matchingPairs"])
    }

    @Test("Disabling a game removes it")
    func disableRemoves() {
        let profile = ChildProfile(name: "Melle")
        profile.setGame("matchingPairs", enabled: true)
        profile.setGame("matchingPairs", enabled: false)
        #expect(profile.enabledGameIDs.isEmpty)
    }

    @Test("Disabling a game that was never on is harmless")
    func disableUnknownIsHarmless() {
        let profile = ChildProfile(name: "Melle")
        profile.setGame("nope", enabled: false)
        #expect(profile.enabledGameIDs.isEmpty)
    }

    @Test("Changing activation bumps lastModified")
    func bumpsLastModified() {
        let old = Date(timeIntervalSince1970: 0)
        let profile = ChildProfile(name: "Melle", lastModified: old)
        profile.setGame("matchingPairs", enabled: true)
        #expect(profile.lastModified > old)
    }
}

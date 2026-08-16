import Foundation
import Testing
@testable import Kidtopia

@Suite("Exporting game activation")
struct ExportGamesTests {
    @Test("Enabled games survive a round trip")
    func roundTrips() {
        let profile = ChildProfile(name: "Melle")
        profile.setGame(GameCatalog.matchingPairs, enabled: true)

        let decoded = ExportPackage.ProfileRecord(profile: profile).makeModel()

        #expect(decoded.enabledGameIDs == [GameCatalog.matchingPairs])
    }

    @Test("A profile with no games round trips as empty")
    func emptyRoundTrips() {
        let record = ExportPackage.ProfileRecord(profile: ChildProfile(name: "Melle"))
        #expect(record.makeModel().enabledGameIDs.isEmpty)
    }

    @Test("Identifiers this build does not know are dropped on import")
    func dropsUnknownIdentifiers() {
        let profile = ChildProfile(name: "Melle", enabledGameIDs: ["fromTheFuture"])
        let decoded = ExportPackage.ProfileRecord(profile: profile).makeModel()
        #expect(decoded.enabledGameIDs.isEmpty)
    }

    @Test("A package written before games decodes with none enabled")
    func decodesOlderPackages() throws {
        let json = """
        {
          "id": "0F5B1E64-9A2C-4D77-91EE-1C0B7A5F3D22",
          "name": "Melle",
          "avatarIconName": "\(AvatarCatalog.fallbackIdentifier)",
          "colorThemeName": "\(ThemePalette.fallbackIdentifier)",
          "sortOrder": 0,
          "ageYears": 5,
          "lockScreenPlaybackEnabled": true,
          "visibleSharedTileIDs": []
        }
        """
        let record = try JSONDecoder().decode(
            ExportPackage.ProfileRecord.self,
            from: Data(json.utf8)
        )
        #expect(record.enabledGameIDs.isEmpty)
    }

    @Test("Encoding and decoding a record preserves enabled games")
    func encodesAndDecodes() throws {
        let profile = ChildProfile(name: "Melle")
        profile.setGame(GameCatalog.matchingPairs, enabled: true)

        let data = try JSONEncoder().encode(ExportPackage.ProfileRecord(profile: profile))
        let decoded = try JSONDecoder().decode(ExportPackage.ProfileRecord.self, from: data)

        #expect(decoded.enabledGameIDs == [GameCatalog.matchingPairs])
    }
}

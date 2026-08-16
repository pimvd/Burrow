import Testing
@testable import Kidtopia

@Suite("Smoke")
struct SmokeTests {
    @Test("The test target can see the app module")
    func canSeeAppModule() {
        #expect(TileCategory.music.rawValue == "music")
    }
}

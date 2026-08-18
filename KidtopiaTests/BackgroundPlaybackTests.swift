import Testing
@testable import Kidtopia

@Suite("Background playback rules")
struct BackgroundPlaybackTests {
    @Test("Only a music tile whose profile allows it keeps playing")
    func survival() {
        #expect(BackgroundPlayback.survivesBackgrounding(category: .music, allowsLockScreenPlayback: true))
        #expect(!BackgroundPlayback.survivesBackgrounding(category: .music, allowsLockScreenPlayback: false))
        #expect(!BackgroundPlayback.survivesBackgrounding(category: .video, allowsLockScreenPlayback: true))
        #expect(!BackgroundPlayback.survivesBackgrounding(category: .video, allowsLockScreenPlayback: false))
    }

    @Test("Everything but YouTube can be heard in the background")
    func audibility() {
        #expect(BackgroundPlayback.playsInBackground(.localAudio))
        #expect(BackgroundPlayback.playsInBackground(.appleMusic))
        #expect(BackgroundPlayback.playsInBackground(.localVideo))
        // The embed is a web view, which iOS suspends with the app.
        #expect(!BackgroundPlayback.playsInBackground(.youtube))
    }

    @Test("The next audible entry is found ahead of the current one")
    func skipsForward() {
        let types: [MediaSourceType] = [.youtube, .youtube, .localAudio, .appleMusic]
        #expect(BackgroundPlayback.firstBackgroundPlayableIndex(after: 0, in: types, loop: false) == 2)
    }

    @Test("The entry that was found unplayable is never returned")
    func neverReturnsItself() {
        let types: [MediaSourceType] = [.localAudio, .youtube, .localAudio]
        #expect(BackgroundPlayback.firstBackgroundPlayableIndex(after: 1, in: types, loop: false) == 2)
        #expect(BackgroundPlayback.firstBackgroundPlayableIndex(after: 2, in: types, loop: true) == 0)
    }

    @Test("A playlist that loops wraps to an audible entry before the current one")
    func wrapsWhenLooping() {
        let types: [MediaSourceType] = [.appleMusic, .youtube]
        #expect(BackgroundPlayback.firstBackgroundPlayableIndex(after: 1, in: types, loop: false) == nil)
        #expect(BackgroundPlayback.firstBackgroundPlayableIndex(after: 1, in: types, loop: true) == 0)
    }

    @Test("A playlist of nothing but YouTube has no audible entry")
    func allYouTube() {
        let types: [MediaSourceType] = [.youtube, .youtube]
        #expect(BackgroundPlayback.firstBackgroundPlayableIndex(after: 0, in: types, loop: false) == nil)
        #expect(BackgroundPlayback.firstBackgroundPlayableIndex(after: 0, in: types, loop: true) == nil)
    }

    @Test("An empty playlist has no audible entry")
    func empty() {
        #expect(BackgroundPlayback.firstBackgroundPlayableIndex(after: 0, in: [], loop: true) == nil)
    }
}

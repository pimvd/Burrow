import Foundation
import Testing
@testable import Burrow

@Suite("Free trial")
struct TrialTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("A trial that was never started is not running")
    func neverStarted() {
        let state = Trial.state(startedAt: nil, now: start)
        #expect(!state.hasStarted)
        #expect(!state.isActive)
        #expect(state.daysRemaining == 0)
    }

    @Test("A trial started now runs for its full length")
    func justStarted() {
        let state = Trial.state(startedAt: start, now: start)
        #expect(state.hasStarted)
        #expect(state.isActive)
        #expect(state.daysRemaining == Trial.lengthInDays)
    }

    @Test("The count goes down a day at a time")
    func countdown() {
        let state = Trial.state(startedAt: start, now: start.addingTimeInterval(3 * 86_400))
        #expect(state.daysRemaining == Trial.lengthInDays - 3)
    }

    @Test("A part-day left still reads as one day")
    func lastDayRoundsUp() {
        let almostOver = start.addingTimeInterval(Trial.length - 3_600)
        let state = Trial.state(startedAt: start, now: almostOver)
        #expect(state.isActive)
        #expect(state.daysRemaining == 1)
    }

    @Test("The trial stops the moment its length is up")
    func expiresOnTheBoundary() {
        let state = Trial.state(startedAt: start, now: start.addingTimeInterval(Trial.length))
        #expect(state.hasStarted)
        #expect(!state.isActive)
        #expect(state.daysRemaining == 0)
    }

    @Test("An expired trial stays started, so it is never offered twice")
    func staysStarted() {
        let state = Trial.state(startedAt: start, now: start.addingTimeInterval(10 * Trial.length))
        #expect(state.hasStarted)
        #expect(!state.isActive)
    }

    @Test("A clock moved backwards does not hand out a longer trial")
    func clockMovedBackwards() {
        let state = Trial.state(startedAt: start, now: start.addingTimeInterval(-60 * 86_400))
        #expect(state.isActive)
        #expect(state.daysRemaining == Trial.lengthInDays)
    }
}

@Suite("Trial storage")
@MainActor
struct TrialServiceTests {
    /// A defaults domain of its own, so the tests never touch the real one.
    private func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: "burrow.tests.\(UUID().uuidString)")!
        return defaults
    }

    @Test("A fresh install has no trial")
    func freshInstall() {
        let service = TrialService(defaults: makeDefaults())
        #expect(!service.state.hasStarted)
        #expect(!service.state.isActive)
    }

    @Test("Starting the trial opens everything")
    func startingOpensEverything() {
        let service = TrialService(defaults: makeDefaults())
        service.start()
        #expect(service.state.isActive)
        #expect(service.state.daysRemaining == Trial.lengthInDays)
    }

    @Test("The trial cannot be started a second time")
    func startsOnlyOnce() {
        let defaults = makeDefaults()
        let service = TrialService(defaults: defaults)
        let begin = Date(timeIntervalSince1970: 1_700_000_000)
        service.start(now: begin)

        // A fortnight later, asking again must not extend anything.
        service.start(now: begin.addingTimeInterval(Trial.length + 86_400))
        service.refresh(now: begin.addingTimeInterval(Trial.length + 86_400))
        #expect(service.state.hasStarted)
        #expect(!service.state.isActive)
    }

    @Test("The start date survives a new instance")
    func survivesRelaunch() {
        let defaults = makeDefaults()
        TrialService(defaults: defaults).start()
        let afterRelaunch = TrialService(defaults: defaults)
        #expect(afterRelaunch.state.isActive)
    }
}

@Suite("ProGate playlist limit")
struct ProGateMediaItemsTests {
    @Test("A free playlist holds three items")
    func freeMaximum() {
        #expect(ProGate.Limit.mediaItemsPerTile.maximum(hasFullAccess: false) == 3)
    }

    @Test("An open playlist holds fifty")
    func fullMaximum() {
        #expect(ProGate.Limit.mediaItemsPerTile.maximum(hasFullAccess: true) == 50)
    }

    @Test("The third item is the last free one")
    func freeBoundary() {
        #expect(ProGate.canAdd(.mediaItemsPerTile, currentCount: 2, hasFullAccess: false))
        #expect(!ProGate.canAdd(.mediaItemsPerTile, currentCount: 3, hasFullAccess: false))
    }

    @Test("The fifty-item cap has its own message, which no purchase lifts")
    func paidCapMessage() {
        #expect(!ProGate.limitMessage(for: .mediaItemsPerTile, hasFullAccess: true).isEmpty)
    }
}

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

@Suite("Trial state")
@MainActor
struct TrialServiceTests {
    private let begin = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Without a trial purchase there is no trial")
    func noPurchase() {
        let service = TrialService(startedAt: nil, now: begin)
        #expect(!service.state.hasStarted)
        #expect(!service.state.isActive)
    }

    @Test("A trial purchase opens everything")
    func purchaseOpensEverything() {
        let service = TrialService()
        service.record(startedAt: begin, now: begin)
        #expect(service.state.isActive)
        #expect(service.state.daysRemaining == Trial.lengthInDays)
    }

    @Test("The trial runs out on the clock, and stays started")
    func runsOut() {
        let service = TrialService(startedAt: begin, now: begin)
        service.refresh(now: begin.addingTimeInterval(Trial.length + 86_400))
        #expect(service.state.hasStarted)
        #expect(!service.state.isActive)
    }

    @Test("A refunded trial no longer counts")
    func refunded() {
        let service = TrialService(startedAt: begin, now: begin)
        service.record(startedAt: nil, now: begin)
        #expect(!service.state.hasStarted)
        #expect(!service.state.isActive)
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

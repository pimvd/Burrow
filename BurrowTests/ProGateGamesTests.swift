import Testing
@testable import Burrow

@Suite("ProGate games limit")
struct ProGateGamesTests {
    @Test("Free profiles get two games")
    func freeMaximum() {
        #expect(ProGate.Limit.gamesPerProfile.maximum(hasFullAccess: false) == 2)
    }

    @Test("Paid profiles are unlimited")
    func paidMaximum() {
        #expect(ProGate.Limit.gamesPerProfile.maximum(hasFullAccess: true) == Int.max)
    }

    @Test("A free profile may add up to the second game")
    func freeBoundary() {
        #expect(ProGate.canAdd(.gamesPerProfile, currentCount: 1, hasFullAccess: false))
        #expect(!ProGate.canAdd(.gamesPerProfile, currentCount: 2, hasFullAccess: false))
    }

    @Test("Remaining counts down and is nil when unlimited")
    func remaining() {
        #expect(ProGate.remaining(.gamesPerProfile, currentCount: 1, hasFullAccess: false) == 1)
        #expect(ProGate.remaining(.gamesPerProfile, currentCount: 2, hasFullAccess: false) == 0)
        #expect(ProGate.remaining(.gamesPerProfile, currentCount: 9, hasFullAccess: true) == nil)
    }

    @Test("The free limit has a message and the paid one does not")
    func messages() {
        #expect(!ProGate.limitMessage(for: .gamesPerProfile, hasFullAccess: false).isEmpty)
        #expect(ProGate.limitMessage(for: .gamesPerProfile, hasFullAccess: true).isEmpty)
    }
}

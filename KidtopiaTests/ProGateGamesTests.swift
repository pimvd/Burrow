import Testing
@testable import Kidtopia

@Suite("ProGate games limit")
struct ProGateGamesTests {
    @Test("Free profiles get two games")
    func freeMaximum() {
        #expect(ProGate.Limit.gamesPerProfile.maximum(isPro: false) == 2)
    }

    @Test("Paid profiles are unlimited")
    func paidMaximum() {
        #expect(ProGate.Limit.gamesPerProfile.maximum(isPro: true) == Int.max)
    }

    @Test("A free profile may add up to the second game")
    func freeBoundary() {
        #expect(ProGate.canAdd(.gamesPerProfile, currentCount: 1, isPro: false))
        #expect(!ProGate.canAdd(.gamesPerProfile, currentCount: 2, isPro: false))
    }

    @Test("Remaining counts down and is nil when unlimited")
    func remaining() {
        #expect(ProGate.remaining(.gamesPerProfile, currentCount: 1, isPro: false) == 1)
        #expect(ProGate.remaining(.gamesPerProfile, currentCount: 2, isPro: false) == 0)
        #expect(ProGate.remaining(.gamesPerProfile, currentCount: 9, isPro: true) == nil)
    }

    @Test("The free limit has a message and the paid one does not")
    func messages() {
        #expect(!ProGate.limitMessage(for: .gamesPerProfile, isPro: false).isEmpty)
        #expect(ProGate.limitMessage(for: .gamesPerProfile, isPro: true).isEmpty)
    }
}

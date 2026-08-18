import Foundation
import Testing
@testable import Kidtopia

@Suite("Copy the Pattern round")
struct PatternMemoryRoundTests {
    @Test("A new round has no pattern yet")
    func startsEmpty() {
        let round = PatternMemoryRound()
        #expect(round.pattern.isEmpty)
        #expect(round.progress == 0)
        #expect(round.round == 0)
    }

    @Test("Extending adds one pad and starts the attempt over")
    func extendsByOne() {
        var round = PatternMemoryRound()
        round.extend(with: 2)
        round.extend(with: 0)

        #expect(round.pattern == [2, 0])
        #expect(round.round == 2)
        #expect(round.progress == 0)
    }

    @Test("A pad outside the four is not added")
    func rejectsUnknownPad() {
        var round = PatternMemoryRound()
        round.extend(with: 9)
        round.extend(with: -1)
        #expect(round.pattern.isEmpty)
    }

    @Test("Random pads stay inside the four")
    func randomPadsAreInRange() {
        var generator = SystemRandomNumberGenerator()
        var round = PatternMemoryRound()

        for _ in 0 ..< 50 { round.extend(using: &generator) }

        #expect(round.pattern.count == 50)
        #expect(round.pattern.allSatisfy { (0 ..< PatternMemoryRound.padCount).contains($0) })
    }

    @Test("Tapping the pattern back in order completes it")
    func completesInOrder() {
        var round = PatternMemoryRound()
        round.extend(with: 1)
        round.extend(with: 3)

        #expect(round.tap(1) == .correct)
        #expect(round.progress == 1)
        #expect(round.tap(3) == .completed)
        #expect(round.progress == 2)
    }

    @Test("A wrong pad sends the child back to the start of the same pattern")
    func wrongTapRewinds() {
        var round = PatternMemoryRound()
        round.extend(with: 1)
        round.extend(with: 3)

        #expect(round.tap(1) == .correct)
        #expect(round.tap(0) == .wrong)
        #expect(round.progress == 0)
        #expect(round.pattern == [1, 3], "the pattern itself is never lost")
    }

    @Test("Taps before there is a pattern are ignored")
    func ignoresTapsWithoutAPattern() {
        var round = PatternMemoryRound()
        #expect(round.tap(0) == .ignored)
    }

    @Test("Taps after the pattern is complete are ignored")
    func ignoresExtraTaps() {
        var round = PatternMemoryRound()
        round.extend(with: 2)

        #expect(round.tap(2) == .completed)
        #expect(round.tap(2) == .ignored)
        #expect(round.progress == 1)
    }

    @Test("Replaying only resets the attempt")
    func replayKeepsThePattern() {
        var round = PatternMemoryRound()
        round.extend(with: 2)
        round.extend(with: 1)
        round.tap(2)

        round.replay()

        #expect(round.progress == 0)
        #expect(round.pattern == [2, 1])
    }

    @Test("Resetting clears everything")
    func resetClears() {
        var round = PatternMemoryRound()
        round.extend(with: 2)
        round.tap(2)

        round.reset()

        #expect(round.pattern.isEmpty)
        #expect(round.progress == 0)
    }

    @Test("A whole game: each round is one pad longer")
    func growsARoundAtATime() {
        var round = PatternMemoryRound()
        var generator = SystemRandomNumberGenerator()

        for expected in 1 ... 8 {
            round.extend(using: &generator)
            #expect(round.round == expected)

            for (step, pad) in round.pattern.enumerated() {
                let outcome = round.tap(pad)
                #expect(outcome == (step == round.pattern.count - 1 ? .completed : .correct))
            }
        }
    }
}

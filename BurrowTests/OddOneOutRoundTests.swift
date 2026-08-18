import Foundation
import Testing
@testable import Burrow

@Suite("Odd One Out round")
struct OddOneOutRoundTests {
    private func makeRound() -> OddOneOutRound {
        OddOneOutRound(level: 1, emojis: ["🐶", "🐱", "🍕", "🐰"], oddIndex: 2)
    }

    @Test("A new round has every picture and no answer yet")
    func startsUnsolved() {
        let round = makeRound()
        #expect(round.options.map(\.emoji) == ["🐶", "🐱", "🍕", "🐰"])
        #expect(round.options.map(\.id) == [0, 1, 2, 3])
        #expect(round.oddID == 2)
        #expect(!round.isSolved)
        #expect(round.wrongPicks.isEmpty)
    }

    @Test("Picking the odd picture solves the round")
    func rightPickSolves() {
        var round = makeRound()
        #expect(round.pick(2) == .right)
        #expect(round.isSolved)
    }

    @Test("A wrong pick is remembered and costs nothing else")
    func wrongPickIsRemembered() {
        var round = makeRound()
        #expect(round.pick(0) == .wrong)
        #expect(round.isWrong(0))
        #expect(!round.isSolved)

        // The child keeps looking and still gets the credit.
        #expect(round.pick(2) == .right)
        #expect(round.isSolved)
    }

    @Test("The same wrong picture is not counted twice")
    func ignoresRepeatedWrongPicks() {
        var round = makeRound()
        #expect(round.pick(0) == .wrong)
        #expect(round.pick(0) == .ignored)
        #expect(round.wrongPicks == [0])
    }

    @Test("Picks after the round is solved are ignored")
    func ignoresPicksAfterSolving() {
        var round = makeRound()
        round.pick(2)
        #expect(round.pick(0) == .ignored)
        #expect(round.wrongPicks.isEmpty)
    }

    @Test("A picture that is not on screen is ignored")
    func ignoresUnknownPicture() {
        var round = makeRound()
        #expect(round.pick(99) == .ignored)
    }

    @Test("Every level builds a round with exactly one outsider")
    func everyLevelIsPlayable() {
        var generator = SystemRandomNumberGenerator()

        for level in 1 ... OddOneOutCatalog.levelCount {
            let tier = OddOneOutCatalog.tier(forLevel: level)

            for _ in 0 ..< 20 {
                let round = OddOneOutRound.make(level: level, using: &generator)

                #expect(round.level == level)
                #expect(round.options.count == tier.optionCount)
                #expect(round.options.map(\.id) == Array(0 ..< tier.optionCount))
                #expect(round.options.contains { $0.id == round.oddID })

                // No picture appears twice, or there would be two answers.
                let emojis = round.options.map(\.emoji)
                #expect(Set(emojis).count == emojis.count)

                // The outsider comes from the other group, the rest from the
                // family — which is what makes the puzzle solvable at all.
                let odd = emojis[round.oddID]
                let family = emojis.enumerated()
                    .filter { $0.offset != round.oddID }
                    .map(\.element)
                let puzzle = tier.puzzles.first { candidate in
                    candidate.outsiders.contains(odd)
                        && family.allSatisfy(candidate.family.contains)
                }
                #expect(puzzle != nil, "the round matches no puzzle in its tier")
            }
        }
    }

    @Test("The odd picture turns up in every position over enough rounds")
    func theAnswerMoves() {
        var generator = SystemRandomNumberGenerator()
        var positions: Set<Int> = []

        for _ in 0 ..< 200 {
            positions.insert(OddOneOutRound.make(level: 1, using: &generator).oddID)
        }

        #expect(positions == Set(0 ..< OddOneOutCatalog.tiers[0].optionCount))
    }

    @Test("Later levels put more pictures on screen")
    func difficultyGrows() {
        let first = OddOneOutCatalog.tier(forLevel: 1)
        let last = OddOneOutCatalog.tier(forLevel: OddOneOutCatalog.levelCount)
        #expect(last.optionCount > first.optionCount)
    }

    @Test("A level past the last one still returns a tier")
    func clampsBeyondTheLastLevel() {
        let last = OddOneOutCatalog.tier(forLevel: OddOneOutCatalog.levelCount)
        #expect(OddOneOutCatalog.tier(forLevel: OddOneOutCatalog.levelCount + 5) == last)
        #expect(OddOneOutCatalog.tier(forLevel: 0) == OddOneOutCatalog.tiers[0])
        #expect(OddOneOutCatalog.tier(forLevel: -3) == OddOneOutCatalog.tiers[0])
    }

    @Test("Every tier has enough pictures for the rounds it builds")
    func tiersHaveEnoughPictures() {
        for tier in OddOneOutCatalog.tiers {
            #expect(!tier.puzzles.isEmpty)
            #expect(tier.optionCount >= 4)

            for puzzle in tier.puzzles {
                #expect(puzzle.family.count >= tier.optionCount - 1)
                #expect(!puzzle.outsiders.isEmpty)

                // A picture in both groups would make the round unanswerable.
                #expect(Set(puzzle.family).isDisjoint(with: Set(puzzle.outsiders)))
                #expect(Set(puzzle.family).count == puzzle.family.count)
            }
        }
    }
}

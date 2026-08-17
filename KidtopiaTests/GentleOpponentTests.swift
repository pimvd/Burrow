import Foundation
import Testing
@testable import Kidtopia

@Suite("Gentle opponent")
struct GentleOpponentTests {
    private struct CountingGenerator: RandomNumberGenerator {
        var value: UInt64 = 0
        mutating func next() -> UInt64 {
            value &+= 1
            return value
        }
    }

    @Test("With nothing to play it passes")
    func passesWithoutLegalMoves() {
        var generator = CountingGenerator()
        let move = GentleOpponent.move(
            legal: [Int](),
            winning: [],
            blocking: [],
            using: &generator
        )
        #expect(move == nil)
    }

    @Test("One legal move is the move")
    func takesTheOnlyMove() {
        var generator = CountingGenerator()
        let move = GentleOpponent.move(legal: [4], winning: [], blocking: [], using: &generator)
        #expect(move == 4)
    }

    @Test("A win beats a block")
    func winsRatherThanBlocks() {
        var generator = CountingGenerator()
        let move = GentleOpponent.move(
            legal: [1, 2, 3],
            winning: [2],
            blocking: [3],
            blockChance: 1,
            using: &generator
        )
        #expect(move == 2)
    }

    @Test("It always blocks at a chance of one")
    func alwaysBlocks() {
        var generator = CountingGenerator()
        for _ in 0 ..< 10 {
            let move = GentleOpponent.move(
                legal: [1, 2, 3],
                winning: [],
                blocking: [3],
                blockChance: 1,
                using: &generator
            )
            #expect(move == 3)
        }
    }

    @Test("At a chance of zero it never blocks on purpose")
    func neverBlocksDeliberately() {
        // With blocking excluded from the pool the only way `3` could come
        // back is the random pick, so the run is over the remaining moves.
        var generator = CountingGenerator()
        for _ in 0 ..< 10 {
            let move = GentleOpponent.move(
                legal: [1, 2],
                winning: [],
                blocking: [3],
                blockChance: 0,
                using: &generator
            )
            #expect(move == 1 || move == 2)
        }
    }

    @Test("Every move it returns is a legal one")
    func staysLegal() {
        var generator = SystemRandomNumberGenerator()
        let legal = [0, 5, 7, 9]

        for _ in 0 ..< 50 {
            let move = GentleOpponent.move(
                legal: legal,
                winning: [],
                blocking: [5],
                using: &generator
            )
            #expect(move.map(legal.contains) == true)
        }
    }
}

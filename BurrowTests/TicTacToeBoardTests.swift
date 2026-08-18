import Foundation
import Testing
@testable import Burrow

@Suite("Tic Tac Toe board")
struct TicTacToeBoardTests {
    /// A fixed generator, so a test never depends on which move the opponent
    /// happens to pick.
    private struct CountingGenerator: RandomNumberGenerator {
        var value: UInt64 = 0
        mutating func next() -> UInt64 {
            value &+= 1
            return value
        }
    }

    @Test("A new board is empty and unfinished")
    func startsEmpty() {
        let board = TicTacToeBoard()
        #expect(board.cells.count == 9)
        #expect(board.cells.allSatisfy { $0 == nil })
        #expect(board.emptyCells.count == 9)
        #expect(board.result == nil)
        #expect(!board.isFinished)
    }

    @Test("Placing a mark fills the cell")
    func placesMark() {
        var board = TicTacToeBoard()
        let placed = board.place(.child, at: 4)
        #expect(placed)
        #expect(board.cells[4] == .child)
        #expect(board.emptyCells.count == 8)
    }

    @Test("A taken cell cannot be played again")
    func rejectsTakenCell() {
        var board = TicTacToeBoard()
        board.place(.child, at: 0)
        let taken = board.place(.computer, at: 0)
        #expect(!taken)
        #expect(board.cells[0] == .child)
    }

    @Test("A cell outside the board is refused")
    func rejectsOutOfRange() {
        var board = TicTacToeBoard()
        let past = board.place(.child, at: 9)
        let before = board.place(.child, at: -1)
        #expect(!past)
        #expect(!before)
    }

    @Test("Three in a row wins and reports the line")
    func rowWins() {
        var board = TicTacToeBoard()
        board.place(.child, at: 0)
        board.place(.computer, at: 3)
        board.place(.child, at: 1)
        board.place(.computer, at: 4)
        board.place(.child, at: 2)

        #expect(board.result == .childWon)
        #expect(board.winningLine == [0, 1, 2])
        #expect(board.isFinished)
    }

    @Test("A diagonal wins too")
    func diagonalWins() {
        var board = TicTacToeBoard()
        for cell in [0, 4, 8] { board.place(.computer, at: cell) }
        #expect(board.result == .computerWon)
        #expect(board.winningLine == [0, 4, 8])
    }

    @Test("No moves are accepted once the game is over")
    func refusesMovesAfterTheEnd() {
        var board = TicTacToeBoard()
        for cell in [0, 1, 2] { board.place(.child, at: cell) }
        let late = board.place(.computer, at: 5)
        #expect(!late)
    }

    @Test("A full board with no line is a draw")
    func drawFillsTheBoard() {
        var board = TicTacToeBoard()
        // c c x
        // x x c
        // c c x  — no line anywhere.
        let moves: [(TicTacToeBoard.Mark, Int)] = [
            (.child, 0), (.child, 1), (.computer, 2),
            (.computer, 3), (.computer, 4), (.child, 5),
            (.child, 6), (.child, 7), (.computer, 8)
        ]
        for (mark, cell) in moves { board.place(mark, at: cell) }

        #expect(board.result == .draw)
        #expect(board.winningLine == nil)
    }

    @Test("Immediate wins are the cells that complete a line")
    func findsImmediateWins() {
        var board = TicTacToeBoard()
        board.place(.child, at: 0)
        board.place(.child, at: 1)

        #expect(board.immediateWins(for: .child) == [2])
        #expect(board.immediateWins(for: .computer).isEmpty)
    }

    @Test("The opponent takes a win when it has one")
    func opponentWins() {
        var board = TicTacToeBoard()
        board.place(.computer, at: 0)
        board.place(.computer, at: 1)
        board.place(.child, at: 3)
        board.place(.child, at: 4)

        var generator = CountingGenerator()
        // Never blocks: the win still has to come first.
        board.playComputerMove(blockChance: 0, using: &generator)

        #expect(board.cells[2] == .computer)
        #expect(board.result == .computerWon)
    }

    @Test("The opponent blocks when it is paying attention")
    func opponentBlocks() {
        var board = TicTacToeBoard()
        board.place(.child, at: 0)
        board.place(.child, at: 1)

        var generator = CountingGenerator()
        board.playComputerMove(blockChance: 1, using: &generator)

        #expect(board.cells[2] == .computer)
    }

    /// The whole point of `GentleOpponent`: a child has to be able to win.
    /// Twenty rounds of a one-in-seven chance make a false failure vanishing.
    @Test("The opponent is beatable: with no blocking it lets the win stand")
    func opponentCanBeBeaten() {
        var generator = SystemRandomNumberGenerator()
        var everMissedTheBlock = false

        for _ in 0 ..< 20 {
            var board = TicTacToeBoard()
            board.place(.child, at: 0)
            board.place(.child, at: 1)
            board.playComputerMove(blockChance: 0, using: &generator)

            #expect(board.emptyCells.count == 6)
            if board.cells[2] == nil {
                everMissedTheBlock = true
                break
            }
        }

        #expect(everMissedTheBlock)
    }

    @Test("The opponent plays nothing on a finished board")
    func opponentPassesWhenFinished() {
        var board = TicTacToeBoard()
        for cell in [0, 1, 2] { board.place(.child, at: cell) }

        var generator = CountingGenerator()
        board.playComputerMove(using: &generator)

        #expect(board.cells.compactMap { $0 }.count == 3)
    }
}

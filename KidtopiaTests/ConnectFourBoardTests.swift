import Foundation
import Testing
@testable import Kidtopia

@Suite("Four in a Row board")
struct ConnectFourBoardTests {
    private struct CountingGenerator: RandomNumberGenerator {
        var value: UInt64 = 0
        mutating func next() -> UInt64 {
            value &+= 1
            return value
        }
    }

    @Test("A new board is empty and every column is open")
    func startsEmpty() {
        let board = ConnectFourBoard()
        #expect(board.slots.count == ConnectFourBoard.columns * ConnectFourBoard.rows)
        #expect(board.slots.allSatisfy { $0 == nil })
        #expect(board.openColumns == Array(0 ..< ConnectFourBoard.columns))
        #expect(board.result == nil)
        #expect(board.lastDrop == nil)
    }

    @Test("A disc falls to the bottom row")
    func fallsToTheBottom() {
        var board = ConnectFourBoard()
        let dropped = board.drop(.child, in: 3)
        #expect(dropped)
        #expect(board.disc(row: ConnectFourBoard.rows - 1, column: 3) == .child)
        #expect(board.disc(row: 0, column: 3) == nil)
    }

    @Test("Discs stack on top of each other")
    func stacks() {
        var board = ConnectFourBoard()
        board.drop(.child, in: 0)
        board.drop(.computer, in: 0)

        #expect(board.disc(row: ConnectFourBoard.rows - 1, column: 0) == .child)
        #expect(board.disc(row: ConnectFourBoard.rows - 2, column: 0) == .computer)
        #expect(board.landingRow(in: 0) == ConnectFourBoard.rows - 3)
    }

    @Test("A full column is closed and refuses more discs")
    func fillsUp() {
        var board = ConnectFourBoard()
        for _ in 0 ..< ConnectFourBoard.rows {
            board.drop(.child, in: 6)
        }

        #expect(board.landingRow(in: 6) == nil)
        #expect(!board.openColumns.contains(6))
        let onAFullColumn = board.drop(.computer, in: 6)
        #expect(!onAFullColumn)
    }

    @Test("A column outside the board is refused")
    func rejectsOutOfRange() {
        var board = ConnectFourBoard()
        let past = board.drop(.child, in: ConnectFourBoard.columns)
        let before = board.drop(.child, in: -1)
        #expect(!past)
        #expect(!before)
        #expect(board.landingRow(in: 99) == nil)
    }

    @Test("Four across wins")
    func horizontalWins() {
        var board = ConnectFourBoard()
        for column in 0 ..< 4 { board.drop(.child, in: column) }

        #expect(board.result == .childWon)
        #expect(board.winningSlots.count == 4)
        #expect(board.isFinished)
    }

    @Test("Four stacked wins")
    func verticalWins() {
        var board = ConnectFourBoard()
        for _ in 0 ..< 4 { board.drop(.computer, in: 2) }

        #expect(board.result == .computerWon)
        #expect(board.winningSlots.count == 4)
    }

    @Test("Four on a diagonal wins")
    func diagonalWins() {
        var board = ConnectFourBoard()
        // A staircase under the child's discs, so column n holds n others
        // beneath it.
        for column in 1 ..< 4 {
            for _ in 0 ..< column { board.drop(.computer, in: column) }
        }
        for column in 0 ..< 4 { board.drop(.child, in: column) }

        #expect(board.result == .childWon)
        #expect(board.winningSlots.count == 4)
    }

    @Test("Three in a row is not a win")
    func threeIsNotEnough() {
        var board = ConnectFourBoard()
        for column in 0 ..< 3 { board.drop(.child, in: column) }
        #expect(board.result == nil)
        #expect(board.winningSlots.isEmpty)
    }

    @Test("No discs are accepted once the game is over")
    func refusesDropsAfterTheEnd() {
        var board = ConnectFourBoard()
        for column in 0 ..< 4 { board.drop(.child, in: column) }
        let late = board.drop(.computer, in: 5)
        #expect(!late)
    }

    @Test("Immediate wins name the columns that finish a run")
    func findsImmediateWins() {
        var board = ConnectFourBoard()
        for column in 0 ..< 3 { board.drop(.child, in: column) }

        #expect(board.immediateWins(for: .child) == [3])
        #expect(board.immediateWins(for: .computer).isEmpty)
    }

    @Test("Looking for a win does not change the board")
    func immediateWinsAreReadOnly() {
        var board = ConnectFourBoard()
        for column in 0 ..< 3 { board.drop(.child, in: column) }
        let before = board

        _ = board.immediateWins(for: .child)
        #expect(board == before)
    }

    @Test("The opponent takes a win when it has one")
    func opponentWins() {
        var board = ConnectFourBoard()
        for _ in 0 ..< 3 { board.drop(.computer, in: 1) }
        board.drop(.child, in: 5)

        var generator = CountingGenerator()
        board.playComputerMove(blockChance: 0, using: &generator)

        #expect(board.result == .computerWon)
    }

    @Test("The opponent blocks when it is paying attention")
    func opponentBlocks() {
        var board = ConnectFourBoard()
        for column in 0 ..< 3 { board.drop(.child, in: column) }

        var generator = CountingGenerator()
        board.playComputerMove(blockChance: 1, using: &generator)

        #expect(board.disc(row: ConnectFourBoard.rows - 1, column: 3) == .computer)
    }

    @Test("A full board with no run of four is a draw")
    func fullBoardIsADraw() {
        var board = ConnectFourBoard()

        // Bands of two rows, offset by column: the pattern below holds no run
        // of four in any direction, so the board fills without a winner.
        //
        //   C X C X C X C
        //   C X C X C X C
        //   X C X C X C X
        //   X C X C X C X
        //   C X C X C X C
        //   C X C X C X C
        for column in 0 ..< ConnectFourBoard.columns {
            for drop in 0 ..< ConnectFourBoard.rows {
                let row = ConnectFourBoard.rows - 1 - drop
                let disc: ConnectFourBoard.Disc =
                    (row / 2 + column).isMultiple(of: 2) ? .child : .computer
                board.drop(disc, in: column)
            }
        }

        #expect(board.slots.allSatisfy { $0 != nil })
        #expect(board.result == .draw)
        #expect(board.winningSlots.isEmpty)
        #expect(board.openColumns.isEmpty)
    }
}

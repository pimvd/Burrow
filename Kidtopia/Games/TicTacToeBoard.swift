import Foundation

/// The rules of Tic Tac Toe, with no SwiftUI in sight so they can be tested
/// directly — the shape `MatchingPairsBoard` set.
///
/// The child always plays first and always plays `.child`; the computer is
/// `GentleOpponent`, which is beatable on purpose.
struct TicTacToeBoard: Equatable {
    enum Mark: Equatable, Sendable {
        case child
        case computer
    }

    enum Result: Equatable, Sendable {
        case childWon
        case computerWon
        case draw
    }

    static let side = 3
    static let cellCount = side * side

    /// The eight ways to complete a line, as indices into `cells`.
    static let lines: [[Int]] = [
        [0, 1, 2], [3, 4, 5], [6, 7, 8],
        [0, 3, 6], [1, 4, 7], [2, 5, 8],
        [0, 4, 8], [2, 4, 6]
    ]

    private(set) var cells: [Mark?] = Array(repeating: nil, count: cellCount)

    /// `nil` while the game is still running.
    private(set) var result: Result?

    /// The three cells that ended it, so the view can pick them out.
    private(set) var winningLine: [Int]?

    var isFinished: Bool { result != nil }

    var emptyCells: [Int] { cells.indices.filter { cells[$0] == nil } }

    /// `false` when the move was not playable, which the caller can ignore.
    @discardableResult
    mutating func place(_ mark: Mark, at index: Int) -> Bool {
        guard !isFinished,
              cells.indices.contains(index),
              cells[index] == nil else {
            return false
        }

        cells[index] = mark
        evaluate()
        return true
    }

    /// The empty cells where `mark` would complete a line straight away.
    func immediateWins(for mark: Mark) -> [Int] {
        emptyCells.filter { index in
            var probe = cells
            probe[index] = mark
            return Self.lines.contains { line in
                line.allSatisfy { probe[$0] == mark }
            }
        }
    }

    mutating func playComputerMove(
        blockChance: Double = GentleOpponent.defaultBlockChance,
        using generator: inout some RandomNumberGenerator
    ) {
        guard !isFinished else { return }

        let move = GentleOpponent.move(
            legal: emptyCells,
            winning: immediateWins(for: .computer),
            blocking: immediateWins(for: .child),
            blockChance: blockChance,
            using: &generator
        )

        if let move {
            place(.computer, at: move)
        }
    }

    private mutating func evaluate() {
        for line in Self.lines {
            guard let mark = cells[line[0]],
                  line.allSatisfy({ cells[$0] == mark }) else {
                continue
            }
            result = mark == .child ? .childWon : .computerWon
            winningLine = line
            return
        }

        if emptyCells.isEmpty {
            result = .draw
        }
    }
}

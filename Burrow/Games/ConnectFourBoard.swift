import Foundation

/// The rules of Four in a Row: seven columns, six rows, discs fall to the
/// lowest free slot. No SwiftUI here, so the rules can be tested directly.
///
/// Slots are stored row-major with row `0` at the top, the order the view
/// draws them in.
struct ConnectFourBoard: Equatable {
    enum Disc: Equatable, Sendable {
        case child
        case computer
    }

    enum Result: Equatable, Sendable {
        case childWon
        case computerWon
        case draw
    }

    static let columns = 7
    static let rows = 6
    static let runLength = 4

    private(set) var slots: [Disc?] = Array(repeating: nil, count: columns * rows)

    /// `nil` while the game is still running.
    private(set) var result: Result?

    /// The four (or more) slots that ended it, so the view can pick them out.
    private(set) var winningSlots: [Int] = []

    /// The slot the last disc landed in, used to animate the drop.
    private(set) var lastDrop: Int?

    var isFinished: Bool { result != nil }

    static func index(row: Int, column: Int) -> Int { row * columns + column }

    func disc(row: Int, column: Int) -> Disc? {
        guard (0 ..< Self.rows).contains(row), (0 ..< Self.columns).contains(column) else {
            return nil
        }
        return slots[Self.index(row: row, column: column)]
    }

    /// Columns with at least one free slot left.
    var openColumns: [Int] {
        (0 ..< Self.columns).filter { landingRow(in: $0) != nil }
    }

    /// The row a disc dropped into `column` would come to rest in, or `nil`
    /// when the column is full.
    func landingRow(in column: Int) -> Int? {
        guard (0 ..< Self.columns).contains(column) else { return nil }
        return (0 ..< Self.rows)
            .reversed()
            .first { slots[Self.index(row: $0, column: column)] == nil }
    }

    /// `false` when the column was full or the game is already over.
    @discardableResult
    mutating func drop(_ disc: Disc, in column: Int) -> Bool {
        guard !isFinished, let row = landingRow(in: column) else { return false }

        let slot = Self.index(row: row, column: column)
        slots[slot] = disc
        lastDrop = slot
        evaluate(from: row, column: column, disc: disc)
        return true
    }

    /// The columns where `disc` would make four in a row straight away.
    func immediateWins(for disc: Disc) -> [Int] {
        openColumns.filter { column in
            var probe = self
            guard let row = probe.landingRow(in: column) else { return false }
            probe.slots[Self.index(row: row, column: column)] = disc
            return !probe.run(from: row, column: column, disc: disc).isEmpty
        }
    }

    mutating func playComputerMove(
        blockChance: Double = GentleOpponent.defaultBlockChance,
        using generator: inout some RandomNumberGenerator
    ) {
        guard !isFinished else { return }

        let move = GentleOpponent.move(
            legal: openColumns,
            winning: immediateWins(for: .computer),
            blocking: immediateWins(for: .child),
            blockChance: blockChance,
            using: &generator
        )

        if let move {
            drop(.computer, in: move)
        }
    }

    private mutating func evaluate(from row: Int, column: Int, disc: Disc) {
        let finished = run(from: row, column: column, disc: disc)
        if !finished.isEmpty {
            result = disc == .child ? .childWon : .computerWon
            winningSlots = finished
            return
        }

        if openColumns.isEmpty {
            result = .draw
        }
    }

    /// The winning slots through the given cell, or an empty array when there
    /// is no run of four through it.
    private func run(from row: Int, column: Int, disc: Disc) -> [Int] {
        let directions = [(0, 1), (1, 0), (1, 1), (1, -1)]

        for (deltaRow, deltaColumn) in directions {
            var line = [Self.index(row: row, column: column)]
            line += walk(from: (row, column), step: (deltaRow, deltaColumn), disc: disc)
            line += walk(from: (row, column), step: (-deltaRow, -deltaColumn), disc: disc)
            if line.count >= Self.runLength { return line }
        }

        return []
    }

    /// Every matching slot in one direction, not counting the starting cell.
    private func walk(
        from start: (row: Int, column: Int),
        step: (row: Int, column: Int),
        disc: Disc
    ) -> [Int] {
        var found: [Int] = []
        var row = start.row + step.row
        var column = start.column + step.column

        while self.disc(row: row, column: column) == disc {
            found.append(Self.index(row: row, column: column))
            row += step.row
            column += step.column
        }

        return found
    }
}

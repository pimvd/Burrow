import Foundation

/// The computer player shared by Tic Tac Toe and Four in a Row.
///
/// It is deliberately beatable. A perfect opponent turns Tic Tac Toe into a
/// game a four-year-old can never win, which is the opposite of what the rest
/// of this app is for: it takes a winning move when one is there, but only
/// notices the child's threat some of the time.
enum GentleOpponent {
    /// How often the opponent bothers to block a move that would otherwise
    /// win the game for the child.
    static let defaultBlockChance = 0.5

    /// - Parameters:
    ///   - legal: every move that may be played right now. Empty means pass.
    ///   - winning: the subset of `legal` that wins for the computer at once.
    ///   - blocking: the subset of `legal` that would win for the child, and
    ///     so is worth taking away.
    ///   - blockChance: `1` always blocks, `0` never does.
    static func move<Move>(
        legal: [Move],
        winning: [Move],
        blocking: [Move],
        blockChance: Double = defaultBlockChance,
        using generator: inout some RandomNumberGenerator
    ) -> Move? {
        guard !legal.isEmpty else { return nil }

        if let win = winning.randomElement(using: &generator) {
            return win
        }

        if Double.random(in: 0 ..< 1, using: &generator) < blockChance,
           let block = blocking.randomElement(using: &generator) {
            return block
        }

        return legal.randomElement(using: &generator)
    }
}

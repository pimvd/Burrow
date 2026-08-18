import Foundation

/// The rules of Copy the Pattern: four pads light up in turn, the child taps
/// them back in the same order, and the pattern grows by one each round.
///
/// There is no way to lose. A wrong tap only sends the child back to the
/// start of the same pattern, which is then shown again.
struct PatternMemoryRound: Equatable {
    static let padCount = 4

    enum Outcome: Equatable {
        case ignored
        case correct
        case completed
        case wrong
    }

    /// The pads to repeat, in order.
    private(set) var pattern: [Int] = []

    /// How many pads of the pattern the child has tapped back correctly.
    private(set) var progress = 0

    /// What the view shows as the round number: one pad is round one.
    var round: Int { pattern.count }

    /// Appends a known pad. Tests use this; the game uses the random overload.
    mutating func extend(with pad: Int) {
        guard (0 ..< Self.padCount).contains(pad) else { return }
        pattern.append(pad)
        progress = 0
    }

    mutating func extend(using generator: inout some RandomNumberGenerator) {
        extend(with: Int.random(in: 0 ..< Self.padCount, using: &generator))
    }

    @discardableResult
    mutating func tap(_ pad: Int) -> Outcome {
        guard progress < pattern.count else { return .ignored }

        guard pattern[progress] == pad else {
            progress = 0
            return .wrong
        }

        progress += 1
        return progress == pattern.count ? .completed : .correct
    }

    /// Back to the first pad of the same pattern, after a wrong tap.
    mutating func replay() {
        progress = 0
    }

    mutating func reset() {
        pattern = []
        progress = 0
    }
}

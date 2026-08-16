import Foundation

/// The rules of Matching Pairs, with no SwiftUI in sight so they can be
/// tested directly.
///
/// There is no score, no timer and no way to lose: the board simply completes.
struct MatchingPairsBoard: Equatable {
    struct Card: Identifiable, Equatable {
        let id: UUID
        let symbolName: String
        var isFaceUp = false
        var isMatched = false
    }

    enum Outcome: Equatable {
        case ignored
        case revealed
        case matched
        case mismatched
    }

    private(set) var cards: [Card]

    /// `true` between a mismatch and the moment the two cards turn back down.
    /// Further taps are ignored while it holds, so a child cannot flip a third
    /// card into a half-resolved pair.
    private(set) var isResolvingMismatch = false

    var isComplete: Bool { cards.allSatisfy(\.isMatched) }

    /// Two cards per symbol, in the order given. Shuffling is the caller's job
    /// so tests can address specific cards.
    init(symbols: [String]) {
        cards = symbols.flatMap { symbol in
            [Card(id: UUID(), symbolName: symbol), Card(id: UUID(), symbolName: symbol)]
        }
    }

    mutating func shuffle() {
        cards.shuffle()
    }

    @discardableResult
    mutating func choose(_ id: UUID) -> Outcome {
        guard !isResolvingMismatch,
              let index = cards.firstIndex(where: { $0.id == id }),
              !cards[index].isMatched,
              !cards[index].isFaceUp else {
            return .ignored
        }

        cards[index].isFaceUp = true

        let faceUp = cards.indices.filter { cards[$0].isFaceUp && !cards[$0].isMatched }
        guard faceUp.count == 2 else { return .revealed }

        if cards[faceUp[0]].symbolName == cards[faceUp[1]].symbolName {
            cards[faceUp[0]].isMatched = true
            cards[faceUp[1]].isMatched = true
            return .matched
        }

        isResolvingMismatch = true
        return .mismatched
    }

    /// Turns the two mismatched cards back down and unblocks the board.
    mutating func hideMismatched() {
        for index in cards.indices where !cards[index].isMatched {
            cards[index].isFaceUp = false
        }
        isResolvingMismatch = false
    }
}

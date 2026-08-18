import Foundation
import Testing
@testable import Burrow

@Suite("Matching Pairs board")
struct MatchingPairsBoardTests {
    /// Two pairs, in a known order: [a, a, b, b]. No shuffling, so the tests
    /// can address specific cards.
    private func makeBoard() -> MatchingPairsBoard {
        MatchingPairsBoard(symbols: ["a", "b"])
    }

    @Test("A board has two cards per symbol, all face down")
    func startsFaceDown() {
        let board = makeBoard()
        #expect(board.cards.count == 4)
        #expect(board.cards.allSatisfy { !$0.isFaceUp && !$0.isMatched })
        #expect(!board.isComplete)
    }

    @Test("Every card has a unique id")
    func cardsAreUnique() {
        let board = makeBoard()
        #expect(Set(board.cards.map(\.id)).count == 4)
    }

    @Test("Choosing a card turns it face up")
    func revealsCard() {
        var board = makeBoard()
        let outcome = board.choose(board.cards[0].id)
        #expect(outcome == .revealed)
        #expect(board.cards[0].isFaceUp)
    }

    @Test("Choosing the same card twice is ignored")
    func ignoresRepeatChoice() {
        var board = makeBoard()
        _ = board.choose(board.cards[0].id)
        #expect(board.choose(board.cards[0].id) == .ignored)
    }

    @Test("Two matching cards stay up and are marked matched")
    func matchStaysUp() {
        var board = makeBoard()
        _ = board.choose(board.cards[0].id)
        let outcome = board.choose(board.cards[1].id)
        #expect(outcome == .matched)
        #expect(board.cards[0].isMatched)
        #expect(board.cards[1].isMatched)
        #expect(board.cards[0].isFaceUp)
    }

    @Test("Two different cards report a mismatch and block further choices")
    func mismatchBlocks() {
        var board = makeBoard()
        _ = board.choose(board.cards[0].id)
        let outcome = board.choose(board.cards[2].id)
        #expect(outcome == .mismatched)
        #expect(board.isResolvingMismatch)
        #expect(board.choose(board.cards[3].id) == .ignored)
    }

    @Test("Hiding a mismatch turns both cards back down")
    func hideMismatchedTurnsBack() {
        var board = makeBoard()
        _ = board.choose(board.cards[0].id)
        _ = board.choose(board.cards[2].id)
        board.hideMismatched()
        #expect(board.cards.allSatisfy { !$0.isFaceUp })
        #expect(!board.isResolvingMismatch)
    }

    @Test("Hiding a mismatch leaves matched cards face up")
    func hideMismatchedKeepsMatches() {
        var board = makeBoard()
        _ = board.choose(board.cards[0].id)
        _ = board.choose(board.cards[1].id)   // matched
        _ = board.choose(board.cards[2].id)
        board.hideMismatched()
        #expect(board.cards[0].isFaceUp)
        #expect(board.cards[1].isFaceUp)
        #expect(!board.cards[2].isFaceUp)
    }

    @Test("A matched card cannot be chosen again")
    func matchedCardIsInert() {
        var board = makeBoard()
        _ = board.choose(board.cards[0].id)
        _ = board.choose(board.cards[1].id)
        #expect(board.choose(board.cards[0].id) == .ignored)
    }

    @Test("Matching every pair completes the board")
    func completes() {
        var board = makeBoard()
        _ = board.choose(board.cards[0].id)
        _ = board.choose(board.cards[1].id)
        #expect(!board.isComplete)
        _ = board.choose(board.cards[2].id)
        _ = board.choose(board.cards[3].id)
        #expect(board.isComplete)
    }

    @Test("An unknown card id is ignored")
    func unknownCardIgnored() {
        var board = makeBoard()
        #expect(board.choose(UUID()) == .ignored)
    }
}

import Foundation
import Testing
@testable import Burrow

@Suite("Hangman round")
struct HangmanRoundTests {
    private func makeRound(word: String = "CAT") -> HangmanRound {
        HangmanRound(word: word, emoji: "🐱")
    }

    @Test("A new round hides every letter and has all its chances")
    func startsHidden() {
        let round = makeRound()
        #expect(round.word == ["C", "A", "T"])
        #expect(round.revealed == [nil, nil, nil])
        #expect(round.mistakes == 0)
        #expect(round.mistakesRemaining == HangmanRound.allowedMistakes)
        #expect(!round.isWon)
        #expect(!round.isLost)
        #expect(!round.isFinished)
    }

    @Test("A right letter is revealed everywhere it appears")
    func revealsEveryOccurrence() {
        var round = makeRound(word: "BALLOON")
        #expect(round.guess("L") == .hit)
        #expect(round.revealed == [nil, nil, "L", "L", nil, nil, nil])
        #expect(round.mistakes == 0)
    }

    @Test("A wrong letter costs a chance")
    func missCostsAChance() {
        var round = makeRound()
        #expect(round.guess("Z") == .miss)
        #expect(round.mistakes == 1)
        #expect(round.mistakesRemaining == HangmanRound.allowedMistakes - 1)
    }

    @Test("The same letter cannot be guessed twice")
    func ignoresRepeats() {
        var round = makeRound()
        #expect(round.guess("Z") == .miss)
        #expect(round.guess("Z") == .ignored)
        #expect(round.mistakes == 1)
    }

    @Test("Anything that is not a letter is ignored")
    func ignoresNonLetters() {
        var round = makeRound()
        #expect(round.guess("3") == .ignored)
        #expect(round.guess("c") == .ignored)
        #expect(round.mistakes == 0)
    }

    @Test("Guessing every letter wins")
    func winsOnTheLastLetter() {
        var round = makeRound()
        for letter in "CAT" { round.guess(letter) }

        #expect(round.isWon)
        #expect(round.isFinished)
        #expect(!round.isLost)
        #expect(round.revealed == ["C", "A", "T"])
    }

    @Test("Six misses lose the round")
    func losesAfterSixMisses() {
        var round = makeRound()
        for letter in "ZXQWVB" { round.guess(letter) }

        #expect(round.mistakes == HangmanRound.allowedMistakes)
        #expect(round.mistakesRemaining == 0)
        #expect(round.isLost)
        #expect(round.isFinished)
    }

    @Test("Solving it on the last chance is a win, not a loss")
    func winOnTheLastChanceIsAWin() {
        var round = makeRound()
        for letter in "ZXQWV" { round.guess(letter) }
        #expect(round.mistakesRemaining == 1)

        for letter in "CAT" { round.guess(letter) }

        #expect(round.isWon)
        #expect(!round.isLost)
    }

    @Test("No guesses are taken once the round is over")
    func stopsAtTheEnd() {
        var round = makeRound()
        for letter in "CAT" { round.guess(letter) }
        #expect(round.guess("Z") == .ignored)
        #expect(round.mistakes == 0)
    }

    @Test("Accents and case are folded away, so the keyboard is enough")
    func normalisesTranslations() {
        #expect(HangmanRound.normalise("árbol") == ["A", "R", "B", "O", "L"])
        #expect(HangmanRound.normalise("Étoile") == ["E", "T", "O", "I", "L", "E"])
        #expect(HangmanRound.normalise("cerf-volant").allSatisfy(HangmanRound.alphabet.contains))
    }

    @Test("The keyboard covers every letter of every word")
    func everyWordIsPlayable() {
        for word in HangmanWords.all {
            let letters = HangmanRound.normalise(word.localized)
            #expect(!letters.isEmpty, "\(word.id) folds to nothing")
            #expect(letters.allSatisfy(HangmanRound.alphabet.contains))
            #expect(!word.emoji.isEmpty)
        }
    }

    @Test("Word identifiers are unique")
    func wordsAreUnique() {
        let ids = HangmanWords.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("The next word is never the one just played")
    func avoidsRepeatingAWord() {
        var generator = SystemRandomNumberGenerator()
        var previous = HangmanWords.all[0]

        for _ in 0 ..< 30 {
            let next = HangmanWords.next(after: previous, using: &generator)
            #expect(next.id != previous.id)
            previous = next
        }
    }
}

import Foundation

/// The rules of Hangman, with no SwiftUI in sight so they can be tested
/// directly.
///
/// Nothing is drawn hanging: the six chances are shown as hearts, and a lost
/// round simply reveals the word and offers another go. The word is always
/// paired with a picture, so a child who cannot read yet still knows what is
/// being spelled.
struct HangmanRound: Equatable {
    static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    static let allowedMistakes = 6

    enum Outcome: Equatable {
        case ignored
        case hit
        case miss
    }

    /// The word being guessed, already folded to plain capitals.
    let word: [Character]

    /// The picture shown above the word.
    let emoji: String

    private(set) var guessedLetters: Set<Character> = []
    private(set) var mistakes = 0

    /// Translated words arrive with accents and the odd hyphen. Folding them
    /// away keeps every language on the same 26 letter keyboard rather than
    /// asking for a key that is not there.
    static func normalise(_ raw: String) -> [Character] {
        raw
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            .uppercased()
            .filter { alphabet.contains($0) }
    }

    init(word: String, emoji: String) {
        self.word = Self.normalise(word)
        self.emoji = emoji
    }

    /// One entry per letter: the letter once it has been guessed, `nil` while
    /// it is still hidden.
    var revealed: [Character?] {
        word.map { guessedLetters.contains($0) ? $0 : nil }
    }

    var mistakesRemaining: Int { max(0, Self.allowedMistakes - mistakes) }

    /// An empty word counts as won rather than trapping the child in a round
    /// that can never end.
    var isWon: Bool { word.allSatisfy { guessedLetters.contains($0) } }

    var isLost: Bool { !isWon && mistakes >= Self.allowedMistakes }

    var isFinished: Bool { isWon || isLost }

    func hasGuessed(_ letter: Character) -> Bool { guessedLetters.contains(letter) }

    @discardableResult
    mutating func guess(_ letter: Character) -> Outcome {
        guard !isFinished,
              Self.alphabet.contains(letter),
              !guessedLetters.contains(letter) else {
            return .ignored
        }

        guessedLetters.insert(letter)

        guard word.contains(letter) else {
            mistakes += 1
            return .miss
        }

        return .hit
    }
}

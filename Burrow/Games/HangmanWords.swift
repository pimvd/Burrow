import Foundation

/// The words Hangman draws from. Short, concrete nouns a young child knows,
/// each with a picture so the round is playable before the word can be read.
///
/// The words are translated like any other string in the app; a translation
/// with accents is folded to plain capitals by `HangmanRound.normalise`, so
/// every language plays on the same twenty-six letter keyboard.
enum HangmanWords {
    struct Word: Identifiable, Sendable {
        /// The English word, used only as a stable key for `ForEach`.
        let id: String
        let emoji: String
        let resource: LocalizedStringResource

        var localized: String { String(localized: resource) }
    }

    static let all: [Word] = [
        Word(id: "DOG", emoji: "🐶", resource: LocalizedStringResource("DOG", comment: "Hangman word")),
        Word(id: "CAT", emoji: "🐱", resource: LocalizedStringResource("CAT", comment: "Hangman word")),
        Word(id: "FISH", emoji: "🐟", resource: LocalizedStringResource("FISH", comment: "Hangman word")),
        Word(id: "BIRD", emoji: "🐦", resource: LocalizedStringResource("BIRD", comment: "Hangman word")),
        Word(id: "SUN", emoji: "🌞", resource: LocalizedStringResource("SUN", comment: "Hangman word")),
        Word(id: "MOON", emoji: "🌙", resource: LocalizedStringResource("MOON", comment: "Hangman word")),
        Word(id: "STAR", emoji: "⭐️", resource: LocalizedStringResource("STAR", comment: "Hangman word")),
        Word(id: "TREE", emoji: "🌳", resource: LocalizedStringResource("TREE", comment: "Hangman word")),
        Word(id: "FLOWER", emoji: "🌸", resource: LocalizedStringResource("FLOWER", comment: "Hangman word")),
        Word(id: "HOUSE", emoji: "🏠", resource: LocalizedStringResource("HOUSE", comment: "Hangman word")),
        Word(id: "CAR", emoji: "🚗", resource: LocalizedStringResource("CAR", comment: "Hangman word")),
        Word(id: "BOAT", emoji: "⛵️", resource: LocalizedStringResource("BOAT", comment: "Hangman word")),
        Word(id: "APPLE", emoji: "🍎", resource: LocalizedStringResource("APPLE", comment: "Hangman word")),
        Word(id: "BALLOON", emoji: "🎈", resource: LocalizedStringResource("BALLOON", comment: "Hangman word"))
    ]

    /// A word other than `previous`, so the same picture does not come up
    /// twice in a row. Falls back to any word when the list is one long.
    static func next(after previous: Word?, using generator: inout some RandomNumberGenerator) -> Word {
        let choices = all.filter { $0.id != previous?.id }
        return choices.randomElement(using: &generator)
            ?? all.randomElement(using: &generator)
            ?? Word(
                id: "CAT",
                emoji: "🐱",
                resource: LocalizedStringResource("CAT", comment: "Hangman word")
            )
    }
}

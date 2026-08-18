import Foundation

/// The pictures Odd One Out draws from, grouped so that every puzzle is a
/// family of things plus one outsider.
///
/// Difficulty is the distance between the two groups, not the wording: level
/// one is animals against a slice of pizza, the last levels are farm animals
/// against wild ones. Nothing here is translated — a picture of a cat says
/// "cat" in every language, which is the point of using them.
enum OddOneOutCatalog {
    struct Puzzle: Equatable, Sendable {
        /// The things that belong together. Needs at least `optionCount - 1`
        /// entries for every tier that uses it.
        let family: [String]

        /// The candidates for the one that does not belong.
        let outsiders: [String]
    }

    struct Tier: Equatable, Sendable {
        /// How many pictures are on screen, the outsider included.
        let optionCount: Int
        let puzzles: [Puzzle]
    }

    /// Three levels per tier, so the pictures on screen grow from four to six
    /// and the two groups move closer together as a child plays on.
    static let levelsPerTier = 3

    static let tiers: [Tier] = [
        Tier(
            optionCount: 4,
            puzzles: [
                Puzzle(family: ["🐶", "🐱", "🐰", "🐭", "🐹", "🦊"], outsiders: ["🍕", "🍎", "🍌", "🍞"]),
                Puzzle(family: ["🍎", "🍌", "🍓", "🍇", "🍊", "🍐"], outsiders: ["🚗", "🚌", "🚲", "✈️"]),
                Puzzle(family: ["🚗", "🚌", "🚲", "🚂", "✈️", "🚚"], outsiders: ["🐮", "🐷", "🐔", "🐴"]),
                Puzzle(family: ["👕", "👖", "🧦", "🧢", "👟", "🧤"], outsiders: ["🍪", "🥕", "🧀", "🍩"])
            ]
        ),
        Tier(
            optionCount: 6,
            puzzles: [
                Puzzle(family: ["🐶", "🐱", "🐴", "🐮", "🐷", "🐰"], outsiders: ["🐟", "🐬", "🐙", "🦀"]),
                Puzzle(family: ["🍎", "🍌", "🍓", "🍇", "🍊", "🍐"], outsiders: ["🥕", "🥦", "🌽", "🥒"]),
                Puzzle(family: ["🐦", "🦋", "🐝", "🦅", "🦉"], outsiders: ["🐟", "🐠", "🦈", "🐬"]),
                Puzzle(family: ["🚗", "🚌", "🚲", "🚚", "🏍️"], outsiders: ["✈️", "🚁", "🚀"])
            ]
        ),
        Tier(
            optionCount: 6,
            puzzles: [
                Puzzle(family: ["🐮", "🐷", "🐔", "🐴", "🐑", "🦆"], outsiders: ["🦁", "🐯", "🐘", "🦒"]),
                Puzzle(family: ["🍬", "🍭", "🍫", "🍪", "🧁", "🍩"], outsiders: ["🥕", "🥦", "🍅", "🥬"]),
                Puzzle(family: ["🐦", "🦆", "🦉", "🦅", "🐧"], outsiders: ["🐝", "🐞", "🦋", "🐜"]),
                Puzzle(family: ["🎸", "🥁", "🎺", "🎻", "🎹"], outsiders: ["⚽️", "🏀", "🎾", "🏈"])
            ]
        )
    ]

    /// How many levels a child can play before the game says well done.
    static var levelCount: Int { tiers.count * levelsPerTier }

    /// Used only if a tier is ever left without puzzles, so the game shows an
    /// easy round rather than trapping.
    static let fallbackPuzzle = Puzzle(
        family: ["🐶", "🐱", "🐰", "🐭", "🐹"],
        outsiders: ["🍕"]
    )

    /// Levels are one-based. Anything past the last tier keeps using it, so a
    /// level that drifts out of range still returns a playable puzzle.
    static func tier(forLevel level: Int) -> Tier {
        let index = max(0, level - 1) / levelsPerTier
        return tiers[min(index, tiers.count - 1)]
    }
}

/// One screen of Odd One Out: a handful of pictures, exactly one of which does
/// not belong. No SwiftUI here, so the rules can be tested directly.
struct OddOneOutRound: Equatable {
    struct Option: Identifiable, Equatable, Sendable {
        /// Position in the round, which is also its place on screen.
        let id: Int
        let emoji: String
    }

    enum Outcome: Equatable {
        case ignored
        case right
        case wrong
    }

    let level: Int
    let options: [Option]
    let oddID: Int

    /// The wrong pictures already tapped, so the view can dim them. A wrong
    /// tap costs nothing else: the child simply keeps looking.
    private(set) var wrongPicks: Set<Int> = []
    private(set) var isSolved = false

    /// Builds the round for a level. `level` is one-based.
    static func make(level: Int, using generator: inout some RandomNumberGenerator) -> OddOneOutRound {
        let tier = OddOneOutCatalog.tier(forLevel: level)
        let puzzle = tier.puzzles.randomElement(using: &generator)
            ?? OddOneOutCatalog.fallbackPuzzle

        let family = puzzle.family.shuffled(using: &generator).prefix(max(1, tier.optionCount - 1))
        let outsider = puzzle.outsiders.randomElement(using: &generator) ?? "🍕"

        var emojis = Array(family)
        let position = Int.random(in: 0 ... emojis.count, using: &generator)
        emojis.insert(outsider, at: position)

        return OddOneOutRound(
            level: level,
            options: emojis.enumerated().map { Option(id: $0.offset, emoji: $0.element) },
            oddID: position
        )
    }

    /// Test seam: a round with the pictures and answer spelled out.
    init(level: Int, emojis: [String], oddIndex: Int) {
        self.init(
            level: level,
            options: emojis.enumerated().map { Option(id: $0.offset, emoji: $0.element) },
            oddID: oddIndex
        )
    }

    private init(level: Int, options: [Option], oddID: Int) {
        self.level = level
        self.options = options
        self.oddID = oddID
    }

    func isWrong(_ id: Int) -> Bool { wrongPicks.contains(id) }

    @discardableResult
    mutating func pick(_ id: Int) -> Outcome {
        guard !isSolved,
              options.contains(where: { $0.id == id }),
              !wrongPicks.contains(id) else {
            return .ignored
        }

        guard id == oddID else {
            wrongPicks.insert(id)
            return .wrong
        }

        isSolved = true
        return .right
    }
}

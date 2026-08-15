import Foundation

/// The single place where the three freemium limits live. Every screen that can
/// add a profile, a tile or a media item asks this type first, so the free and
/// paid rules never drift apart.
enum ProGate {
    enum Limit: Equatable, Sendable {
        case profiles
        case tilesPerProfile
        case mediaItemsPerTile

        func maximum(isPro: Bool) -> Int {
            switch self {
            case .profiles:
                return isPro ? Int.max : 1
            case .tilesPerProfile:
                return isPro ? Int.max : 5
            case .mediaItemsPerTile:
                return isPro ? 50 : 7
            }
        }
    }

    /// Whether one more item may be added given how many already exist.
    static func canAdd(_ limit: Limit, currentCount: Int, isPro: Bool) -> Bool {
        currentCount < limit.maximum(isPro: isPro)
    }

    /// Remaining slots, or `nil` when unlimited.
    static func remaining(_ limit: Limit, currentCount: Int, isPro: Bool) -> Int? {
        let maximum = limit.maximum(isPro: isPro)
        guard maximum != Int.max else { return nil }
        return max(0, maximum - currentCount)
    }

    /// The message shown when the parent runs into a limit.
    static func limitMessage(for limit: Limit, isPro: Bool) -> String {
        if isPro {
            switch limit {
            case .mediaItemsPerTile:
                return String(
                    localized: "A playlist can hold up to 50 items.",
                    comment: "Paid tier media item limit reached"
                )
            case .profiles, .tilesPerProfile:
                return ""
            }
        }

        switch limit {
        case .profiles:
            return String(
                localized: "The free version includes one child profile. Unlock Kidtopia for unlimited profiles.",
                comment: "Free tier profile limit reached"
            )
        case .tilesPerProfile:
            return String(
                localized: "The free version includes five tiles per profile. Unlock Kidtopia for unlimited tiles.",
                comment: "Free tier tile limit reached"
            )
        case .mediaItemsPerTile:
            return String(
                localized: "The free version holds seven items per playlist. Unlock Kidtopia for up to 50.",
                comment: "Free tier media item limit reached"
            )
        }
    }
}

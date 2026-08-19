import Foundation

/// The single place where the freemium limits live. Every screen that can add a
/// profile, a tile or a media item asks this type first, so the free and paid
/// rules never drift apart.
///
/// `hasFullAccess` is the answer to "is everything open", which a purchase and a
/// running trial both produce. Nothing here needs to tell them apart.
enum ProGate {
    enum Limit: Equatable, Sendable {
        case profiles
        case tilesPerProfile
        case mediaItemsPerTile
        case gamesPerProfile

        func maximum(hasFullAccess: Bool) -> Int {
            switch self {
            case .profiles:
                return hasFullAccess ? Int.max : 1
            case .tilesPerProfile:
                return hasFullAccess ? Int.max : 5
            case .mediaItemsPerTile:
                return hasFullAccess ? 50 : 3
            case .gamesPerProfile:
                return hasFullAccess ? Int.max : 2
            }
        }
    }

    /// Whether one more item may be added given how many already exist.
    static func canAdd(_ limit: Limit, currentCount: Int, hasFullAccess: Bool) -> Bool {
        currentCount < limit.maximum(hasFullAccess: hasFullAccess)
    }

    /// Remaining slots, or `nil` when unlimited.
    static func remaining(_ limit: Limit, currentCount: Int, hasFullAccess: Bool) -> Int? {
        let maximum = limit.maximum(hasFullAccess: hasFullAccess)
        guard maximum != Int.max else { return nil }
        return max(0, maximum - currentCount)
    }

    /// The message shown when the parent runs into a limit.
    static func limitMessage(for limit: Limit, hasFullAccess: Bool) -> String {
        if hasFullAccess {
            switch limit {
            case .mediaItemsPerTile:
                return String(
                    localized: "A playlist can hold up to 50 items.",
                    comment: "Paid tier media item limit reached"
                )
            case .profiles, .tilesPerProfile, .gamesPerProfile:
                return ""
            }
        }

        switch limit {
        case .profiles:
            return String(
                localized: "The free version includes one child profile. Unlock Burrow for unlimited profiles.",
                comment: "Free tier profile limit reached"
            )
        case .tilesPerProfile:
            return String(
                localized: "The free version includes five tiles per profile. Unlock Burrow for unlimited tiles.",
                comment: "Free tier tile limit reached"
            )
        case .mediaItemsPerTile:
            return String(
                localized: "The free version holds three items per playlist. Unlock Burrow for up to 50.",
                comment: "Free tier media item limit reached"
            )
        case .gamesPerProfile:
            return String(
                localized: "The free version includes two games per profile. Unlock Burrow for all of them.",
                comment: "Free tier game limit reached"
            )
        }
    }
}

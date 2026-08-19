import Foundation

/// What may still be heard once the app is no longer on screen.
///
/// Two separate questions, deliberately kept apart. Whether a *playlist* carries
/// on is the parent's call through the profile, narrowed to music: a video tile
/// playing on in a pocket is never what anyone meant. Whether an *entry* can be
/// heard is a platform fact, not a preference — a YouTube entry plays through a
/// web view, and iOS suspends those along with the app.
enum BackgroundPlayback {
    /// What a playlist that was suspended should do when the app comes back.
    ///
    /// The split is a platform fact rather than a taste: the music engines keep
    /// their exact position while the app is away, so starting them again is
    /// seamless, whereas a YouTube embed has to be rebuilt and therefore begins
    /// at 0:00. A song coming back from its start is a small thing; a long
    /// picture doing it, unasked and out loud, is not — so a video comes back
    /// paused, with the player's one big button waiting.
    ///
    /// Keyed on the tile's category, not on the entry: a music tile holding a
    /// YouTube entry does start that entry over at 0:00, which is the mild end
    /// of the same trade.
    enum Resumption: Equatable, Sendable {
        /// Start playing again by itself.
        case playAgain
        /// Stay on screen, paused, and wait to be pressed.
        case waitForChild
        /// Nothing worth coming back to; clear the player.
        case giveUp
    }

    /// Whether the child finds their playlist playing, waiting, or gone.
    static func resumption(
        category: TileCategory,
        hasExhaustedPlaylist: Bool,
        screenTimeHasExpired: Bool
    ) -> Resumption {
        // A session that ran out while the app was away must not be handed a
        // fresh picture, and a playlist that had already failed its way to the
        // end has nothing to give back.
        if screenTimeHasExpired || hasExhaustedPlaylist { return .giveUp }

        return category == .music ? .playAgain : .waitForChild
    }

    /// Whether a running playlist should survive the app leaving the foreground.
    static func survivesBackgrounding(category: TileCategory, allowsLockScreenPlayback: Bool) -> Bool {
        category == .music && allowsLockScreenPlayback
    }

    /// Whether an entry of this kind can still be heard in the background.
    static func playsInBackground(_ type: MediaSourceType) -> Bool {
        type != .youtube
    }

    /// The next entry that can still be heard, or `nil` when the playlist holds
    /// none.
    ///
    /// `index` is the entry that has just been found inaudible, so it is never
    /// returned — a looping playlist would otherwise come back to the silence it
    /// was trying to leave.
    static func firstBackgroundPlayableIndex(
        after index: Int,
        in types: [MediaSourceType],
        loop: Bool
    ) -> Int? {
        guard !types.isEmpty else { return nil }

        if let ahead = types.indices
            .filter({ $0 > index })
            .first(where: { playsInBackground(types[$0]) }) {
            return ahead
        }

        guard loop else { return nil }

        return types.indices
            .filter { $0 < index }
            .first { playsInBackground(types[$0]) }
    }
}

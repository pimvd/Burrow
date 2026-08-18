import Foundation

/// What may still be heard once the app is no longer on screen.
///
/// Two separate questions, deliberately kept apart. Whether a *playlist* carries
/// on is the parent's call through the profile, narrowed to music: a video tile
/// playing on in a pocket is never what anyone meant. Whether an *entry* can be
/// heard is a platform fact, not a preference — a YouTube entry plays through a
/// web view, and iOS suspends those along with the app.
enum BackgroundPlayback {
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

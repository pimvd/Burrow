import Foundation

/// The one place the YouTube caveat is written.
///
/// YouTube playback is the only part of Burrow that depends on somebody else's
/// permission. Everything else — local audio and video, the games, the tiles
/// themselves — keeps working whatever Google decides. That difference is worth
/// telling a parent plainly, before they build a playlist on it and before they
/// pay, rather than on the day it stops.
///
/// The add screen, the purchase screen and `website/support.html` all say this,
/// so it lives here once and cannot drift between them.
enum YouTubeSupportNotice {
    /// For a footer under something the parent is doing right now.
    static var short: String {
        String(
            localized: """
            YouTube videos play through Google's own embedded player. Burrow \
            supports them for as long as YouTube allows it — that is Google's \
            decision, not ours, and it can change. Files you add from your own \
            device never depend on it.
            """,
            comment: "YouTube support caveat, shown where a link is added"
        )
    }

    /// For the purchase screen, where it also has to say what is *not* being
    /// bought.
    static var full: String {
        String(
            localized: """
            Unlocking lifts Burrow's own limits: profiles, tiles, playlist \
            length and games. YouTube is not part of it. YouTube videos play \
            through Google's embedded player, and Burrow can offer them only \
            for as long as YouTube permits it. If that changes, YouTube items \
            will stop playing and no update can bring them back. Your own \
            audio and video files, and Apple Music, are not affected.
            """,
            comment: "YouTube support caveat, shown before purchase"
        )
    }
}

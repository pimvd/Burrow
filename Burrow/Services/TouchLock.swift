import Foundation

/// The rules of the player's touch lock: the thing a parent turns on before
/// handing over a running video, so that nothing the child touches does
/// anything.
///
/// Named for touches rather than for the screen, to keep it apart from
/// `ChildProfile.lockScreenPlaybackEnabled`, which is about iOS's own lock
/// screen and has nothing to do with this.
///
/// There is no clock and no SwiftUI in here, so the two rules that matter can be
/// tested directly. A touch on a locked player never reaches what is underneath
/// it: all it does is bring the way out back, so a palm on the glass or a run of
/// excited taps can neither pause the video nor close the player. And the way
/// out is a press and hold rather than a tap — no keyboard in the way, so a
/// parent can do it one-handed with the device still in a child's hands, and
/// long enough that nothing accidental ever reaches the end of it.
struct TouchLock: Equatable, Sendable {
    /// How long the way out has to be held before it opens. Long enough to be
    /// out of reach of anything accidental, short enough that a parent does not
    /// let go wondering whether it worked.
    static let unlockHold: TimeInterval = 3

    /// How long the way out stays on screen after a touch. Deliberately longer
    /// than `unlockHold`, so a hold begun the moment the button appears cannot
    /// be spoilt by the button fading out from under the finger.
    static let unlockLinger: TimeInterval = 4

    private(set) var isLocked = false

    /// Whether the way out is on screen. It shows itself as the lock closes, so
    /// the parent is told how to undo what they just did, and it comes back on
    /// any touch afterwards.
    private(set) var showsUnlock = false

    /// Bumped on every reveal, so the view can start the fade-out countdown
    /// again even when the way out is already showing.
    private(set) var revealCount = 0

    mutating func lock() {
        isLocked = true
        reveal()
    }

    mutating func unlock() {
        isLocked = false
        showsUnlock = false
    }

    /// A touch anywhere on the locked player, the way out included. Nothing is
    /// passed on; the touch only brings the way out back.
    mutating func touched() {
        guard isLocked else { return }
        reveal()
    }

    /// The way out fading again because nobody used it. The lock stays closed:
    /// only a hold that runs its course opens it.
    mutating func hideUnlock() {
        showsUnlock = false
    }

    private mutating func reveal() {
        showsUnlock = true
        revealCount += 1
    }
}

import Foundation
import Observation

/// Tracks whether the parental gate has been passed for the current app run.
///
/// The unlock survives navigation inside Settings, but is dropped as soon as the
/// app is fully backgrounded, so reopening the app always asks again.
@Observable
@MainActor
final class ParentSessionState {
    private(set) var isUnlocked = false

    func unlock() {
        isUnlocked = true
    }

    func lock() {
        isUnlocked = false
    }

    /// Called when the app moves to the background.
    func applicationDidEnterBackground() {
        lock()
    }
}

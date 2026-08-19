import Foundation
import Observation

/// Remembers when the parent started the free trial and reports whether it is
/// still running.
///
/// The start date lives in `UserDefaults` rather than in the synced store: it is
/// a property of this installation, not of the family's content, and the parent
/// should not have their trial consumed on a new iPad by a device they no longer
/// own. The trade-off is that reinstalling the app starts a fresh trial. That is
/// deliberate — the alternative is a server, and Burrow does not have one.
@Observable
@MainActor
final class TrialService {
    /// One key, read in two places, so it is named once.
    private static let startedAtKey = "trial.startedAt"

    private let defaults: UserDefaults

    /// Recomputed rather than derived on the fly, so a view redraws when the
    /// trial runs out. ``refresh()`` is what moves it.
    private(set) var state: Trial.State

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        state = Trial.state(startedAt: Self.startedAt(in: defaults), now: .now)
    }

    /// Re-reads the clock. Called at launch and whenever the app comes forward,
    /// which is also when the parental gate closes, so a trial can never expire
    /// unnoticed behind an open parent screen.
    func refresh(now: Date = .now) {
        state = Trial.state(startedAt: Self.startedAt(in: defaults), now: now)
    }

    /// Starts the trial. Does nothing if one was ever started before, so the
    /// offer cannot be taken twice.
    func start(now: Date = .now) {
        guard !state.hasStarted else { return }
        defaults.set(now.timeIntervalSince1970, forKey: Self.startedAtKey)
        refresh(now: now)
    }

    private static func startedAt(in defaults: UserDefaults) -> Date? {
        let stored = defaults.double(forKey: startedAtKey)
        guard stored > 0 else { return nil }
        return Date(timeIntervalSince1970: stored)
    }
}

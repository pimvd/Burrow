import Foundation
import Observation

/// Holds the date the parent started the free trial and reports whether it is
/// still running.
///
/// The trial is a free non-consumable in the App Store, so its start date is the
/// purchase date of that transaction and `StoreManager` hands it in. That ties
/// the trial to the parent's Apple Account rather than to this installation:
/// reinstalling does not start a new one, and a new device sees the same trial.
@Observable
@MainActor
final class TrialService {
    private var startedAt: Date?

    /// Recomputed rather than derived on the fly, so a view redraws when the
    /// trial runs out. ``refresh()`` is what moves it.
    private(set) var state: Trial.State

    init(startedAt: Date? = nil, now: Date = .now) {
        self.startedAt = startedAt
        state = Trial.state(startedAt: startedAt, now: now)
    }

    /// Re-reads the clock. Called at launch and whenever the app comes forward,
    /// which is also when the parental gate closes, so a trial can never expire
    /// unnoticed behind an open parent screen.
    func refresh(now: Date = .now) {
        state = Trial.state(startedAt: startedAt, now: now)
    }

    /// Takes the start date from the store's entitlements. `nil` means no trial
    /// was ever taken, or it was refunded.
    func record(startedAt: Date?, now: Date = .now) {
        self.startedAt = startedAt
        refresh(now: now)
    }
}

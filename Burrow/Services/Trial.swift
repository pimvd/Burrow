import Foundation

/// The rules of the one-off free trial, with no storage and no clock of their
/// own so they can be tested directly.
///
/// StoreKit only offers introductory offers on subscriptions, and Burrow sells a
/// non-consumable, so the trial has to be the app's own: one start date, and
/// everything open until it runs out.
enum Trial {
    /// How long a started trial lasts.
    static let length: TimeInterval = 14 * 24 * 60 * 60

    /// Whole days, for the parent-facing count.
    static var lengthInDays: Int { Int(length / 86_400) }

    struct State: Equatable, Sendable {
        /// The trial was started at some point, whether or not it still runs. A
        /// trial is offered once, so this is what takes the offer away.
        var hasStarted: Bool
        /// Everything is open right now because of the trial.
        var isActive: Bool
        /// Days left, rounded up, so the last part-day still reads as "1 day".
        /// Zero whenever the trial is not running.
        var daysRemaining: Int

        static let notStarted = State(hasStarted: false, isActive: false, daysRemaining: 0)
    }

    /// Derives the trial state from the stored start date.
    ///
    /// A `startedAt` in the future means the device clock moved backwards after
    /// the trial began. Rather than hand out an unbounded trial, that case is
    /// treated as if the trial had just started.
    static func state(startedAt: Date?, now: Date) -> State {
        guard let startedAt else { return .notStarted }

        let elapsed = max(0, now.timeIntervalSince(startedAt))
        let remaining = length - elapsed
        guard remaining > 0 else {
            return State(hasStarted: true, isActive: false, daysRemaining: 0)
        }

        return State(
            hasStarted: true,
            isActive: true,
            daysRemaining: max(1, Int((remaining / 86_400).rounded(.up)))
        )
    }
}

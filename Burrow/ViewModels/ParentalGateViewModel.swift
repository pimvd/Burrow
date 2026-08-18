import Foundation
import Observation

/// Validates the birth year the parent enters.
///
/// The failure message is deliberately generic and identical for every kind of
/// wrong answer, so a child cannot learn the rule by trial and error.
@Observable
@MainActor
final class ParentalGateViewModel {
    static let earliestYear = 1900
    static let minimumAgeYears = 16

    var enteredYearText: String = ""
    private(set) var showsFailure = false

    /// The newest year that still passes, i.e. someone who is at least 16.
    static func latestValidYear(now: Date = Date(), calendar: Calendar = .current) -> Int {
        calendar.component(.year, from: now) - minimumAgeYears
    }

    var enteredYear: Int? {
        Int(enteredYearText.trimmingCharacters(in: .whitespaces))
    }

    /// A sensible starting value for the stepper.
    static var defaultYear: Int { latestValidYear() - 15 }

    func adjustYear(by delta: Int) {
        let current = enteredYear ?? Self.defaultYear
        let adjusted = min(max(current + delta, Self.earliestYear), Calendar.current.component(.year, from: Date()))
        enteredYearText = String(adjusted)
        showsFailure = false
    }

    func clearFailure() {
        showsFailure = false
    }

    /// Returns `true` when the entered year unlocks the parent area.
    func validate(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let year = enteredYear,
              year >= Self.earliestYear,
              year <= Self.latestValidYear(now: now, calendar: calendar) else {
            showsFailure = true
            return false
        }
        showsFailure = false
        return true
    }
}

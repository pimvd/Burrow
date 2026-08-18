import Foundation
import Observation

/// Holds the statistics screen's selection: which profile (or the whole
/// household) and over which period.
@Observable
@MainActor
final class StatisticsViewModel {
    /// `nil` means "everyone together".
    var selectedProfileID: UUID?
    var preset: StatisticsPreset = .week
    var customStart: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    var customEnd: Date = Date()

    /// The range currently in effect.
    func range(now: Date = Date(), calendar: Calendar = .current) -> StatisticsRange {
        if let preset = preset.range(now: now, calendar: calendar) {
            return preset
        }
        let start = calendar.startOfDay(for: min(customStart, customEnd))
        let end = calendar.date(
            bySettingHour: 23,
            minute: 59,
            second: 59,
            of: max(customStart, customEnd)
        ) ?? max(customStart, customEnd)
        return StatisticsRange(start: start, end: end)
    }

    func sessions(from all: [UsageSession], tileID: UUID? = nil) -> [UsageSession] {
        StatisticsService.filter(
            all,
            profileID: selectedProfileID,
            tileID: tileID,
            range: range()
        )
    }
}

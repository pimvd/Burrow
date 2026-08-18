import Foundation

/// A closed date range the statistics are computed over.
struct StatisticsRange: Equatable, Sendable {
    var start: Date
    var end: Date

    func contains(_ date: Date) -> Bool {
        date >= start && date <= end
    }
}

/// The ready-made ranges the parent can pick, next to a custom one.
enum StatisticsPreset: String, CaseIterable, Identifiable, Sendable {
    case day
    case week
    case month
    case allTime
    case custom

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .day: return String(localized: "Day", comment: "Statistics range preset")
        case .week: return String(localized: "Week", comment: "Statistics range preset")
        case .month: return String(localized: "Month", comment: "Statistics range preset")
        case .allTime: return String(localized: "All time", comment: "Statistics range preset")
        case .custom: return String(localized: "Custom", comment: "Statistics range preset")
        }
    }

    /// Resolves the preset into concrete dates. `custom` returns `nil`, because
    /// the parent supplies both ends itself.
    func range(now: Date = Date(), calendar: Calendar = .current) -> StatisticsRange? {
        let endOfToday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now

        switch self {
        case .day:
            let start = calendar.startOfDay(for: now)
            return StatisticsRange(start: start, end: endOfToday)
        case .week:
            let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
            return StatisticsRange(start: start, end: endOfToday)
        case .month:
            let start = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now)) ?? now
            return StatisticsRange(start: start, end: endOfToday)
        case .allTime:
            return StatisticsRange(start: Date.distantPast, end: endOfToday)
        case .custom:
            return nil
        }
    }
}

/// Plain totals — no generated insights, no comparison against a limit.
struct UsageTotals: Equatable, Sendable {
    var totalSeconds: Int = 0
    var openCount: Int = 0

    var formattedDuration: String {
        let minutes = totalSeconds / 60
        if minutes < 60 {
            return String(localized: "\(minutes) min", comment: "Duration in minutes")
        }
        let hours = minutes / 60
        let remainder = minutes % 60
        return String(localized: "\(hours) h \(remainder) min", comment: "Duration in hours and minutes")
    }
}

/// One day in the trend chart.
struct DailyUsagePoint: Identifiable, Equatable, Sendable {
    var id: Date { day }
    let day: Date
    let totalSeconds: Int
    let openCount: Int

    var minutes: Double { Double(totalSeconds) / 60 }
}

/// One hour-of-day bucket, to see when the app is used most.
struct HourlyUsagePoint: Identifiable, Equatable, Sendable {
    var id: Int { hour }
    let hour: Int
    let totalSeconds: Int
    let openCount: Int

    var minutes: Double { Double(totalSeconds) / 60 }
}

/// How often one playlist entry was played.
struct MediaItemPlayCount: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let playCount: Int
    let totalSeconds: Int
}

/// Aggregates `UsageSession` rows into the numbers the statistics screens show.
///
/// Rows come in two shapes (see `UsageRecorder`): open markers with no media
/// item and zero duration, and play rows with a media item and real seconds.
/// Every function here keeps the two apart, so time is never double counted and
/// an open is never counted as a play.
enum StatisticsService {
    static func filter(
        _ sessions: [UsageSession],
        profileID: UUID? = nil,
        tileID: UUID? = nil,
        range: StatisticsRange? = nil
    ) -> [UsageSession] {
        sessions.filter { session in
            if let profileID, session.profileID != profileID { return false }
            if let tileID, session.tileID != tileID { return false }
            if let range, !range.contains(session.startTime) { return false }
            return true
        }
    }

    static func totals(_ sessions: [UsageSession]) -> UsageTotals {
        var totals = UsageTotals()
        for session in sessions {
            if session.mediaItemID == nil {
                totals.openCount += 1
            } else {
                totals.totalSeconds += session.durationSeconds
            }
        }
        return totals
    }

    /// One point per day across the range, including days with no usage, so the
    /// line chart does not skip gaps.
    static func dailyPoints(
        _ sessions: [UsageSession],
        range: StatisticsRange,
        calendar: Calendar = .current,
        maximumDays: Int = 400
    ) -> [DailyUsagePoint] {
        let startDay = calendar.startOfDay(for: max(range.start, earliestDate(in: sessions) ?? range.start))
        let endDay = calendar.startOfDay(for: range.end)
        guard startDay <= endDay else { return [] }

        var buckets: [Date: (seconds: Int, opens: Int)] = [:]
        for session in sessions where range.contains(session.startTime) {
            let day = calendar.startOfDay(for: session.startTime)
            var bucket = buckets[day] ?? (0, 0)
            if session.mediaItemID == nil {
                bucket.opens += 1
            } else {
                bucket.seconds += session.durationSeconds
            }
            buckets[day] = bucket
        }

        var points: [DailyUsagePoint] = []
        var cursor = startDay
        var guardCounter = 0
        while cursor <= endDay && guardCounter < maximumDays {
            let bucket = buckets[cursor] ?? (0, 0)
            points.append(
                DailyUsagePoint(day: cursor, totalSeconds: bucket.seconds, openCount: bucket.opens)
            )
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
            guardCounter += 1
        }
        return points
    }

    /// The last seven days, always exactly seven points.
    static func lastSevenDays(
        _ sessions: [UsageSession],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [DailyUsagePoint] {
        guard let range = StatisticsPreset.week.range(now: now, calendar: calendar) else { return [] }
        var buckets: [Date: (seconds: Int, opens: Int)] = [:]
        for session in sessions where range.contains(session.startTime) {
            let day = calendar.startOfDay(for: session.startTime)
            var bucket = buckets[day] ?? (0, 0)
            if session.mediaItemID == nil {
                bucket.opens += 1
            } else {
                bucket.seconds += session.durationSeconds
            }
            buckets[day] = bucket
        }

        return (0..<7).compactMap { offset -> DailyUsagePoint? in
            guard let day = calendar.date(
                byAdding: .day,
                value: offset - 6,
                to: calendar.startOfDay(for: now)
            ) else { return nil }
            let bucket = buckets[day] ?? (0, 0)
            return DailyUsagePoint(day: day, totalSeconds: bucket.seconds, openCount: bucket.opens)
        }
    }

    /// All 24 hours, so the pattern of the day is visible at a glance.
    static func hourlyPoints(
        _ sessions: [UsageSession],
        calendar: Calendar = .current
    ) -> [HourlyUsagePoint] {
        var seconds = [Int](repeating: 0, count: 24)
        var opens = [Int](repeating: 0, count: 24)

        for session in sessions {
            let hour = calendar.component(.hour, from: session.startTime)
            guard (0..<24).contains(hour) else { continue }
            if session.mediaItemID == nil {
                opens[hour] += 1
            } else {
                seconds[hour] += session.durationSeconds
            }
        }

        return (0..<24).map {
            HourlyUsagePoint(hour: $0, totalSeconds: seconds[$0], openCount: opens[$0])
        }
    }

    /// Play counts per playlist entry, most played first.
    static func playCounts(
        _ sessions: [UsageSession],
        titles: [UUID: String]
    ) -> [MediaItemPlayCount] {
        var counts: [UUID: (plays: Int, seconds: Int)] = [:]
        for session in sessions {
            guard let itemID = session.mediaItemID else { continue }
            var bucket = counts[itemID] ?? (0, 0)
            bucket.plays += 1
            bucket.seconds += session.durationSeconds
            counts[itemID] = bucket
        }

        return counts
            .map { itemID, bucket in
                MediaItemPlayCount(
                    id: itemID,
                    title: titles[itemID] ?? String(localized: "Removed item", comment: "Deleted media item in statistics"),
                    playCount: bucket.plays,
                    totalSeconds: bucket.seconds
                )
            }
            .sorted { lhs, rhs in
                lhs.playCount == rhs.playCount
                    ? lhs.totalSeconds > rhs.totalSeconds
                    : lhs.playCount > rhs.playCount
            }
    }

    /// Totals per tile, most used first.
    static func totalsPerTile(_ sessions: [UsageSession]) -> [(tileID: UUID, totals: UsageTotals)] {
        var grouped: [UUID: [UsageSession]] = [:]
        for session in sessions {
            grouped[session.tileID, default: []].append(session)
        }
        return grouped
            .map { (tileID: $0.key, totals: totals($0.value)) }
            .sorted { $0.totals.totalSeconds > $1.totals.totalSeconds }
    }

    private static func earliestDate(in sessions: [UsageSession]) -> Date? {
        sessions.map(\.startTime).min()
    }
}

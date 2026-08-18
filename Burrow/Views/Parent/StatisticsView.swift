import Charts
import SwiftData
import SwiftUI

/// Plain usage numbers for the parent: per profile or for the whole household,
/// with a seven-day trend, an hourly pattern and a per-tile breakdown.
struct StatisticsView: View {
    @Query private var sessions: [UsageSession]
    @Query(sort: \ChildProfile.sortOrder) private var profiles: [ChildProfile]
    @Query private var tiles: [Tile]

    @State private var viewModel = StatisticsViewModel()

    private var scopedSessions: [UsageSession] {
        viewModel.sessions(from: sessions)
    }

    private var totals: UsageTotals {
        StatisticsService.totals(scopedSessions)
    }

    private var sevenDayPoints: [DailyUsagePoint] {
        StatisticsService.lastSevenDays(
            StatisticsService.filter(sessions, profileID: viewModel.selectedProfileID)
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        List {
            Section {
                Picker(selection: $viewModel.selectedProfileID) {
                    Text("Everyone", comment: "Household-wide statistics scope")
                        .tag(UUID?.none)
                    ForEach(profiles) { profile in
                        Text(profile.name).tag(Optional(profile.id))
                    }
                } label: {
                    Text("Profile", comment: "Statistics scope picker")
                }

                Picker(selection: $viewModel.preset) {
                    ForEach(StatisticsPreset.allCases) { preset in
                        Text(preset.localizedTitle).tag(preset)
                    }
                } label: {
                    Text("Period", comment: "Statistics period picker")
                }

                if viewModel.preset == .custom {
                    DatePicker(
                        selection: $viewModel.customStart,
                        displayedComponents: .date
                    ) {
                        Text("From", comment: "Custom range start")
                    }
                    DatePicker(
                        selection: $viewModel.customEnd,
                        displayedComponents: .date
                    ) {
                        Text("To", comment: "Custom range end")
                    }
                }
            }

            Section {
                TotalsRow(totals: totals)
            } header: {
                Text("Total", comment: "Statistics section")
            }

            Section {
                SevenDayChart(points: sevenDayPoints)
            } header: {
                Text("Last 7 days", comment: "Statistics section")
            }

            Section {
                HourlyChart(points: StatisticsService.hourlyPoints(scopedSessions))
            } header: {
                Text("Time of day", comment: "Statistics section")
            } footer: {
                Text(
                    "Shows at which hours Burrow is used most within the chosen period.",
                    comment: "Hourly chart explanation"
                )
            }

            Section {
                let perTile = StatisticsService.totalsPerTile(scopedSessions)
                if perTile.isEmpty {
                    Text("Nothing used yet in this period.", comment: "Empty statistics")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(perTile, id: \.tileID) { entry in
                        NavigationLink {
                            TileStatisticsView(tileID: entry.tileID)
                        } label: {
                            TileTotalsRow(
                                title: tileTitle(for: entry.tileID),
                                totals: entry.totals
                            )
                        }
                    }
                }
            } header: {
                Text("Per tile", comment: "Statistics section")
            }
        }
        .navigationTitle(Text("Statistics", comment: "Statistics title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tileTitle(for tileID: UUID) -> String {
        if let tile = tiles.first(where: { $0.id == tileID }) {
            return tile.title
        }
        // Game rows carry the game's catalog UUID in place of a tile ID.
        if let game = GameCatalog.game(id: tileID) {
            return game.localizedTitle
        }
        return String(localized: "Removed tile", comment: "Deleted tile in statistics")
    }
}

// MARK: - Shared pieces

struct TotalsRow: View {
    let totals: UsageTotals

    var body: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Playback time", comment: "Statistics metric")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(totals.formattedDuration)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Times opened", comment: "Statistics metric")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(totals.openCount)")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

struct SevenDayChart: View {
    let points: [DailyUsagePoint]

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value(String(localized: "Day", comment: "Chart axis"), point.day, unit: .day),
                y: .value(String(localized: "Minutes", comment: "Chart axis"), point.minutes)
            )
            .interpolationMethod(.monotone)

            PointMark(
                x: .value(String(localized: "Day", comment: "Chart axis"), point.day, unit: .day),
                y: .value(String(localized: "Minutes", comment: "Chart axis"), point.minutes)
            )
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.weekday(.narrow))
            }
        }
        .frame(height: 180)
        .padding(.vertical, 8)
        .accessibilityLabel(Text("Playback minutes per day over the last seven days", comment: "Chart accessibility"))
    }
}

struct HourlyChart: View {
    let points: [HourlyUsagePoint]

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value(String(localized: "Hour", comment: "Chart axis"), point.hour),
                y: .value(String(localized: "Minutes", comment: "Chart axis"), point.minutes)
            )
        }
        .chartXScale(domain: 0...23)
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let hour = value.as(Int.self) {
                        Text("\(hour):00", comment: "Hour of day axis label")
                    }
                }
            }
        }
        .frame(height: 150)
        .padding(.vertical, 8)
        .accessibilityLabel(Text("Playback minutes per hour of the day", comment: "Chart accessibility"))
    }
}

struct TileTotalsRow: View {
    let title: String
    let totals: UsageTotals

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline)
            Text(
                "\(totals.formattedDuration) · \(totals.openCount)x opened",
                comment: "Per tile totals subtitle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

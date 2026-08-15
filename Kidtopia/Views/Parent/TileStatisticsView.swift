import Charts
import SwiftData
import SwiftUI

/// Statistics for one tile, including which entry in its playlist is played
/// most. Reachable from the statistics list and directly from the tile editor.
struct TileStatisticsView: View {
    let tileID: UUID

    @Query private var sessions: [UsageSession]
    @Query private var tiles: [Tile]

    @State private var viewModel = StatisticsViewModel()

    private var tile: Tile? {
        tiles.first { $0.id == tileID }
    }

    private var scopedSessions: [UsageSession] {
        viewModel.sessions(from: sessions, tileID: tileID)
    }

    private var itemTitles: [UUID: String] {
        guard let tile else { return [:] }
        return Dictionary(
            tile.orderedMediaItems.map { ($0.id, $0.title) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        List {
            Section {
                Picker(selection: $viewModel.preset) {
                    ForEach(StatisticsPreset.allCases) { preset in
                        Text(preset.localizedTitle).tag(preset)
                    }
                } label: {
                    Text("Period", comment: "Statistics period picker")
                }

                if viewModel.preset == .custom {
                    DatePicker(selection: $viewModel.customStart, displayedComponents: .date) {
                        Text("From", comment: "Custom range start")
                    }
                    DatePicker(selection: $viewModel.customEnd, displayedComponents: .date) {
                        Text("To", comment: "Custom range end")
                    }
                }
            }

            Section {
                TotalsRow(totals: StatisticsService.totals(scopedSessions))
            } header: {
                Text("Total", comment: "Statistics section")
            }

            Section {
                SevenDayChart(
                    points: StatisticsService.lastSevenDays(
                        StatisticsService.filter(sessions, tileID: tileID)
                    )
                )
            } header: {
                Text("Last 7 days", comment: "Statistics section")
            }

            Section {
                let counts = StatisticsService.playCounts(scopedSessions, titles: itemTitles)
                if counts.isEmpty {
                    Text("Nothing played yet in this period.", comment: "Empty statistics")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(counts) { entry in
                        LabeledContent {
                            Text("\(entry.playCount)x")
                                .monospacedDigit()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title)
                                Text(
                                    UsageTotals(totalSeconds: entry.totalSeconds, openCount: 0).formattedDuration
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Per item", comment: "Statistics section")
            } footer: {
                Text(
                    "Shows which song or video within this tile is played most.",
                    comment: "Per item statistics explanation"
                )
            }
        }
        .navigationTitle(
            Text(tile?.title ?? String(localized: "Tile", comment: "Fallback tile title"))
        )
        .navigationBarTitleDisplayMode(.inline)
    }
}

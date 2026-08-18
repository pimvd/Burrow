import SwiftData
import SwiftUI

/// The root of the parent area: everything a grown-up can manage.
struct ParentSettingsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(StoreManager.self) private var store
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ChildProfile.sortOrder) private var profiles: [ChildProfile]
    @Query private var tiles: [Tile]

    @State private var isShowingDataCleanup = false
    @State private var reminderEnabled = BackupReminderService.shared.isReminderEnabled

    private var activeTiles: [Tile] { tiles.filter { !$0.isTrashed } }
    private var trashedTiles: [Tile] { tiles.filter(\.isTrashed) }

    var body: some View {
        List {
            Section {
                NavigationLink(value: ParentDestination.profiles) {
                    Label {
                        LabeledContent {
                            Text("\(profiles.count)")
                        } label: {
                            Text("Profiles", comment: "Parent settings row")
                        }
                    } icon: {
                        Image(systemName: "person.2")
                    }
                }

                NavigationLink(value: ParentDestination.tiles) {
                    Label {
                        LabeledContent {
                            Text("\(activeTiles.count)")
                        } label: {
                            Text("Tiles", comment: "Parent settings row")
                        }
                    } icon: {
                        Image(systemName: "square.grid.2x2")
                    }
                }

                NavigationLink(value: ParentDestination.games) {
                    Label {
                        Text("Games", comment: "Parent settings row")
                    } icon: {
                        Image(systemName: "gamecontroller")
                    }
                }

                NavigationLink(value: ParentDestination.trash) {
                    Label {
                        LabeledContent {
                            Text("\(trashedTiles.count)")
                        } label: {
                            Text("Trash", comment: "Parent settings row")
                        }
                    } icon: {
                        Image(systemName: "trash")
                    }
                }
            } header: {
                Text("Content", comment: "Parent settings section")
            } footer: {
                Text(
                    "Deleted tiles stay in the trash for 14 days and are then removed for good, together with their statistics.",
                    comment: "Trash retention explanation"
                )
            }

            Section {
                NavigationLink(value: ParentDestination.statistics) {
                    Label(
                        String(localized: "Statistics", comment: "Parent settings row"),
                        systemImage: "chart.xyaxis.line"
                    )
                }
            } header: {
                Text("Usage", comment: "Parent settings section")
            }

            Section {
                NavigationLink(value: ParentDestination.exportImport) {
                    Label(
                        String(localized: "Export and import", comment: "Parent settings row"),
                        systemImage: "arrow.up.arrow.down.square"
                    )
                }

                Toggle(isOn: $reminderEnabled) {
                    Label(
                        String(localized: "Monthly backup reminder", comment: "Parent settings row"),
                        systemImage: "bell.badge"
                    )
                }
                .onChange(of: reminderEnabled) { _, enabled in
                    Task { await BackupReminderService.shared.setReminderEnabled(enabled) }
                }

                Button {
                    isShowingDataCleanup = true
                } label: {
                    Label(
                        String(localized: "Clear usage data", comment: "Parent settings row"),
                        systemImage: "eraser"
                    )
                }
            } header: {
                Text("Backup and data", comment: "Parent settings section")
            } footer: {
                Text(
                    "Your content syncs automatically across your own devices through iCloud. An export is an extra copy you keep yourself.",
                    comment: "iCloud and export explanation"
                )
            }

            Section {
                if store.isPro {
                    Label {
                        Text("Burrow is unlocked", comment: "Purchase state")
                    } icon: {
                        Image(systemName: "checkmark.seal")
                    }
                    .foregroundStyle(.secondary)
                } else {
                    NavigationLink(value: ParentDestination.purchase) {
                        Label(
                            String(localized: "Unlock Burrow", comment: "Parent settings row"),
                            systemImage: "sparkles"
                        )
                    }
                }
            } header: {
                Text("Burrow", comment: "Parent settings section")
            } footer: {
                Text(
                    "One-time purchase. No ads, no subscriptions, and nothing about your family leaves your devices.",
                    comment: "Privacy promise"
                )
            }
        }
        .navigationTitle(Text("For grown-ups", comment: "Parent area title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.closeParentArea()
                } label: {
                    Text("Done", comment: "Close the parent area")
                }
            }
        }
        .sheet(isPresented: $isShowingDataCleanup) {
            UsageDataCleanupView()
        }
        .task {
            reminderEnabled = BackupReminderService.shared.isReminderEnabled
            TrashService.purgeExpiredTiles(in: modelContext)
        }
    }
}

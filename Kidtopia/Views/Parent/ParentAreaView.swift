import SwiftUI

/// Wraps the whole parent hierarchy. Until the gate is passed it shows only the
/// birth-year prompt; afterwards the settings root, optionally opened straight
/// at a deep link such as one tile's statistics.
struct ParentAreaView: View {
    @Environment(ParentSessionState.self) private var parentSession
    @Environment(AppRouter.self) private var router

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if parentSession.isUnlocked {
                    ParentSettingsView()
                } else {
                    ParentalGateView()
                }
            }
            .navigationDestination(for: ParentDestination.self) { destination in
                view(for: destination)
            }
        }
        .onChange(of: parentSession.isUnlocked, initial: true) { _, unlocked in
            guard unlocked, let pending = router.pendingParentDestination else { return }
            path.append(pending)
            router.pendingParentDestination = nil
        }
    }

    @ViewBuilder
    private func view(for destination: ParentDestination) -> some View {
        switch destination {
        case .profiles:
            ProfileListView()
        case .tiles:
            TileListView()
        case .statistics:
            StatisticsView()
        case .tileStatistics(let tileID):
            TileStatisticsView(tileID: tileID)
        case .trash:
            TrashView()
        case .exportImport:
            ExportImportView()
        case .purchase:
            PurchaseView()
        }
    }
}

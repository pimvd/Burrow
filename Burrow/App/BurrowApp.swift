import SwiftData
import SwiftUI

@main
struct BurrowApp: App {
    @State private var parentSession = ParentSessionState()
    @State private var router = AppRouter()
    @State private var store = StoreManager()
    @State private var connectivity = ConnectivityMonitor()
    @State private var playback = MediaPlaybackService()
    @State private var screenTime = ScreenTimeCoordinator()
    @State private var cloudSync: CloudSyncStatus

    private let container: ModelContainer

    init() {
        // The App Store screenshots run on made-up data in memory, never on
        // the parent's own store (see ScreenshotMode).
        container = ScreenshotMode.isActive
            ? ScreenshotMode.makeContainer()
            : ModelContainerFactory.makeContainer()
        // Built after the container, because it reports on the store that was
        // actually opened.
        _cloudSync = State(initialValue: CloudSyncStatus())
        MediaLibrary.shared.ensureDirectoryExists()
        BackupReminderService.shared.registerAsDelegate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(parentSession)
                .environment(router)
                .environment(store)
                .environment(connectivity)
                .environment(playback)
                .environment(screenTime)
                .environment(cloudSync)
                .tint(Color.accentColor)
        }
        .modelContainer(container)
    }
}

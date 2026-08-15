import SwiftData
import SwiftUI

@main
struct KidtopiaApp: App {
    @State private var parentSession = ParentSessionState()
    @State private var router = AppRouter()
    @State private var store = StoreManager()
    @State private var connectivity = ConnectivityMonitor()
    @State private var playback = MediaPlaybackService()
    @State private var screenTime = ScreenTimeCoordinator()

    private let container: ModelContainer

    init() {
        container = ModelContainerFactory.makeContainer()
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
                .tint(Color.accentColor)
        }
        .modelContainer(container)
    }
}

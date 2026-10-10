import Combine
import SwiftData
import SwiftUI

/// Chooses between the first-run setup, the child profile picker and an active
/// child profile, and hosts the parent area as a sheet.
struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ParentSessionState.self) private var parentSession
    @Environment(MediaPlaybackService.self) private var playback
    @Environment(ScreenTimeCoordinator.self) private var screenTime
    @Environment(StoreManager.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ChildProfile.sortOrder) private var profiles: [ChildProfile]

    var body: some View {
        @Bindable var router = router

        Group {
            switch router.screen {
            case .welcome:
                WelcomeView()
            case .profilePicker:
                ProfilePickerView()
            case .child(let profileID):
                if let profile = profiles.first(where: { $0.id == profileID }) {
                    ChildHomeView(profile: profile)
                } else {
                    ProfilePickerView()
                }
            }
        }
        .animation(CalmStyle.screenTransition, value: router.screen)
        .sheet(isPresented: $router.isPresentingParentArea) {
            // Leaving the parent area ends the unlocked session, so coming back
            // always asks for the birth year again.
            parentSession.lock()
            router.pendingParentDestination = nil
        } content: {
            ParentAreaView()
        }
        .task {
            // Tiles whose 14 days in the trash have passed are removed on every
            // launch, together with their statistics and media files.
            TrashService.purgeExpiredTiles(in: modelContext)
            TrashService.purgeAbandonedDrafts(in: modelContext)
            await store.refresh()
            await BackupReminderService.shared.scheduleMonthlyReminderIfAuthorized()
        }
        .onChange(of: profiles.isEmpty, initial: true) { _, isEmpty in
            syncScreen(profilesAreEmpty: isEmpty)
        }
        .onChange(of: scenePhase) { _, newPhase in
            handle(scenePhase: newPhase)
        }
        .onOpenURL { url in
            // A playlist link only ever proposes a tile. Adding it happens in
            // the parent area, behind the gate, so a child tapping a link in
            // Messages cannot change their own tiles.
            guard url.scheme?.lowercased() == PlaylistLink.scheme else { return }
            router.openParentArea(at: .playlistLink(PlaylistLink(url: url)))
        }
        .onReceive(NotificationCenter.default.publisher(for: .burrowOpenExportScreen)) { _ in
            // Tapping the monthly reminder goes straight to the export screen,
            // behind the parental gate as always.
            router.openParentArea(at: .exportImport)
        }
    }

    private func syncScreen(profilesAreEmpty: Bool) {
        if profilesAreEmpty {
            router.showWelcome()
        } else if case .welcome = router.screen {
            router.showProfilePicker()
        }
    }

    private func handle(scenePhase newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            // The parental gate always asks again after a full backgrounding.
            parentSession.lock()
            // A video tile never plays on without the app; a music tile does
            // when the profile allows it.
            if let playlist = playback.playlist {
                if BackgroundPlayback.survivesBackgrounding(
                    category: playlist.category,
                    allowsLockScreenPlayback: playlist.allowsLockScreenPlayback
                ) {
                    playback.continueInBackground()
                } else {
                    playback.stop()
                }
            }
            screenTime.pause()
        case .active:
            // The trial runs down on the wall clock, so it is re-read whenever
            // the app comes forward rather than only at launch.
            store.trial.refresh()
            if case .child = router.screen {
                screenTime.resume()
            }
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}

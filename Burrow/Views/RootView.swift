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
        .sheet(isPresented: ScreenshotMode.isActive ? .constant(false) : $router.isPresentingParentArea) {
            // Leaving the parent area ends the unlocked session, so coming back
            // always asks for the birth year again.
            parentSession.lock()
            router.pendingParentDestination = nil
        } content: {
            ParentAreaView()
        }
        // The screenshots show the parent area full screen: on an iPad a
        // sheet is a small card over the profile picker.
        .fullScreenCover(isPresented: ScreenshotMode.isActive ? $router.isPresentingParentArea : .constant(false)) {
            ParentAreaView()
        }
        .task {
            if let scene = ScreenshotMode.scene {
                // Let the first screen settle, or a presentation can be lost.
                try? await Task.sleep(for: .seconds(1))
                open(scene)
                return
            }
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

    /// Goes straight to one screenshot scene. The parent area is opened
    /// already unlocked: the screenshots show what is behind the gate.
    private func open(_ scene: ScreenshotMode.Scene) {
        switch scene {
        case .profiles:
            router.showProfilePicker()
        case .music, .video, .games, .game:
            screenTime.startSession(limitMinutes: 45)
            router.showChild(profileID: ScreenshotMode.firstChildID)
        case .tiles:
            parentSession.unlock()
            router.openParentArea(at: .tiles)
        case .statistics:
            parentSession.unlock()
            router.openParentArea(at: .statistics)
        case .purchase:
            parentSession.unlock()
            router.openParentArea(at: .purchase)
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
                    // Suspended rather than stopped: the player screen stays up
                    // while the app is away, so stopping left the child staring
                    // at "nothing to play" with no way on but backing out.
                    playback.suspend()
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
            resumeSuspendedPlayback()
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    /// Hands a playlist that was paused for a backgrounding back to the child.
    ///
    /// Music starts itself again where it left off; a video waits to be pressed,
    /// because building its embed again would restart it at 0:00 and nobody asked
    /// for that out loud. Either way the player keeps what it was showing.
    private func resumeSuspendedPlayback() {
        guard let playlist = playback.playlist, playback.isSuspended else { return }

        switch BackgroundPlayback.resumption(
            category: playlist.category,
            hasExhaustedPlaylist: playback.hasExhaustedPlaylist,
            screenTimeHasExpired: screenTime.hasExpired
        ) {
        case .playAgain:
            playback.resume()
        case .waitForChild:
            break
        case .giveUp:
            playback.stop()
        }
    }
}

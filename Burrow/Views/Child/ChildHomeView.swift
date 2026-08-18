import SwiftData
import SwiftUI

/// The child's home screen for one profile: a Music tab and a Video tab, each
/// showing only that profile's tiles of that category.
struct ChildHomeView: View {
    let profile: ChildProfile

    @Environment(AppRouter.self) private var router
    @Environment(ConnectivityMonitor.self) private var connectivity
    @Environment(ScreenTimeCoordinator.self) private var screenTime
    @Environment(MediaPlaybackService.self) private var playback
    @Environment(StoreManager.self) private var store
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Tile.sortOrder) private var allTiles: [Tile]

    @State private var viewModel = ChildHomeViewModel()

    /// Playback outlives the player for a music tile, so both the recorder and
    /// the service's callbacks belong here, where they last as long as the
    /// child's session rather than as long as one full screen cover.
    @State private var recorder = UsageRecorder()

    /// The music still running with the player closed, if any.
    private var backgroundedPlaylist: PlaybackPlaylist? {
        guard viewModel.presentedTile == nil,
              viewModel.presentedGame == nil,
              let playlist = playback.playlist,
              playlist.category == .music else {
            return nil
        }
        return playlist
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        TabView(selection: $viewModel.selectedTab) {
            tileGrid(for: .music)
                .tabItem {
                    Label(
                        String(localized: "Music", comment: "Child tab"),
                        systemImage: "music.note"
                    )
                }
                .tag(ChildTab.music)

            tileGrid(for: .video)
                .tabItem {
                    Label(
                        String(localized: "Video", comment: "Child tab"),
                        systemImage: "film"
                    )
                }
                .tag(ChildTab.video)

            gameGrid
                .tabItem {
                    Label(
                        String(localized: "Games", comment: "Child tab"),
                        systemImage: "gamecontroller"
                    )
                }
                .tag(ChildTab.games)
        }
        .background(profile.theme.wash.ignoresSafeArea())
        .fullScreenCover(item: $viewModel.presentedTile) { tile in
            NowPlayingView(tile: tile, profile: profile)
        }
        .fullScreenCover(item: $viewModel.presentedGame) { game in
            GameHostView(game: game, profile: profile)
        }
        .fullScreenCover(isPresented: Binding(
            get: { screenTime.hasExpired },
            set: { if !$0 { screenTime.acknowledgeExpiry() } }
        )) {
            TimesUpView {
                endSession()
            }
        }
        .onChange(of: screenTime.hasExpired) { _, expired in
            guard expired else { return }
            stopPlayback()
            viewModel.presentedTile = nil
            viewModel.presentedGame = nil
        }
        .onChange(of: viewModel.presentedTile?.id) { _, tileID in
            handlePresentedTileChange(to: tileID)
        }
        // A music tile's YouTube entry is heard, never seen, so its embed lives
        // here rather than in the player: closing the player takes the picture
        // away, and this keeps the sound.
        .background(hiddenYouTubeHost)
    }

    /// The bar for music that plays on with the player closed. It is inset
    /// into each tab's own content rather than the TabView, so it sits just
    /// above the tab bar instead of covering it.
    @ViewBuilder
    private var nowPlayingInset: some View {
        if let playlist = backgroundedPlaylist {
            NowPlayingBar(
                tileTitle: playlist.tileTitle,
                entryTitle: playback.currentEntry?.title,
                tint: profile.theme.tint,
                onOpen: { viewModel.presentedTile = allTiles.first { $0.id == playlist.tileID } },
                onStop: stopPlayback
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var hiddenYouTubeHost: some View {
        if playback.playlist?.category == .music,
           let entry = playback.currentEntry,
           entry.type == .youtube,
           let videoID = entry.youtubeVideoID {
            YouTubeWebView(
                videoID: videoID,
                onFinished: { playback.youTubeDidFinish() },
                onFailed: { playback.youTubeDidFail($0) },
                onStartedPlaying: { playback.youTubeDidStartPlaying() },
                onPaused: { playback.youTubeDidPause() },
                isPlaying: playback.isPlaying
            )
            .id(playback.playToken)
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var gameGrid: some View {
        ZStack(alignment: .top) {
            GameGridView(
                games: viewModel.visibleGames(profile: profile, isPro: store.isPro),
                profile: profile
            ) { game in
                viewModel.presentedGame = game
            }

            floatingControls
        }
        .safeAreaInset(edge: .bottom) { nowPlayingInset }
        .animation(CalmStyle.transition, value: backgroundedPlaylist?.tileID)
    }

    @ViewBuilder
    private func tileGrid(for category: TileCategory) -> some View {
        let tiles = viewModel.visibleTiles(
            from: allTiles,
            profile: profile,
            category: category,
            isOnline: connectivity.isOnline
        )

        ZStack(alignment: .top) {
            TileGridView(tiles: tiles, profile: profile) { tile in
                viewModel.presentedTile = tile
            }

            floatingControls
        }
        .safeAreaInset(edge: .bottom) { nowPlayingInset }
        .animation(CalmStyle.transition, value: backgroundedPlaylist?.tileID)
    }

    /// The small controls that float over every tab's grid.
    private var floatingControls: some View {
        HStack(alignment: .top) {
            Button {
                endSession()
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.calm)
            .accessibilityLabel(Text("Choose another profile", comment: "Back to profile picker"))

            Spacer(minLength: 0)

            if screenTime.progress != nil {
                ScreenTimeIndicator()
            }

            ParentEntryButton()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func endSession() {
        stopPlayback()
        screenTime.stop()
        router.showProfilePicker()
    }

    // MARK: - Playback

    /// Opening a tile starts it; closing one stops only what may not play on.
    private func handlePresentedTileChange(to tileID: UUID?) {
        guard let tileID else {
            if playback.playlist?.category == .video {
                stopPlayback()
            }
            return
        }
        guard let tile = allTiles.first(where: { $0.id == tileID }) else { return }
        startPlayback(for: tile)
    }

    private func startPlayback(for tile: Tile) {
        // Reopening the tile that is already playing shows it where it got to,
        // rather than starting it over.
        guard playback.playlist?.tileID != tile.id else { return }

        recorder.endTile(in: modelContext)
        recorder.beginTile(profileID: profile.id, tileID: tile.id, in: modelContext)

        playback.onEntryChanged = { entryID in
            // Remember where the playlist is, so reopening the tile continues
            // from this entry (always from 0:00).
            tile.lastPlayedItemID = entryID
            recorder.beginEntry(entryID, in: modelContext)
            if let item = tile.orderedMediaItems.first(where: { $0.id == entryID }) {
                item.clearError()
            }
            ModelSaver.save(modelContext, describing: "storing the last played item")
        }

        playback.onEntryFailure = { entryID, message in
            // Stored for the parent view only; the child sees a silent skip.
            guard let item = tile.orderedMediaItems.first(where: { $0.id == entryID }) else { return }
            item.recordError(message)
            ModelSaver.save(modelContext, describing: "storing a media error")
        }

        playback.onEntryCompleted = { _ in
            recorder.finishCurrentEntry(in: modelContext)
        }

        playback.onPlaybackModeChanged = { shuffle, repeatMode in
            // The player's shuffle and repeat buttons are sticky per tile.
            // Repeat-one has no field of its own; it comes back as repeat-all.
            tile.shufflePlaylist = shuffle
            tile.loopPlaylist = repeatMode != .off
            ModelSaver.save(modelContext, describing: "storing playback modes")
        }

        playback.start(PlaybackPlaylist(tile: tile, profile: profile))
    }

    private func stopPlayback() {
        recorder.endTile(in: modelContext)
        playback.onEntryChanged = nil
        playback.onEntryFailure = nil
        playback.onEntryCompleted = nil
        playback.onPlaybackModeChanged = nil
        playback.stop()
    }
}

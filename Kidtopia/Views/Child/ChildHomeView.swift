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

    @Query(sort: \Tile.sortOrder) private var allTiles: [Tile]

    @State private var viewModel = ChildHomeViewModel()

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
        }
        .background(profile.theme.wash.ignoresSafeArea())
        .fullScreenCover(item: $viewModel.presentedTile) { tile in
            NowPlayingView(tile: tile, profile: profile)
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
            playback.stop()
            viewModel.presentedTile = nil
        }
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
    }

    private func endSession() {
        playback.stop()
        screenTime.stop()
        router.showProfilePicker()
    }
}

import AVKit
import SwiftData
import SwiftUI

/// Full screen playback for one tile. Only the current track or video is on
/// screen — the playlist itself is never shown to the child.
struct NowPlayingView: View {
    let tile: Tile
    let profile: ChildProfile

    @Environment(MediaPlaybackService.self) private var playback
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var recorder = UsageRecorder()

    private var scale: AgeLayoutScale { profile.layoutScale }

    /// `true` when the current entry actually shows a picture. Audio entries
    /// keep the normal layout in every orientation.
    private var isShowingVideo: Bool {
        guard let entry = playback.currentEntry else { return false }
        switch entry.type {
        case .localVideo:
            return true
        case .youtube:
            return tile.category.showsYouTubeVideo && entry.youtubeVideoID != nil
        case .localAudio, .appleMusic:
            return false
        }
    }

    /// Landscape with a video playing: the picture takes the whole screen and
    /// the controls sit on top of it instead of beside it.
    private var isImmersive: Bool {
        verticalSizeClass == .compact && isShowingVideo
    }

    var body: some View {
        // Both orientations use the same view tree. Rotating only changes
        // modifier values on it — never which branch of an `if` is taken —
        // because a new branch would give the player a new identity, tearing
        // down the video view and restarting the video from the beginning.
        stage
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, isImmersive ? 0 : 20)
            // Landscape video runs edge to edge, under the floating controls.
            .ignoresSafeArea(edges: isImmersive ? .all : [])
            // In portrait these reserve their own space above and below the
            // stage; in landscape the stage reaches past them, so they float
            // on top of the picture instead.
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .safeAreaInset(edge: .bottom, spacing: 0) { footer }
            .animation(CalmStyle.transition, value: isImmersive)
            .background(profile.theme.wash.ignoresSafeArea())
            .background(Color(.systemBackground).ignoresSafeArea())
            .statusBarHidden()
            .onAppear(perform: startPlayback)
            .onDisappear(perform: stopPlayback)
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, height: 48)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.calm)
            .accessibilityLabel(Text("Close", comment: "Close the player"))

            Spacer(minLength: 0)

            ScreenTimeIndicator()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var stage: some View {
        if playback.hasExhaustedPlaylist {
            emptyStage
        } else if let entry = playback.currentEntry {
            currentEntryStage(entry)
                .transition(.opacity)
                .animation(CalmStyle.transition, value: entry.id)
        } else {
            emptyStage
        }
    }

    @ViewBuilder
    private func currentEntryStage(_ entry: PlaybackEntry) -> some View {
        VStack(spacing: isImmersive ? 0 : 20) {
            Group {
                switch entry.type {
                case .localVideo:
                    VideoPlayer(player: playback.player)
                        .aspectRatio(16 / 9, contentMode: .fit)

                case .youtube:
                    if tile.category.showsYouTubeVideo, let videoID = entry.youtubeVideoID {
                        YouTubeWebView(
                            videoID: videoID,
                            onFinished: { playback.youTubeDidFinish() },
                            onFailed: { playback.youTubeDidFail($0) },
                            onStartedPlaying: { playback.youTubeDidStartPlaying() },
                            onPaused: { playback.youTubeDidPause() },
                            isPlaying: playback.isPlaying
                        )
                        .id(playback.playToken)
                        .aspectRatio(16 / 9, contentMode: .fit)
                    } else {
                        artwork
                            .overlay(alignment: .bottom) {
                                // Audio-only mode: the embed still has to exist
                                // for sound, but it is kept out of sight.
                                if let videoID = entry.youtubeVideoID {
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
                    }

                case .localAudio, .appleMusic:
                    artwork
                }
            }
            .calmCard(cornerRadius: isImmersive ? 0 : 28)

            // In landscape the picture gets the whole screen, so the title and
            // any status line step aside.
            if !isImmersive {
                VStack(spacing: 6) {
                    Text(entry.title.isEmpty ? tile.title : entry.title)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    if let message = playback.childFacingMessage {
                        Text(message)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .contentShape(Rectangle())
        .gesture(swipeGesture)
    }

    private var artwork: some View {
        TileImageView(
            tileID: tile.id,
            imageData: tile.imageData,
            category: tile.category,
            tint: profile.theme.tint
        )
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 420)
    }

    private var emptyStage: some View {
        VStack(spacing: 16) {
            Image(systemName: "zzz")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Nothing to play right now.", comment: "Playback empty state")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if scale.showsTransportButtons {
            HStack(spacing: 36) {
                transportButton(systemImage: "backward.fill", label: String(localized: "Previous", comment: "Transport button")) {
                    playback.previous()
                }

                transportButton(
                    systemImage: playback.isPlaying ? "pause.fill" : "play.fill",
                    label: playback.isPlaying
                        ? String(localized: "Pause", comment: "Transport button")
                        : String(localized: "Play", comment: "Transport button"),
                    diameter: 96
                ) {
                    playback.togglePlayPause()
                }

                transportButton(systemImage: "forward.fill", label: String(localized: "Next", comment: "Transport button")) {
                    playback.next()
                }
            }
            .padding(.bottom, 32)
            .padding(.top, 12)
        } else {
            Color.clear.frame(height: 24)
        }
    }

    private func transportButton(
        systemImage: String,
        label: String,
        diameter: CGFloat = 76,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: diameter * 0.36, weight: .medium))
                .foregroundStyle(profile.theme.tint)
                .frame(width: diameter, height: diameter)
                .background(Color(.secondarySystemBackground), in: Circle())
        }
        .buttonStyle(.calm)
        .accessibilityLabel(Text(label))
    }

    /// Older children navigate the playlist by swiping instead of with buttons.
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                guard !scale.showsTransportButtons else { return }
                if value.translation.width < -40 {
                    playback.next()
                } else if value.translation.width > 40 {
                    playback.previous()
                }
            }
    }

    // MARK: - Lifecycle

    private func startPlayback() {
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

        playback.start(PlaybackPlaylist(tile: tile, profile: profile))
    }

    private func stopPlayback() {
        recorder.endTile(in: modelContext)
        playback.onEntryChanged = nil
        playback.onEntryFailure = nil
        playback.onEntryCompleted = nil
        playback.stop()
    }
}

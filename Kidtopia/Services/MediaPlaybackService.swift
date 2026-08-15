import AVFoundation
import Foundation
import MediaPlayer
import Observation
import OSLog

/// Drives playback for all four media source types.
///
/// Local audio and local video run through a single `AVQueuePlayer`. Apple Music
/// goes through `AppleMusicService`. YouTube is rendered by `YouTubeWebView`,
/// which reports back through `youTubeDidFinish()` and `youTubeDidFail(_:)`.
///
/// The service never touches SwiftData. Callers wire the `onEntryChanged` and
/// `onEntryFailure` closures to persist `lastPlayedItemID` and
/// `lastKnownErrorMessage`.
@Observable
@MainActor
final class MediaPlaybackService {
    private(set) var playlist: PlaybackPlaylist?
    private(set) var currentEntry: PlaybackEntry?
    private(set) var isPlaying = false

    /// A short, friendly line shown to the child when the current entry cannot
    /// play (for example a song that needs an Apple Music subscription).
    private(set) var childFacingMessage: String?

    /// Set when every entry in the playlist failed, so the view can show a calm
    /// "nothing to play" state instead of spinning forever.
    private(set) var hasExhaustedPlaylist = false

    /// Changes every time an entry starts, including when the same entry comes
    /// round again. Views key their YouTube web view on it so a repeat actually
    /// restarts the embed instead of leaving a finished player on screen.
    private(set) var playToken = UUID()

    /// Called with the entry identifier whenever a new entry starts.
    @ObservationIgnored var onEntryChanged: ((UUID) -> Void)?

    /// Called with an entry identifier and a parent-facing error description.
    @ObservationIgnored var onEntryFailure: ((UUID, String) -> Void)?

    /// Called when an entry played to its end, with the elapsed seconds.
    @ObservationIgnored var onEntryCompleted: ((UUID) -> Void)?

    @ObservationIgnored private let queuePlayer = AVQueuePlayer()
    @ObservationIgnored private let logger = Logger(subsystem: "com.pvd.kidtopia", category: "Playback")
    @ObservationIgnored private var playOrder: [UUID] = []
    @ObservationIgnored private var orderIndex = 0
    @ObservationIgnored private var consecutiveFailures = 0
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var failureObserver: NSObjectProtocol?
    @ObservationIgnored private var appleMusicWatchdog: Task<Void, Never>?
    @ObservationIgnored private var remoteCommandsRegistered = false

    /// Exposed so `VideoPlayer` can render local video with the same player.
    var player: AVQueuePlayer { queuePlayer }

    init() {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleAVPlayerItemFinished(notification)
            }
        }

        failureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleAVPlayerItemFailed(notification)
            }
        }
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        if let failureObserver {
            NotificationCenter.default.removeObserver(failureObserver)
        }
        appleMusicWatchdog?.cancel()
    }

    // MARK: - Starting and stopping

    /// Starts a tile's playlist. Any playlist that was already running is
    /// replaced immediately, without a crossfade or transition.
    func start(_ playlist: PlaybackPlaylist) {
        stopAllEngines()

        self.playlist = playlist
        hasExhaustedPlaylist = false
        childFacingMessage = nil
        consecutiveFailures = 0

        playOrder = Self.makePlayOrder(for: playlist)
        orderIndex = Self.startIndex(in: playOrder, preferring: playlist.startEntryID)

        configureAudioSession(active: true)
        configureRemoteCommands(enabled: playlist.allowsLockScreenPlayback)

        guard !playOrder.isEmpty else {
            hasExhaustedPlaylist = true
            return
        }

        playCurrentEntry()
    }

    /// Stops everything and clears the Now Playing information.
    func stop() {
        stopAllEngines()
        playlist = nil
        currentEntry = nil
        isPlaying = false
        childFacingMessage = nil
        hasExhaustedPlaylist = false
        configureRemoteCommands(enabled: false)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        configureAudioSession(active: false)
    }

    // MARK: - Transport

    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    func pause() {
        guard let entry = currentEntry else { return }
        switch entry.type {
        case .localAudio, .localVideo:
            queuePlayer.pause()
        case .appleMusic:
            AppleMusicService.shared.pause()
        case .youtube:
            break // The web view is paused by the view layer.
        }
        isPlaying = false
        updateNowPlayingInfo()
    }

    func resume() {
        guard let entry = currentEntry else { return }
        switch entry.type {
        case .localAudio, .localVideo:
            queuePlayer.play()
        case .appleMusic:
            Task { await AppleMusicService.shared.resume() }
        case .youtube:
            break
        }
        isPlaying = true
        updateNowPlayingInfo()
    }

    func next() {
        advance(by: 1, countAsFailure: false)
    }

    func previous() {
        advance(by: -1, countAsFailure: false)
    }

    // MARK: - YouTube callbacks

    /// The embedded player reached the end of the video.
    func youTubeDidFinish() {
        guard currentEntry?.type == .youtube else { return }
        if let id = currentEntry?.id {
            onEntryCompleted?(id)
        }
        advance(by: 1, countAsFailure: false)
    }

    /// The embedded player could not play the video (removed, private, blocked).
    /// The child sees nothing; the message is stored for the parent view.
    func youTubeDidFail(_ message: String) {
        guard let entry = currentEntry, entry.type == .youtube else { return }
        onEntryFailure?(entry.id, message)
        advance(by: 1, countAsFailure: true)
    }

    func youTubeDidStartPlaying() {
        guard currentEntry?.type == .youtube else { return }
        isPlaying = true
        updateNowPlayingInfo()
    }

    func youTubeDidPause() {
        guard currentEntry?.type == .youtube else { return }
        isPlaying = false
        updateNowPlayingInfo()
    }

    // MARK: - Play order

    private static func makePlayOrder(for playlist: PlaybackPlaylist) -> [UUID] {
        let ids = playlist.entries.map(\.id)
        guard playlist.shuffle else { return ids }
        return ids.shuffled()
    }

    private static func startIndex(in order: [UUID], preferring entryID: UUID?) -> Int {
        guard let entryID, let index = order.firstIndex(of: entryID) else { return 0 }
        return index
    }

    private func entry(withID id: UUID) -> PlaybackEntry? {
        playlist?.entries.first { $0.id == id }
    }

    /// Moves through the play order, honouring `loopPlaylist`.
    private func advance(by offset: Int, countAsFailure: Bool) {
        guard let playlist, !playOrder.isEmpty else { return }

        if countAsFailure {
            consecutiveFailures += 1
            if consecutiveFailures >= playOrder.count {
                stopAllEngines()
                currentEntry = nil
                isPlaying = false
                hasExhaustedPlaylist = true
                return
            }
        } else {
            consecutiveFailures = 0
        }

        let nextIndex = orderIndex + offset

        if nextIndex >= playOrder.count {
            guard playlist.loop else {
                stopAllEngines()
                isPlaying = false
                return
            }
            // A looped shuffle reshuffles, so the second pass is not identical.
            if playlist.shuffle {
                playOrder = Self.makePlayOrder(for: playlist)
            }
            orderIndex = 0
        } else if nextIndex < 0 {
            orderIndex = playlist.loop ? playOrder.count - 1 : 0
        } else {
            orderIndex = nextIndex
        }

        playCurrentEntry()
    }

    // MARK: - Playing one entry

    private func playCurrentEntry() {
        stopEnginesKeepingSession()
        childFacingMessage = nil

        guard playOrder.indices.contains(orderIndex),
              let entry = entry(withID: playOrder[orderIndex]) else {
            hasExhaustedPlaylist = true
            return
        }

        currentEntry = entry
        playToken = UUID()
        onEntryChanged?(entry.id)

        switch entry.type {
        case .localAudio, .localVideo:
            playLocalFile(for: entry)
        case .appleMusic:
            playAppleMusic(for: entry)
        case .youtube:
            // The view observes `currentEntry` and loads the embed itself.
            guard entry.youtubeVideoID?.isEmpty == false else {
                reportFailure(
                    for: entry,
                    message: String(
                        localized: "This YouTube link is incomplete.",
                        comment: "Parent-facing media error"
                    )
                )
                return
            }
            isPlaying = true
            updateNowPlayingInfo()
        }
    }

    private func playLocalFile(for entry: PlaybackEntry) {
        guard let fileName = entry.localFileName, !fileName.isEmpty else {
            reportFailure(
                for: entry,
                message: String(
                    localized: "No file is attached to this item.",
                    comment: "Parent-facing media error"
                )
            )
            return
        }

        let url = MediaLibrary.shared.url(forFileNamed: fileName)
        guard MediaLibrary.shared.fileExists(named: fileName) else {
            reportFailure(for: entry, message: MediaLibraryError.fileMissing(name: fileName).localizedDescription)
            return
        }

        let item = AVPlayerItem(url: url)
        queuePlayer.removeAllItems()
        queuePlayer.insert(item, after: nil)
        // Every item deliberately starts at 0:00; positions are never resumed.
        queuePlayer.seek(to: .zero)
        queuePlayer.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    private func playAppleMusic(for entry: PlaybackEntry) {
        guard let catalogID = entry.appleMusicItemID, !catalogID.isEmpty else {
            reportFailure(
                for: entry,
                message: String(
                    localized: "No Apple Music song is attached to this item.",
                    comment: "Parent-facing media error"
                )
            )
            return
        }

        appleMusicWatchdog?.cancel()
        let entryID = entry.id

        Task { [weak self] in
            guard let self else { return }
            do {
                try await AppleMusicService.shared.play(catalogID: catalogID)
                guard self.currentEntry?.id == entryID else { return }
                self.isPlaying = true
                self.updateNowPlayingInfo()
                self.startAppleMusicWatchdog(for: entryID)
            } catch {
                guard self.currentEntry?.id == entryID else { return }
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                // The rest of the playlist stays playable: show a friendly line
                // for this entry and move on.
                self.childFacingMessage = String(
                    localized: "This song cannot play right now.",
                    comment: "Child-facing message when an Apple Music item fails"
                )
                self.onEntryFailure?(entryID, message)
                self.advance(by: 1, countAsFailure: true)
            }
        }
    }

    /// MusicKit does not post an end-of-song notification, so the player state is
    /// sampled once per second while an Apple Music entry is active.
    private func startAppleMusicWatchdog(for entryID: UUID) {
        appleMusicWatchdog?.cancel()
        appleMusicWatchdog = Task { [weak self] in
            // Give the player a moment to leave the .stopped state it starts in.
            try? await Task.sleep(for: .seconds(2))
            while !Task.isCancelled {
                guard let self else { return }
                guard self.currentEntry?.id == entryID else { return }
                if AppleMusicService.shared.hasFinishedPlaying {
                    self.onEntryCompleted?(entryID)
                    self.advance(by: 1, countAsFailure: false)
                    return
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func reportFailure(for entry: PlaybackEntry, message: String) {
        onEntryFailure?(entry.id, message)
        advance(by: 1, countAsFailure: true)
    }

    // MARK: - AVPlayer notifications

    private func handleAVPlayerItemFinished(_ notification: Notification) {
        guard let entry = currentEntry,
              entry.type == .localAudio || entry.type == .localVideo,
              let finishedItem = notification.object as? AVPlayerItem,
              finishedItem === queuePlayer.currentItem else {
            return
        }
        onEntryCompleted?(entry.id)
        advance(by: 1, countAsFailure: false)
    }

    private func handleAVPlayerItemFailed(_ notification: Notification) {
        guard let entry = currentEntry,
              entry.type == .localAudio || entry.type == .localVideo else {
            return
        }
        let underlying = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
        let message = underlying?.localizedDescription ?? String(
            localized: "This file could not be played.",
            comment: "Parent-facing media error"
        )
        reportFailure(for: entry, message: message)
    }

    // MARK: - Engines

    private func stopEnginesKeepingSession() {
        queuePlayer.pause()
        queuePlayer.removeAllItems()
        appleMusicWatchdog?.cancel()
        appleMusicWatchdog = nil
        AppleMusicService.shared.stop()
        isPlaying = false
    }

    private func stopAllEngines() {
        stopEnginesKeepingSession()
        playOrder = []
        orderIndex = 0
    }

    // MARK: - Audio session, lock screen and remote commands

    private func configureAudioSession(active: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            if active {
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true)
            } else {
                try session.setActive(false, options: .notifyOthersOnDeactivation)
            }
        } catch {
            logger.error("Audio session error: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func configureRemoteCommands(enabled: Bool) {
        let center = MPRemoteCommandCenter.shared()

        guard enabled else {
            if remoteCommandsRegistered {
                center.playCommand.removeTarget(nil)
                center.pauseCommand.removeTarget(nil)
                center.togglePlayPauseCommand.removeTarget(nil)
                center.nextTrackCommand.removeTarget(nil)
                center.previousTrackCommand.removeTarget(nil)
                center.playCommand.isEnabled = false
                center.pauseCommand.isEnabled = false
                center.togglePlayPauseCommand.isEnabled = false
                center.nextTrackCommand.isEnabled = false
                center.previousTrackCommand.isEnabled = false
                remoteCommandsRegistered = false
            }
            return
        }

        guard !remoteCommandsRegistered else { return }
        remoteCommandsRegistered = true

        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.togglePlayPause() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.previous() }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let playlist, playlist.allowsLockScreenPlayback, let entry = currentEntry else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: entry.title,
            MPMediaItemPropertyAlbumTitle: playlist.tileTitle,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        if entry.type == .localAudio || entry.type == .localVideo,
           let item = queuePlayer.currentItem {
            let duration = item.duration
            if duration.isNumeric {
                info[MPMediaItemPropertyPlaybackDuration] = CMTimeGetSeconds(duration)
            }
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTimeGetSeconds(queuePlayer.currentTime())
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

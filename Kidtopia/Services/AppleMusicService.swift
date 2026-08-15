import Foundation
import MusicKit
import OSLog

/// Thin wrapper around MusicKit for the `.appleMusic` media source.
///
/// Apple Music playback needs both the user's permission and an active
/// subscription. When either is missing, the entry reports a friendly message
/// and the rest of the playlist keeps playing.
@MainActor
final class AppleMusicService {
    enum AppleMusicError: LocalizedError {
        case notAuthorized
        case noSubscription
        case songNotFound
        case playbackFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return String(
                    localized: "Kidtopia does not have permission to use Apple Music yet.",
                    comment: "Apple Music authorization missing"
                )
            case .noSubscription:
                return String(
                    localized: "This song needs an Apple Music subscription.",
                    comment: "Apple Music subscription missing"
                )
            case .songNotFound:
                return String(
                    localized: "This song is not available in Apple Music.",
                    comment: "Apple Music catalog lookup failed"
                )
            case .playbackFailed(let message):
                return message
            }
        }
    }

    static let shared = AppleMusicService()

    private let logger = Logger(subsystem: "com.pvd.kidtopia", category: "AppleMusic")
    private var player: ApplicationMusicPlayer { ApplicationMusicPlayer.shared }

    private init() {}

    var isAuthorized: Bool {
        MusicAuthorization.currentStatus == .authorized
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        if isAuthorized { return true }
        let status = await MusicAuthorization.request()
        return status == .authorized
    }

    func hasActiveSubscription() async -> Bool {
        do {
            let subscription = try await MusicSubscription.current
            return subscription.canPlayCatalogContent
        } catch {
            logger.error("Subscription check failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Looks up the catalog song and starts it from the beginning.
    func play(catalogID: String) async throws {
        guard await requestAuthorization() else {
            throw AppleMusicError.notAuthorized
        }
        guard await hasActiveSubscription() else {
            throw AppleMusicError.noSubscription
        }

        let song: Song
        do {
            var request = MusicCatalogResourceRequest<Song>(
                matching: \.id,
                equalTo: MusicItemID(catalogID)
            )
            request.limit = 1
            let response = try await request.response()
            guard let first = response.items.first else {
                throw AppleMusicError.songNotFound
            }
            song = first
        } catch let error as AppleMusicError {
            throw error
        } catch {
            logger.error("Catalog lookup failed: \(error.localizedDescription, privacy: .public)")
            throw AppleMusicError.songNotFound
        }

        do {
            player.queue = ApplicationMusicPlayer.Queue(for: [song])
            player.state.repeatMode = MusicPlayer.RepeatMode.none
            try await player.play()
        } catch {
            logger.error("Playback failed: \(error.localizedDescription, privacy: .public)")
            throw AppleMusicError.playbackFailed(error.localizedDescription)
        }
    }

    func pause() {
        guard player.state.playbackStatus == .playing else { return }
        player.pause()
    }

    func resume() async {
        do {
            try await player.play()
        } catch {
            logger.error("Resume failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func stop() {
        player.stop()
    }

    /// `true` once the queued song has run to its end.
    var hasFinishedPlaying: Bool {
        switch player.state.playbackStatus {
        case .stopped:
            return true
        default:
            return false
        }
    }

    var isPlaying: Bool {
        player.state.playbackStatus == .playing
    }

    // MARK: - Catalog search

    /// A single search hit, flattened so the picker view does not need MusicKit.
    struct SongSearchResult: Identifiable, Hashable, Sendable {
        let id: String
        let title: String
        let artistName: String
    }

    /// Searches the Apple Music catalogue so the parent can add a song to a
    /// music tile.
    func searchSongs(term: String, limit: Int = 25) async throws -> [SongSearchResult] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        guard await requestAuthorization() else {
            throw AppleMusicError.notAuthorized
        }

        var request = MusicCatalogSearchRequest(term: trimmed, types: [Song.self])
        request.limit = limit

        do {
            let response = try await request.response()
            return response.songs.map { song in
                SongSearchResult(
                    id: song.id.rawValue,
                    title: song.title,
                    artistName: song.artistName
                )
            }
        } catch {
            logger.error("Search failed: \(error.localizedDescription, privacy: .public)")
            throw AppleMusicError.playbackFailed(error.localizedDescription)
        }
    }
}

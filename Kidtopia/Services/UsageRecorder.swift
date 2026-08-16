import Foundation
import SwiftData

/// Writes `UsageSession` rows while a child is playing something.
///
/// Two kinds of rows are stored, which keeps the statistics unambiguous:
///
/// - **Open markers** — `mediaItemID == nil`, `durationSeconds == 0`. One row per
///   time a tile is opened. These drive the "number of times opened" figures.
/// - **Play rows** — `mediaItemID != nil` with the seconds that entry actually
///   played. These drive every duration figure and the per-item play counts.
///
/// Because the two kinds never overlap, totals can be summed without any risk of
/// counting the same second twice.
@MainActor
final class UsageRecorder {
    private var profileID: UUID?
    private var tileID: UUID?
    private var gameIdentifier: String?
    private var currentEntryID: UUID?
    private var currentEntryStart: Date?

    /// Records that a tile was opened and starts tracking entries.
    func beginTile(profileID: UUID, tileID: UUID, in context: ModelContext, now: Date = Date()) {
        finishCurrentEntry(in: context, now: now)
        self.profileID = profileID
        self.tileID = tileID

        let marker = UsageSession(
            profileID: profileID,
            tileID: tileID,
            mediaItemID: nil,
            startTime: now,
            durationSeconds: 0
        )
        context.insert(marker)
        ModelSaver.save(context, describing: "recording a tile opening")
    }

    /// Starts timing a new entry, closing the previous one.
    func beginEntry(_ entryID: UUID, in context: ModelContext, now: Date = Date()) {
        finishCurrentEntry(in: context, now: now)
        currentEntryID = entryID
        currentEntryStart = now
    }

    /// Closes the open entry, if any, and writes its play row.
    func finishCurrentEntry(in context: ModelContext, now: Date = Date()) {
        guard let profileID,
              let tileID,
              let entryID = currentEntryID,
              let start = currentEntryStart else {
            currentEntryID = nil
            currentEntryStart = nil
            return
        }

        currentEntryID = nil
        currentEntryStart = nil

        let seconds = Int(now.timeIntervalSince(start).rounded())
        // Ignore taps that lasted less than a second, so an accidental tap does
        // not show up as a play.
        guard seconds >= 1 else { return }

        let session = UsageSession(
            profileID: profileID,
            tileID: tileID,
            mediaItemID: entryID,
            gameIdentifier: gameIdentifier,
            startTime: start,
            durationSeconds: seconds
        )
        context.insert(session)
        ModelSaver.save(context, describing: "recording playback time")
    }

    /// Ends the whole visit to a tile.
    func endTile(in context: ModelContext, now: Date = Date()) {
        finishCurrentEntry(in: context, now: now)
        profileID = nil
        tileID = nil
        gameIdentifier = nil
    }

    /// Records that a game was opened and starts timing it.
    ///
    /// A game has no playlist, so the visit is both the opening and the single
    /// entry: the game's stable UUID stands in for the tile *and* for the
    /// media item. That is what lets `StatisticsService` sum game time without
    /// knowing games exist — a play row is recognised by a non-nil
    /// `mediaItemID`, and a game row has one.
    func beginGame(
        profileID: UUID,
        game: GameCatalog.Game,
        in context: ModelContext,
        now: Date = Date()
    ) {
        finishCurrentEntry(in: context, now: now)
        self.profileID = profileID
        self.tileID = game.id
        self.gameIdentifier = game.identifier

        let marker = UsageSession(
            profileID: profileID,
            tileID: game.id,
            mediaItemID: nil,
            gameIdentifier: game.identifier,
            startTime: now,
            durationSeconds: 0
        )
        context.insert(marker)
        ModelSaver.save(context, describing: "recording a game opening")

        currentEntryID = game.id
        currentEntryStart = now
    }

    /// Ends the whole visit to a game.
    func endGame(in context: ModelContext, now: Date = Date()) {
        endTile(in: context, now: now)
    }
}

import Foundation
import SwiftData
import Testing
@testable import Kidtopia

@MainActor
@Suite("Game usage recording")
struct GameUsageTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: ChildProfile.self, Tile.self, MediaItem.self, UsageSession.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func sessions(in context: ModelContext) throws -> [UsageSession] {
        try context.fetch(FetchDescriptor<UsageSession>())
    }

    @Test("Opening a game writes an opening marker against the game's UUID")
    func opensWithMarker() throws {
        let context = try makeContext()
        let recorder = UsageRecorder()
        let game = GameCatalog.all[0]
        let profileID = UUID()
        let start = Date(timeIntervalSince1970: 1_000)

        recorder.beginGame(profileID: profileID, game: game, in: context, now: start)

        let rows = try sessions(in: context)
        #expect(rows.count == 1)
        #expect(rows[0].tileID == game.id)
        #expect(rows[0].mediaItemID == nil)
        #expect(rows[0].gameIdentifier == game.identifier)
        #expect(rows[0].durationSeconds == 0)
    }

    @Test("Ending a game writes a play row carrying the seconds")
    func writesPlayRow() throws {
        let context = try makeContext()
        let recorder = UsageRecorder()
        let game = GameCatalog.all[0]
        let start = Date(timeIntervalSince1970: 1_000)

        recorder.beginGame(profileID: UUID(), game: game, in: context, now: start)
        recorder.endGame(in: context, now: start.addingTimeInterval(30))

        let play = try sessions(in: context).filter { $0.mediaItemID != nil }
        #expect(play.count == 1)
        #expect(play[0].durationSeconds == 30)
        // The play row must carry a non-nil mediaItemID or StatisticsService
        // counts it as an opening worth zero seconds.
        #expect(play[0].mediaItemID == game.id)
        #expect(play[0].gameIdentifier == game.identifier)
    }

    @Test("A visit shorter than a second is not recorded as play")
    func ignoresAccidentalTaps() throws {
        let context = try makeContext()
        let recorder = UsageRecorder()
        let start = Date(timeIntervalSince1970: 1_000)

        recorder.beginGame(profileID: UUID(), game: GameCatalog.all[0], in: context, now: start)
        recorder.endGame(in: context, now: start.addingTimeInterval(0.2))

        #expect(try sessions(in: context).filter { $0.mediaItemID != nil }.isEmpty)
    }

    @Test("Game seconds land in the duration totals, not the opening counts")
    func statisticsCountGameTime() throws {
        let context = try makeContext()
        let recorder = UsageRecorder()
        let game = GameCatalog.all[0]
        let start = Date(timeIntervalSince1970: 1_000)

        recorder.beginGame(profileID: UUID(), game: game, in: context, now: start)
        recorder.endGame(in: context, now: start.addingTimeInterval(45))

        let totals = StatisticsService.totals(try sessions(in: context))
        #expect(totals.totalSeconds == 45)
        #expect(totals.openCount == 1)
    }

    @Test("Games and media both appear in the per-tile breakdown without double counting")
    func mixedRowsDoNotDoubleCount() throws {
        let context = try makeContext()
        let recorder = UsageRecorder()
        let game = GameCatalog.all[0]
        let tileID = UUID()
        let itemID = UUID()
        let profileID = UUID()
        let start = Date(timeIntervalSince1970: 1_000)

        recorder.beginTile(profileID: profileID, tileID: tileID, in: context, now: start)
        recorder.beginEntry(itemID, in: context, now: start)
        recorder.endTile(in: context, now: start.addingTimeInterval(10))

        recorder.beginGame(profileID: profileID, game: game, in: context, now: start)
        recorder.endGame(in: context, now: start.addingTimeInterval(20))

        let rows = try sessions(in: context)
        let perTile = StatisticsService.totalsPerTile(rows)
        #expect(perTile.count == 2)
        #expect(StatisticsService.totals(rows).totalSeconds == 30)

        let gameTotals = perTile.first { $0.tileID == game.id }?.totals
        #expect(gameTotals?.totalSeconds == 20)
    }

    @Test("Media rows carry no game identifier")
    func mediaRowsHaveNoGameIdentifier() throws {
        let context = try makeContext()
        let recorder = UsageRecorder()
        let start = Date(timeIntervalSince1970: 1_000)

        recorder.beginTile(profileID: UUID(), tileID: UUID(), in: context, now: start)
        recorder.beginEntry(UUID(), in: context, now: start)
        recorder.endTile(in: context, now: start.addingTimeInterval(5))

        #expect(try sessions(in: context).allSatisfy { $0.gameIdentifier == nil })
    }
}

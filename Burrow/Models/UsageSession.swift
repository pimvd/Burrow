import Foundation
import SwiftData

/// One recorded stretch of listening or watching. A session is written when the
/// child leaves a playback view (or the app resigns the foreground) so the
/// statistics screens can aggregate plain totals.
@Model
final class UsageSession {
    var id: UUID = UUID()
    var profileID: UUID = UUID()
    var tileID: UUID = UUID()
    var mediaItemID: UUID?

    /// Set on rows written by a game, `nil` on every media row. The row's
    /// `tileID` is then the game's stable catalog UUID.
    var gameIdentifier: String?

    var startTime: Date = Date()
    var durationSeconds: Int = 0

    init(
        id: UUID = UUID(),
        profileID: UUID,
        tileID: UUID,
        mediaItemID: UUID? = nil,
        gameIdentifier: String? = nil,
        startTime: Date = Date(),
        durationSeconds: Int = 0
    ) {
        self.id = id
        self.profileID = profileID
        self.tileID = tileID
        self.mediaItemID = mediaItemID
        self.gameIdentifier = gameIdentifier
        self.startTime = startTime
        self.durationSeconds = durationSeconds
    }
}

extension UsageSession {
    var endTime: Date {
        startTime.addingTimeInterval(TimeInterval(durationSeconds))
    }
}

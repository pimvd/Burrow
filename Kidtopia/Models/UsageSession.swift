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
    var startTime: Date = Date()
    var durationSeconds: Int = 0

    init(
        id: UUID = UUID(),
        profileID: UUID,
        tileID: UUID,
        mediaItemID: UUID? = nil,
        startTime: Date = Date(),
        durationSeconds: Int = 0
    ) {
        self.id = id
        self.profileID = profileID
        self.tileID = tileID
        self.mediaItemID = mediaItemID
        self.startTime = startTime
        self.durationSeconds = durationSeconds
    }
}

extension UsageSession {
    var endTime: Date {
        startTime.addingTimeInterval(TimeInterval(durationSeconds))
    }
}

import Foundation
import Testing
@testable import Burrow

@Suite("Edit conflict guard")
struct EditConflictGuardTests {
    @Test("An untouched record is not a conflict")
    func unchanged() {
        let opened = Date()
        let guardian = EditConflictGuard(expectedLastModified: opened)
        #expect(!guardian.hasConflict(currentLastModified: opened))
    }

    @Test("A change made elsewhere is a conflict")
    func remoteChange() {
        let opened = Date()
        let guardian = EditConflictGuard(expectedLastModified: opened)
        #expect(guardian.hasConflict(currentLastModified: opened.addingTimeInterval(5)))
    }

    @Test("Sub-millisecond drift from CloudKit is not a conflict")
    func roundTripTolerance() {
        let opened = Date()
        let guardian = EditConflictGuard(expectedLastModified: opened)
        #expect(!guardian.hasConflict(currentLastModified: opened.addingTimeInterval(0.0005)))
    }

    /// The tile editor writes playlist changes straight through, so the stamp it
    /// guards moves while the editor is still open. Without this the parent is
    /// told their own edit arrived from another device.
    @Test("A write the editor made itself is not a conflict")
    func localWriteIsNotAConflict() {
        let opened = Date()
        var guardian = EditConflictGuard(expectedLastModified: opened)

        let afterAppending = opened.addingTimeInterval(3)
        guardian.recordLocalWrite(at: afterAppending)

        #expect(!guardian.hasConflict(currentLastModified: afterAppending))
    }

    @Test("A change made elsewhere after a local write is still a conflict")
    func remoteChangeAfterLocalWrite() {
        let opened = Date()
        var guardian = EditConflictGuard(expectedLastModified: opened)

        let afterAppending = opened.addingTimeInterval(3)
        guardian.recordLocalWrite(at: afterAppending)

        #expect(guardian.hasConflict(currentLastModified: afterAppending.addingTimeInterval(2)))
    }
}

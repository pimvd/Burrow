import Testing
@testable import Burrow

@Suite("Touch lock rules")
struct TouchLockTests {
    @Test("A new lock is open and shows nothing")
    func startsOpen() {
        let lock = TouchLock()
        #expect(!lock.isLocked)
        #expect(!lock.showsUnlock)
        #expect(lock.revealCount == 0)
    }

    @Test("Locking shows the way out, so the parent is told how to undo it")
    func lockingRevealsTheWayOut() {
        var lock = TouchLock()
        lock.lock()
        #expect(lock.isLocked)
        #expect(lock.showsUnlock)
        #expect(lock.revealCount == 1)
    }

    @Test("A touch on a locked screen only brings the way out back")
    func touchingRevealsTheWayOut() {
        var lock = TouchLock()
        lock.lock()
        lock.hideUnlock()

        lock.touched()
        #expect(lock.isLocked)
        #expect(lock.showsUnlock)
    }

    @Test("Every touch restarts the countdown, even while the way out shows")
    func everyTouchCounts() {
        var lock = TouchLock()
        lock.lock()

        lock.touched()
        lock.touched()
        #expect(lock.revealCount == 3)
    }

    @Test("No amount of touching opens the lock")
    func touchingNeverUnlocks() {
        var lock = TouchLock()
        lock.lock()

        for _ in 0 ..< 50 {
            lock.touched()
            lock.hideUnlock()
        }
        #expect(lock.isLocked)
    }

    @Test("The way out fading again leaves the lock closed")
    func hidingKeepsTheLock() {
        var lock = TouchLock()
        lock.lock()

        lock.hideUnlock()
        #expect(lock.isLocked)
        #expect(!lock.showsUnlock)
    }

    @Test("Unlocking clears the lock and the way out together")
    func unlockingClearsEverything() {
        var lock = TouchLock()
        lock.lock()

        lock.unlock()
        #expect(!lock.isLocked)
        #expect(!lock.showsUnlock)
    }

    @Test("Touches on an open lock do nothing at all")
    func touchesOnAnOpenLockDoNothing() {
        var lock = TouchLock()
        lock.touched()
        #expect(!lock.isLocked)
        #expect(!lock.showsUnlock)
        #expect(lock.revealCount == 0)
    }

    @Test("The way out outlives the hold it takes to use it")
    func theWayOutStaysLongEnoughToUse() {
        // Otherwise a hold begun as the button appears would be spoilt by the
        // button fading out from under the finger.
        #expect(TouchLock.unlockHold < TouchLock.unlockLinger)
    }

    @Test("The hold is longer than anything accidental and shorter than patience")
    func theHoldIsDeliberate() {
        #expect(TouchLock.unlockHold >= 2)
        #expect(TouchLock.unlockHold <= 5)
    }
}

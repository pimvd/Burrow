import Foundation
import Observation

/// A self-contained session timer. Deliberately not built on FamilyControls or
/// Apple's Screen Time APIs: it only limits how long one uninterrupted session
/// inside Burrow lasts, and resets when the child returns to the profile
/// picker.
@Observable
@MainActor
final class ScreenTimeCoordinator {
    private(set) var limitSeconds: Int?
    private(set) var elapsedSeconds = 0
    private(set) var hasExpired = false
    private(set) var isRunning = false

    @ObservationIgnored private var tickTask: Task<Void, Never>?

    /// `nil` when the profile has no limit configured.
    var progress: Double? {
        guard let limitSeconds, limitSeconds > 0 else { return nil }
        return min(1, Double(elapsedSeconds) / Double(limitSeconds))
    }

    var remainingSeconds: Int? {
        guard let limitSeconds else { return nil }
        return max(0, limitSeconds - elapsedSeconds)
    }

    /// Starts a fresh session for a profile. Pass `nil` for no limit; the timer
    /// still runs so the child screen can show elapsed time, but never expires.
    func startSession(limitMinutes: Int?) {
        stop()
        limitSeconds = limitMinutes.map { max(0, $0) * 60 }
        elapsedSeconds = 0
        hasExpired = false
        resume()
    }

    func resume() {
        guard !hasExpired, !isRunning else { return }
        isRunning = true
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.isRunning else { return }
                self.tick()
            }
        }
    }

    func pause() {
        isRunning = false
        tickTask?.cancel()
        tickTask = nil
    }

    /// Ends the session entirely, for example when returning to the picker.
    func stop() {
        pause()
        elapsedSeconds = 0
        hasExpired = false
        limitSeconds = nil
    }

    /// Clears the expired state after the "time's up" screen was dismissed.
    func acknowledgeExpiry() {
        hasExpired = false
    }

    private func tick() {
        elapsedSeconds += 1
        guard let limitSeconds, limitSeconds > 0, elapsedSeconds >= limitSeconds else { return }
        hasExpired = true
        pause()
    }
}

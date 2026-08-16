import Foundation
import Observation

/// Which top-level surface the app is showing.
enum AppScreen: Equatable {
    /// No profiles exist yet: the parent has to create the first one.
    case welcome
    /// The child-facing profile picker.
    case profilePicker
    /// A child profile is active.
    case child(profileID: UUID)
}

/// Deep links that the parent settings hierarchy can be opened at.
enum ParentDestination: Hashable {
    case profiles
    case tiles
    case games
    case statistics
    case tileStatistics(tileID: UUID)
    case trash
    case exportImport
    case purchase
}

/// Owns the app's navigation state. Views observe it instead of passing bindings
/// through several layers.
@Observable
@MainActor
final class AppRouter {
    var screen: AppScreen = .profilePicker

    /// Set when the parent area should be presented, optionally at a deep link.
    var pendingParentDestination: ParentDestination?
    var isPresentingParentArea = false

    func showChild(profileID: UUID) {
        screen = .child(profileID: profileID)
    }

    func showProfilePicker() {
        screen = .profilePicker
    }

    func showWelcome() {
        screen = .welcome
    }

    func openParentArea(at destination: ParentDestination? = nil) {
        pendingParentDestination = destination
        isPresentingParentArea = true
    }

    func closeParentArea() {
        isPresentingParentArea = false
        pendingParentDestination = nil
    }
}

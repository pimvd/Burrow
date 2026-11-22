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
    /// A playlist link was opened. `nil` when the link could not be read, so
    /// the parent is told rather than left wondering why nothing happened.
    case playlistLink(PlaylistLink?)
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

    /// Set while the parent area closes only to open again, at this
    /// destination (which may itself be `nil`: the settings root).
    private var reopenDestination: ParentDestination??

    func openParentArea(at destination: ParentDestination? = nil) {
        guard !isPresentingParentArea else {
            // Already open, maybe deep inside a sheet of its own, and locked
            // again if the app went to the background in between (as it does
            // when a link is tapped in Safari). Pushing onto that left the
            // parent on whatever was showing; close it and come back fresh.
            reopenDestination = destination
            isPresentingParentArea = false
            return
        }
        pendingParentDestination = destination
        isPresentingParentArea = true
    }

    func closeParentArea() {
        isPresentingParentArea = false
        pendingParentDestination = nil
        reopenDestination = nil
    }

    /// Called once the parent area is fully gone.
    func parentAreaDidClose() {
        pendingParentDestination = nil
        if case .some(let destination) = reopenDestination {
            reopenDestination = nil
            openParentArea(at: destination)
        }
    }
}

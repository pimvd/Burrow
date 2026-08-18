import Foundation
import SwiftData
import SwiftUI

/// How the parent wants to resolve a detected edit conflict.
enum ConflictResolution {
    case keepMine
    case keepServer
    case cancel
}

/// Detects the case where iCloud merged a newer version of a record while the
/// parent had an editor open.
///
/// SwiftData with CloudKit merges silently by default. Burrow keeps a
/// `lastModified` stamp on every model and compares it against the last value
/// this editor knows about. If it moved on its own, another device changed the
/// same record and the parent gets to choose instead of losing an edit without
/// noticing.
///
/// The baseline is the last *known* stamp, not the stamp at opening, because an
/// editor may write to the record it guards before the parent saves. Those
/// writes have to be recorded, or the editor reports the parent's own change as
/// someone else's.
struct EditConflictGuard {
    private var expectedLastModified: Date

    init(expectedLastModified: Date) {
        self.expectedLastModified = expectedLastModified
    }

    /// Moves the baseline to a write the editor just made itself, so only
    /// changes from elsewhere are left to report.
    mutating func recordLocalWrite(at date: Date) {
        expectedLastModified = date
    }

    /// `true` when the stored record changed other than through this editor.
    func hasConflict(currentLastModified: Date) -> Bool {
        // Dates round-trip through CloudKit with sub-millisecond noise, so a
        // small tolerance avoids false positives.
        abs(currentLastModified.timeIntervalSince(expectedLastModified)) > 0.001
    }
}

/// Presents the keep mine / keep server / cancel choice.
struct ConflictResolutionDialog: ViewModifier {
    @Binding var isPresented: Bool
    let recordName: String
    let onResolve: (ConflictResolution) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            Text("This was changed on another device", comment: "Conflict dialog title"),
            isPresented: $isPresented,
            titleVisibility: .visible
        ) {
            Button {
                onResolve(.keepMine)
            } label: {
                Text("Keep my changes", comment: "Conflict resolution option")
            }

            Button {
                onResolve(.keepServer)
            } label: {
                Text("Keep the other version", comment: "Conflict resolution option")
            }

            Button(role: .cancel) {
                onResolve(.cancel)
            } label: {
                Text("Cancel", comment: "Conflict resolution option")
            }
        } message: {
            Text(
                "\(recordName) was also changed somewhere else while you were editing. Which version should Burrow keep?",
                comment: "Conflict dialog explanation"
            )
        }
    }
}

extension View {
    func conflictResolutionDialog(
        isPresented: Binding<Bool>,
        recordName: String,
        onResolve: @escaping (ConflictResolution) -> Void
    ) -> some View {
        modifier(
            ConflictResolutionDialog(
                isPresented: isPresented,
                recordName: recordName,
                onResolve: onResolve
            )
        )
    }
}

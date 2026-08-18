import Foundation
import OSLog
import SwiftData

/// Small helper around `ModelContext.save()` so no call site swallows an error
/// silently.
enum ModelSaver {
    private static let logger = Logger(subsystem: "com.pvd.burrow", category: "Persistence")

    /// Saves and logs failures. Returns the error so a view can surface it.
    @discardableResult
    static func save(_ context: ModelContext, describing action: String) -> Error? {
        guard context.hasChanges else { return nil }
        do {
            try context.save()
            return nil
        } catch {
            logger.error("Saving failed while \(action, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return error
        }
    }
}

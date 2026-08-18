import Foundation
import OSLog
import SwiftData

/// Builds the app's `ModelContainer`.
///
/// The primary configuration mirrors the store to the parent's private CloudKit
/// database so their own devices stay in sync. Nothing is shared between
/// different iCloud accounts. When CloudKit is unavailable (no iCloud account,
/// missing entitlement, simulator without a signed-in account) the app falls
/// back to a local-only store rather than refusing to launch.
enum ModelContainerFactory {
    private static let logger = Logger(subsystem: "com.pvd.burrow", category: "Persistence")

    /// Whether the store that was actually opened mirrors to CloudKit. The
    /// fallback below is silent by design, so this is the only way a screen can
    /// tell the parent that their content is staying on this device.
    private(set) static var isCloudBacked = false

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(versionedSchema: BurrowSchemaV1.self)

        if inMemory {
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            return makeContainer(
                schema: schema,
                configuration: configuration,
                cloudBacked: false,
                allowFallback: false
            )
        }

        let cloudConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        return makeContainer(
            schema: schema,
            configuration: cloudConfiguration,
            cloudBacked: true,
            allowFallback: true
        )
    }

    private static func makeContainer(
        schema: Schema,
        configuration: ModelConfiguration,
        cloudBacked: Bool,
        allowFallback: Bool
    ) -> ModelContainer {
        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: BurrowMigrationPlan.self,
                configurations: [configuration]
            )
            isCloudBacked = cloudBacked
            return container
        } catch {
            logger.error("Could not open the synced store: \(error.localizedDescription, privacy: .public)")

            isCloudBacked = false

            if allowFallback {
                do {
                    let localConfiguration = ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: false,
                        cloudKitDatabase: .none
                    )
                    return try ModelContainer(
                        for: schema,
                        migrationPlan: BurrowMigrationPlan.self,
                        configurations: [localConfiguration]
                    )
                } catch {
                    logger.error("Could not open the local store either: \(error.localizedDescription, privacy: .public)")
                }
            }

            // A container is required for the app to function at all. An
            // in-memory store keeps the app usable for the current launch and
            // is the last resort before crashing.
            do {
                let memoryConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
                return try ModelContainer(for: schema, configurations: [memoryConfiguration])
            } catch {
                fatalError("Burrow could not create any model container: \(error)")
            }
        }
    }
}

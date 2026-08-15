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
    private static let logger = Logger(subsystem: "com.pvd.kidtopia", category: "Persistence")

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(versionedSchema: KidtopiaSchemaV1.self)

        if inMemory {
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            return makeContainer(schema: schema, configuration: configuration, allowFallback: false)
        }

        let cloudConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        return makeContainer(schema: schema, configuration: cloudConfiguration, allowFallback: true)
    }

    private static func makeContainer(
        schema: Schema,
        configuration: ModelConfiguration,
        allowFallback: Bool
    ) -> ModelContainer {
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: KidtopiaMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            logger.error("Could not open the synced store: \(error.localizedDescription, privacy: .public)")

            if allowFallback {
                do {
                    let localConfiguration = ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: false,
                        cloudKitDatabase: .none
                    )
                    return try ModelContainer(
                        for: schema,
                        migrationPlan: KidtopiaMigrationPlan.self,
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
                fatalError("Kidtopia could not create any model container: \(error)")
            }
        }
    }
}

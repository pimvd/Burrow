import Foundation
import SwiftData

/// Version 1 of the persistent schema.
///
/// Future releases add a new `VersionedSchema` here plus a `MigrationStage` in
/// `KidtopiaMigrationPlan`. Lightweight migrations run silently at container
/// creation; nothing is surfaced to the parent unless a migration fails.
enum KidtopiaSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 1, 0) }

    static var models: [any PersistentModel.Type] {
        [ChildProfile.self, Tile.self, MediaItem.self, UsageSession.self]
    }
}

/// The ordered list of schema versions the store can be migrated through.
enum KidtopiaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [KidtopiaSchemaV1.self]
    }

    /// Empty for now: there is only one schema version. Lightweight stages get
    /// appended here as the model evolves.
    ///
    /// A second version cannot simply re-list the same model types — SwiftData
    /// checksums them and rejects duplicates. Each version needs its own copies
    /// of the model classes, so the ceremony is only worth it once the app has
    /// shipped and there are real stores to migrate.
    static var stages: [MigrationStage] { [] }
}

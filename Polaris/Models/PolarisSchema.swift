//
//  PolarisSchema.swift
//  Polaris
//

import SwiftData

enum PolarisSchema: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Project.self,
            Todo.self,
            Tag.self,
            ChecklistItem.self
        ]
    }
}

enum PolarisMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PolarisSchema.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

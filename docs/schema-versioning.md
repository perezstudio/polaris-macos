# Schema Versioning

Polaris uses SwiftData's `VersionedSchema` and `SchemaMigrationPlan` to manage database migrations.

## Current Version

**V1 (1.0.0)** — `PolarisSchema`

Defined in `Polaris/Models/PolarisSchema.swift`. Includes all four models:
- `Project`
- `Todo`
- `Tag`
- `ChecklistItem`

## How It Works

The `ModelContainer` in `AppDelegate` is created with the versioned schema and migration plan:

```swift
let schema = Schema(versionedSchema: PolarisSchema.self)
let config = ModelConfiguration("Polaris", schema: schema, ...)

let container = try ModelContainer(
    for: schema,
    migrationPlan: PolarisMigrationPlan.self,
    configurations: [config]
)
```

`PolarisMigrationPlan` declares the ordered list of schema versions and the migration stages between them. SwiftData uses this to automatically migrate the store when the app launches with a newer schema.

## Adding a New Schema Version

When you need to change model properties (add, remove, or rename fields), follow these steps:

### 1. Create the new versioned schema

In `PolarisSchema.swift`, rename the existing schema and create a new one:

```swift
// Preserve the old schema for migration reference
enum PolarisSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Project.self, Todo.self, Tag.self, ChecklistItem.self]
    }
}

// New schema with updated models
enum PolarisSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Project.self, Todo.self, Tag.self, ChecklistItem.self]
    }
}
```

### 2. Add a migration stage

For additive changes (new optional properties, new models), use a lightweight migration:

```swift
enum PolarisMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PolarisSchemaV1.self, PolarisSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: PolarisSchemaV1.self,
        toVersion: PolarisSchemaV2.self
    )
}
```

For complex changes (renaming properties, transforming data), use a custom migration:

```swift
static let migrateV1toV2 = MigrationStage.custom(
    fromVersion: PolarisSchemaV1.self,
    toVersion: PolarisSchemaV2.self
) { context in
    // Transform data here
    try context.save()
}
```

### 3. Update AppDelegate

Point the schema to the latest version:

```swift
let schema = Schema(versionedSchema: PolarisSchemaV2.self)
```

## Fallback Reset

If migration fails entirely (e.g., during development with incompatible changes), `AppDelegate` deletes the store files and creates a fresh database. This is a development convenience — in production, migrations should always be tested.

## When Lightweight Migration Works

SwiftData can handle these changes automatically with `.lightweight`:
- Adding a new property with a default value
- Adding a new optional property
- Adding a new model
- Removing a property
- Removing a model

These require `.custom` migration:
- Renaming a property
- Changing a property's type
- Splitting or merging models
- Transforming existing data

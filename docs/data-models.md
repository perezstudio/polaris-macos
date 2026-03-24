# Data Models

Polaris uses SwiftData with four persistent models stored in a named SQLite database (`"Polaris"`).

## Entity Relationship Diagram

```
Project ──1:N──> Todo ──1:N──> ChecklistItem
   │                │
   │                └──N:N──> Tag
   └──1:N──────────────────> Tag
```

## Project

Container for tasks and tags.

| Property | Type | Notes |
|----------|------|-------|
| `id` | `UUID` | Unique identifier |
| `name` | `String` | Display name |
| `note` | `String` | Markdown content |
| `icon` | `String` | SF Symbol name (default: `folder.fill`) |
| `color` | `String` | `ProjectColor` raw value, randomly assigned on creation |
| `createdAt` | `Date` | |
| `sortOrder` | `Int` | Drag-drop ordering |
| `todos` | `[Todo]` | Cascade delete |
| `tags` | `[Tag]` | Cascade delete |

## Todo

Individual task within a project. Named `Todo` (not `Task`) to avoid collision with Swift concurrency's `Task`.

| Property | Type | Notes |
|----------|------|-------|
| `title` | `String` | |
| `note` | `String` | Markdown content |
| `isCompleted` | `Bool` | |
| `dueDate` | `Date?` | Soft target date |
| `deadlineDate` | `Date?` | Hard deadline |
| `priorityRawValue` | `Int` | Stored value; use computed `priority` property |
| `createdAt` | `Date` | |
| `sortOrder` | `Int` | |
| `project` | `Project?` | Inverse of `Project.todos` |
| `checklistItems` | `[ChecklistItem]` | Cascade delete |
| `tags` | `[Tag]` | Many-to-many via inverse |

### Priority Enum

```swift
enum Priority: Int, Codable, CaseIterable {
    case low = 0      // gray
    case medium = 1   // blue
    case high = 2     // orange
    case urgent = 3   // red
}
```

Stored as `priorityRawValue: Int` in SwiftData. Access via the computed `priority` property.

## Tag

Categorical labels applied to todos, scoped to a project.

| Property | Type | Notes |
|----------|------|-------|
| `name` | `String` | |
| `color` | `String` | `ProjectColor` raw value (default: `gray`) |
| `project` | `Project?` | Owning project |
| `todos` | `[Todo]` | Many-to-many |

## ChecklistItem

Sub-task within a todo.

| Property | Type | Notes |
|----------|------|-------|
| `title` | `String` | |
| `isCompleted` | `Bool` | |
| `sortOrder` | `Int` | |
| `todo` | `Todo?` | Parent todo |

## ProjectColor

Enum defining all available colors for projects and tags. Stored as string raw values in SwiftData for readability.

```swift
enum ProjectColor: String, CaseIterable, Codable {
    case red, orange, yellow, green, mint, teal, cyan,
         blue, indigo, purple, pink, brown, gray
}
```

**Helpers:**
- `.color` — Returns the corresponding `SwiftUI.Color`
- `.label` — Capitalized display name
- `.random` — Random selection (used for new project defaults)
- `Color.fromString(_:)` — Parses a raw value string back to a `Color` (falls back to `.blue`)

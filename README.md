# Polaris

A macOS project management app built with AppKit, SwiftUI, and SwiftData.

Polaris uses a three-panel layout — sidebar, content area, and inspector — to manage projects, tasks, tags, and checklists with rich markdown notes.

## Architecture

Polaris is an AppKit-driven application that hosts SwiftUI views inside `NSHostingController` instances. This hybrid approach enables full control over the window chrome (transparent titlebar, custom split view behavior) while using SwiftUI for all UI rendering.

```
NSWindow (transparent titlebar, fullSizeContentView)
└── NSSplitViewController (3 vertical panes)
    ├── Sidebar  — Project list, drag-drop reorder, inline rename
    ├── Content  — Project detail / task list (swappable)
    └── Inspector — Task details, markdown notes, checklist (collapsible)
```

**Key patterns:**
- `@Observable` stores (`SelectionStore`, `WindowStateModel`) for reactive state
- `withObservationTracking` bridges AppKit observation to SwiftUI
- SwiftData `@Query` for automatic data binding
- Content pane swapping via `NSSplitViewItem` removal/insertion
- Live markdown editing with `NSTextView` syntax highlighting

## Data Layer

SwiftData with a named store (`"Polaris"`) and versioned schema via `VersionedSchema` / `SchemaMigrationPlan`. See [docs/data-models.md](docs/data-models.md) for full model documentation and [docs/schema-versioning.md](docs/schema-versioning.md) for migration details.

**Models:** Project, Todo, Tag, ChecklistItem

## Project Structure

```
Polaris/
├── App/           PolarisApp, AppDelegate (menu, ModelContainer)
├── Windows/       MainWindowController
├── Views/
│   ├── MainSplitViewController
│   ├── Sidebar/   SidebarView, ProjectRowView, ProjectEditSheet
│   ├── Content/   ProjectDetailView, TaskRowView, EmptyStateView
│   ├── Inspector/ InspectorView (tabbed: Details, Notes, Checklist)
│   ├── Shared/    LiveMarkdownEditor, MarkdownRenderer, MarkdownContentView
│   └── Components/ HoverButton, PolarisTabBar
├── Models/        Project, Todo, Tag, ChecklistItem, ProjectColor, PolarisSchema
├── Stores/        SelectionStore
└── Shared/        PolarisStyles, AppSettings, WindowStateModel, NSHostingControllerBridge
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+N | New Task |
| Cmd+1 | Toggle Sidebar |
| Cmd+I | Toggle Inspector |

## Building

```bash
xcodebuild -scheme Polaris -destination 'platform=macOS'
```

Requires macOS and Xcode with Swift 5.9+.

## Documentation

- [Data Models](docs/data-models.md) — Model properties, relationships, and enums
- [Schema Versioning](docs/schema-versioning.md) — Migration plan and how to add new versions
- [Architecture](docs/architecture.md) — AppKit+SwiftUI hybrid, state management, view hierarchy

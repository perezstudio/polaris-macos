# Architecture

## Overview

Polaris is a macOS application using a hybrid AppKit + SwiftUI architecture. AppKit manages the window, titlebar, and split view layout. SwiftUI renders all UI inside `NSHostingController` instances. SwiftData provides the persistence layer.

This approach is necessary because SwiftUI's `App` protocol cannot customize `NSWindow` properties like transparent titlebars or split view divider behavior.

## Application Lifecycle

```
PolarisApp (@main)
  └── NSApplicationDelegateAdaptor → AppDelegate
        ├── Creates ModelContainer (named "Polaris", versioned schema)
        ├── Sets up main menu (keyboard shortcuts)
        └── Creates MainWindowController
              └── Creates MainSplitViewController
                    ├── Creates SelectionStore, WindowStateModel
                    └── Hosts 3 SwiftUI views via NSHostingController
```

## Window Configuration

`MainWindowController` creates an `NSWindow` with:
- Transparent titlebar (`titlebarAppearsTransparent = true`)
- Hidden title (`titleVisibility = .hidden`)
- Full-size content view (`styleMask: .fullSizeContentView`)
- No toolbar separator
- Initial size: 1200x800, minimum: 900x600
- Frame autosave: `"PolarisMainWindow"`

## Three-Panel Split View

`MainSplitViewController` is an `NSSplitViewController` with three panes:

| Pane | Width | Collapsible | Content |
|------|-------|-------------|---------|
| Sidebar | 200–300px | Yes (Cmd+1) | SidebarView |
| Content | 400px min | No | ProjectDetailView or EmptyStateView |
| Inspector | 280–350px | Yes (Cmd+I) | InspectorView |

The divider style is `.thin`. Collapse/expand animations use `NSAnimationContext` (0.2s).

### Content Swapping

The content pane swaps between `EmptyStateView` (no project selected) and `ProjectDetailView` (project selected). Because `NSSplitViewItem.viewController` is read-only after creation, swapping works by removing the old split view item and inserting a new one at index 1.

The `currentProjectId` property prevents redundant swaps when the same project is re-selected.

## State Management

### SelectionStore

`@Observable` class on `@MainActor`. Holds `selectedProject: Project?` and `selectedTodo: Todo?`. Shared across all three panels.

- Sidebar sets `selectedProject` on row tap
- Content sets `selectedTodo` on task row tap
- Inspector reads `selectedTodo` for editing
- `MainSplitViewController` observes both via `withObservationTracking` to trigger content swapping and inspector expand/collapse

### WindowStateModel

`@Observable` class tracking `isSidebarCollapsed` and `isInspectorCollapsed`. SwiftUI views read these to conditionally show toggle buttons in their headers (e.g., the sidebar toggle appears in the content header only when the sidebar is collapsed).

### AppSettings

Singleton `@Observable` class persisting `appearanceMode` and `textSizeScale` to `UserDefaults`. Provides `Font.appScaled()` and `NSFont.appScaled()` extensions used throughout the app for consistent sizing.

## SwiftUI ↔ AppKit Bridging

### Hosting Controllers

Each SwiftUI view is wrapped in an `NSHostingController` via the `hostSwiftUI()` helper, which configures transparent backgrounds and proper sizing.

All panel root views use `.ignoresSafeArea(edges: .top)` to render edge-to-edge under the transparent titlebar.

### Observation Tracking

`MainSplitViewController` uses `withObservationTracking` to observe `SelectionStore` changes from AppKit:

```swift
func observeProject() {
    withObservationTracking {
        _ = selectionStore.selectedProject
    } onChange: {
        DispatchQueue.main.async { [weak self] in
            self?.handleProjectChange()
            observeProject() // re-register
        }
    }
}
```

This pattern re-registers observation after each change since `withObservationTracking` is one-shot.

## Visual Design System

Styles are defined in `PolarisStyles.swift`, ported from Admiral (Mjolnir):

- **HoverButtonStyle** — Three sizes (small 24px, regular 28px, large 32px) with hover/press opacity
- **HoverMenuStyle** — Same hover treatment for `Menu` controls
- **VisualEffectBackground** — `NSVisualEffectView` wrapper for `.sidebar` material
- **Color extensions** — `polarisAccent`, `polarisSecondaryLabel`, `polarisSeparator`, etc.

## Markdown Editor

`LiveMarkdownEditor` is an `NSViewRepresentable` wrapping a custom `NSTextView` subclass. It applies `NSAttributedString` styling on every keystroke for headers, bold, italic, inline code, code blocks, and lists while keeping the raw markdown in the text buffer. The coordinator preserves cursor position during re-styling.

`MarkdownRenderer` generates `NSAttributedString` for read-only display, used in `MarkdownContentView` (a self-sizing `NSTextView` for use in `ScrollView`).

## Menu & Keyboard Shortcuts

The main menu is built programmatically in `AppDelegate.setupMainMenu()`:

- **File** — New Task (Cmd+N)
- **Edit** — Standard text editing (Undo, Redo, Cut, Copy, Paste, Select All)
- **View** — Toggle Sidebar (Cmd+1), Toggle Inspector (Cmd+I)

Menu actions use `@objc` selectors on `MainSplitViewController`, dispatched through the responder chain.

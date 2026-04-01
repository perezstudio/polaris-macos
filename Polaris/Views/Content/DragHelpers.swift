//
//  DragHelpers.swift
//  Polaris
//
//  Shared drag-and-drop utilities used by ProjectDetailView and tab views.
//

import SwiftUI
import SwiftData

// MARK: - Generic Helpers

/// Removes a todo by ID from a dictionary of groups keyed by string.
/// Returns the removed Todo, or nil if not found.
func removeTodoFromGroups(
    draggedId: PersistentIdentifier,
    groups: inout [String: [Todo]]
) -> Todo? {
    for key in groups.keys {
        if let idx = groups[key]?.firstIndex(where: { $0.persistentModelID == draggedId }) {
            return groups[key]?.remove(at: idx)
        }
    }
    return nil
}

/// Removes a todo by ID from a flat array.
/// Returns the removed Todo, or nil if not found.
func removeTodoFromArray(
    draggedId: PersistentIdentifier,
    array: inout [Todo]
) -> Todo? {
    if let idx = array.firstIndex(where: { $0.persistentModelID == draggedId }) {
        return array.remove(at: idx)
    }
    return nil
}

/// Persists sortOrder for all todos in grouped arrays and saves.
func persistGroupSortOrders(
    groups: [String: [Todo]],
    modelContext: ModelContext
) {
    for (_, todos) in groups {
        for (i, todo) in todos.enumerated() {
            todo.sortOrder = i
        }
    }
    try? modelContext.save()
}

// MARK: - Multi-Item Helpers

/// Removes multiple todos by ID from a flat array, preserving their relative order.
/// Returns the removed todos in their original order.
func removeTodosFromArray(
    draggedIds: Set<PersistentIdentifier>,
    array: inout [Todo]
) -> [Todo] {
    var removed: [Todo] = []
    array.removeAll { todo in
        if draggedIds.contains(todo.persistentModelID) {
            removed.append(todo)
            return true
        }
        return false
    }
    return removed
}

/// Removes multiple todos by ID from grouped arrays, preserving their relative order.
/// Returns the removed todos in their original order.
func removeTodosFromGroups(
    draggedIds: Set<PersistentIdentifier>,
    groups: inout [String: [Todo]]
) -> [Todo] {
    var removed: [Todo] = []
    for key in groups.keys {
        groups[key]?.removeAll { todo in
            if draggedIds.contains(todo.persistentModelID) {
                removed.append(todo)
                return true
            }
            return false
        }
    }
    return removed
}

// MARK: - Drag Auto-Scroll

/// Invisible view that polls mouse position during drag and scrolls the parent NSScrollView.
/// Does NOT register for drag types, so it never intercepts SwiftUI drop delegates.
struct DragAutoScrollOverlay: NSViewRepresentable {
    @Binding var isDragging: Bool
    @Binding var draggedTodoModelID: PersistentIdentifier?
    var draggedSectionId: Binding<PersistentIdentifier?>? = nil
    var collapsedForDrag: Binding<Set<PersistentIdentifier>>? = nil

    func makeNSView(context: Context) -> DragAutoScrollNSView {
        let view = DragAutoScrollNSView()
        view.onDragEnded = { cleanupStaleDrag() }
        return view
    }

    func updateNSView(_ nsView: DragAutoScrollNSView, context: Context) {
        nsView.onDragEnded = { cleanupStaleDrag() }
        nsView.startPolling()
    }

    static func dismantleNSView(_ nsView: DragAutoScrollNSView, coordinator: ()) {
        nsView.stopPolling()
    }

    private func cleanupStaleDrag() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if draggedSectionId?.wrappedValue != nil || draggedTodoModelID != nil {
                if let collapsed = collapsedForDrag {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        collapsed.wrappedValue.removeAll()
                    }
                }
                draggedSectionId?.wrappedValue = nil
                draggedTodoModelID = nil
                isDragging = false
            }
        }
    }
}

final class DragAutoScrollNSView: NSView {
    private var pollTimer: Timer?
    private let edgeZone: CGFloat = 50
    private let maxSpeed: CGFloat = 12
    var onDragEnded: (() -> Void)?
    private var wasMouseDown = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil // Fully transparent to all events
    }

    func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    override func removeFromSuperview() {
        stopPolling()
        super.removeFromSuperview()
    }

    private func findScrollView() -> NSScrollView? {
        var current: NSView? = superview
        while let view = current {
            if let sv = view as? NSScrollView { return sv }
            current = view.superview
        }
        return nil
    }

    private func tick() {
        guard let window = window, let scrollView = findScrollView() else { return }

        let mouseDown = NSEvent.pressedMouseButtons & 1 != 0
        if wasMouseDown && !mouseDown {
            wasMouseDown = false
            onDragEnded?()
            return
        }
        wasMouseDown = mouseDown
        guard mouseDown else { return }

        let mouseInWindow = window.mouseLocationOutsideOfEventStream
        let mouseInView = scrollView.convert(mouseInWindow, from: nil)
        let visibleRect = scrollView.contentView.bounds

        guard mouseInView.x >= -20 && mouseInView.x <= scrollView.bounds.width + 20 else { return }

        let scrollBounds = scrollView.bounds
        let distFromVisualTop = scrollBounds.maxY - mouseInView.y
        let distFromVisualBottom = mouseInView.y - scrollBounds.minY

        var speed: CGFloat = 0
        if distFromVisualTop < edgeZone && distFromVisualTop >= -10 {
            let factor = 1.0 - max(0, distFromVisualTop) / edgeZone
            speed = -maxSpeed * factor
        } else if distFromVisualBottom < edgeZone && distFromVisualBottom >= -10 {
            let factor = 1.0 - max(0, distFromVisualBottom) / edgeZone
            speed = maxSpeed * factor
        }

        guard abs(speed) > 0.5 else { return }

        let clipView = scrollView.contentView
        var origin = visibleRect.origin
        if scrollView.documentView?.isFlipped == true {
            origin.y += speed
        } else {
            origin.y -= speed
        }
        let maxY = (scrollView.documentView?.frame.height ?? 0) - clipView.bounds.height
        origin.y = max(0, min(origin.y, maxY))
        clipView.setBoundsOrigin(origin)
        scrollView.reflectScrolledClipView(clipView)
    }
}

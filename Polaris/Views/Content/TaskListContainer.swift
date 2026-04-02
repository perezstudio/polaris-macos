//
//  TaskListContainer.swift
//  Polaris
//
//  Shared shell for tab content views: header, scrollable task list,
//  keyboard navigation, and inspector integration.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Inline Editing Preference Key

/// Propagates inline editing state from TaskRowView up to TaskListContainer.
struct InlineEditingKey: PreferenceKey {
    static var defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

struct TaskListContainer<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let selectionStore: SelectionStore
    let windowState: WindowStateModel
    var onToggleSidebar: (() -> Void)?
    var onToggleInspector: (() -> Void)?
    var allTodos: [Todo]
    var onAddTask: (() -> Void)?

    // Optional drag support
    var isDragging: Binding<Bool>?
    var draggedTodoModelID: Binding<PersistentIdentifier?>?
    var onPerformBackgroundDrop: (() -> Void)?

    @ViewBuilder let content: (ScrollViewProxy) -> Content

    @FocusState private var isListFocused: Bool
    @State private var isEditingInline = false
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            content(proxy)
                        }
                        .frame(maxWidth: 800)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 68)
                        .padding(.bottom, 24)
                        .frame(minHeight: geometry.size.height, alignment: .top)
                        .background {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { deselectTask() }
                        }
                        .modifier(BackgroundDropModifier(
                            isDragging: isDragging,
                            draggedTodoModelID: draggedTodoModelID,
                            onPerformDrop: onPerformBackgroundDrop
                        ))
                    }
                    .onAppear { scrollProxy = proxy }
                }
                .overlay {
                    if let isDragging, let draggedTodoModelID,
                       isDragging.wrappedValue {
                        DragAutoScrollOverlay(
                            isDragging: isDragging,
                            draggedTodoModelID: draggedTodoModelID
                        )
                    }
                }
            }

            VStack(spacing: 0) {
                headerBar
                    .modifier(BackgroundDropModifier(
                        isDragging: isDragging,
                        draggedTodoModelID: draggedTodoModelID,
                        onPerformDrop: onPerformBackgroundDrop
                    ))
                    .background(VisualEffectBackground(material: .headerView, blendingMode: .withinWindow))
                Divider()
            }
            .zIndex(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .focusable()
        .focused($isListFocused)
        .focusEffectDisabled()
        .onPreferenceChange(InlineEditingKey.self) { editing in
            Log.editing.debug("[TaskListContainer:\(title)] isEditingInline changed: \(editing)")
            isEditingInline = editing
            if editing {
                isListFocused = false
                Log.focus.debug("[TaskListContainer:\(title)] yielded focus for inline editing")
            } else {
                DispatchQueue.main.async {
                    // Don't steal focus from AppKit text views (e.g. notes editor in inspector)
                    if let firstResponder = NSApp.keyWindow?.firstResponder,
                       firstResponder is NSTextView {
                        Log.focus.debug("[TaskListContainer:\(title)] skipped focus reclaim – NSTextView is first responder")
                        return
                    }
                    isListFocused = true
                    Log.focus.debug("[TaskListContainer:\(title)] reclaimed focus after inline editing")
                }
            }
        }
        .onChange(of: isListFocused) { _, focused in
            Log.focus.debug("[TaskListContainer:\(title)] isListFocused changed: \(focused)")
        }
        .onAppear { isListFocused = true }
        .onKeyPress(.upArrow) {
            guard !isEditingInline else {
                Log.shortcut.debug("[TaskListContainer:\(title)] ↑ ignored (editing inline)")
                return .ignored
            }
            Log.shortcut.debug("[TaskListContainer:\(title)] ↑ handled")
            let isShift = NSApp.currentEvent?.modifierFlags.contains(.shift) == true
            if isShift {
                navigateSelectionExtending(direction: -1)
            } else {
                navigateSelection(direction: -1)
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            guard !isEditingInline else {
                Log.shortcut.debug("[TaskListContainer:\(title)] ↓ ignored (editing inline)")
                return .ignored
            }
            Log.shortcut.debug("[TaskListContainer:\(title)] ↓ handled")
            let isShift = NSApp.currentEvent?.modifierFlags.contains(.shift) == true
            if isShift {
                navigateSelectionExtending(direction: 1)
            } else {
                navigateSelection(direction: 1)
            }
            return .handled
        }
        .onKeyPress(.return) {
            guard !isEditingInline else {
                Log.shortcut.debug("[TaskListContainer:\(title)] ↩ ignored (editing inline)")
                return .ignored
            }
            Log.shortcut.debug("[TaskListContainer:\(title)] ↩ handled")
            if let todo = selectionStore.selectedTodo {
                expandInspector(for: todo)
            }
            return .handled
        }
        .onKeyPress(.escape) {
            guard !isEditingInline else {
                Log.shortcut.debug("[TaskListContainer:\(title)] ⎋ ignored (editing inline)")
                return .ignored
            }
            Log.shortcut.debug("[TaskListContainer:\(title)] ⎋ handled → deselectTask")
            deselectTask()
            return .handled
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 4) {
            if windowState.isSidebarCollapsed {
                Button {
                    onToggleSidebar?()
                } label: {
                    Image(systemName: "sidebar.leading")
                        .font(.appScaled(size: 14))
                }
                .buttonStyle(.polarisHover(size: .large))
            }

            Image(systemName: icon)
                .font(.appScaled(size: 14))
                .foregroundStyle(iconColor)
                .padding(.leading, 4)

            Text(title)
                .font(.appScaled(size: 13, weight: .medium))
                .lineLimit(1)

            Spacer()

            if let onAddTask {
                Button {
                    onAddTask()
                } label: {
                    Image(systemName: "plus")
                        .font(.appScaled(size: 14))
                }
                .buttonStyle(.polarisHover(size: .large))
            }

            if windowState.isInspectorCollapsed {
                Button {
                    onToggleInspector?()
                } label: {
                    Image(systemName: "sidebar.trailing")
                        .font(.appScaled(size: 14))
                }
                .buttonStyle(.polarisHover(size: .large))
            }
        }
        .padding(.horizontal, 8)
        .padding(.leading, windowState.isSidebarCollapsed ? 68 : 0)
        .frame(height: 52)
    }

    // MARK: - Keyboard Navigation

    private func navigateSelection(direction: Int) {
        let todos = allTodos
        guard !todos.isEmpty else { return }

        guard let current = selectionStore.selectedTodo,
              let currentIndex = todos.firstIndex(where: { $0.persistentModelID == current.persistentModelID }) else {
            if let first = todos.first {
                selectionStore.selectSingle(first)
                expandInspector(for: first)
                scrollToTodo(first)
            }
            return
        }

        let newIndex = currentIndex + direction
        guard newIndex >= 0 && newIndex < todos.count else { return }
        let todo = todos[newIndex]
        selectionStore.selectSingle(todo)
        expandInspector(for: todo)
        scrollToTodo(todo)
    }

    private func navigateSelectionExtending(direction: Int) {
        let todos = allTodos
        guard !todos.isEmpty else { return }

        guard let current = selectionStore.selectedTodo,
              let currentIndex = todos.firstIndex(where: { $0.persistentModelID == current.persistentModelID }) else {
            if let first = todos.first {
                selectionStore.selectSingle(first)
                scrollToTodo(first)
            }
            return
        }

        let newIndex = currentIndex + direction
        guard newIndex >= 0 && newIndex < todos.count else { return }
        let todo = todos[newIndex]
        selectionStore.extendSelectionStep(to: todo)
        scrollToTodo(todo)
    }

    private func scrollToTodo(_ todo: Todo) {
        withAnimation(.easeInOut(duration: 0.2)) {
            scrollProxy?.scrollTo(todo.persistentModelID, anchor: .center)
        }
    }

    func expandInspector(for todo: Todo) {
        selectionStore.selectedTodo = todo
        if windowState.isInspectorCollapsed {
            onToggleInspector?()
        }
    }

    private func deselectTask() {
        selectionStore.clearSelection()
        if !windowState.isInspectorCollapsed {
            onToggleInspector?()
        }
        isListFocused = true
    }
}

// MARK: - Background Drop Modifier

/// Conditionally applies a background drop delegate when drag state is provided.
private struct BackgroundDropModifier: ViewModifier {
    var isDragging: Binding<Bool>?
    var draggedTodoModelID: Binding<PersistentIdentifier?>?
    var onPerformDrop: (() -> Void)?

    func body(content: Content) -> some View {
        if let isDragging, let draggedTodoModelID, let onPerformDrop {
            content.onDrop(of: [.text], delegate: TabBackgroundDropDelegate(
                isDragging: isDragging,
                draggedTodoModelID: draggedTodoModelID,
                onPerformDrop: onPerformDrop
            ))
        } else {
            content
        }
    }
}

/// Generic background drop delegate for tab views.
/// On drop, calls onPerformDrop which each view uses to persist sort orders and clear state.
private struct TabBackgroundDropDelegate: DropDelegate {
    @Binding var isDragging: Bool
    @Binding var draggedTodoModelID: PersistentIdentifier?
    let onPerformDrop: () -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard draggedTodoModelID != nil else { return false }
        onPerformDrop()
        draggedTodoModelID = nil
        isDragging = false
        return true
    }
}

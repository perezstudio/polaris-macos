//
//  InboxView.swift
//  Polaris
//
//  Displays all tasks not assigned to a project.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct InboxView: View {
    let selectionStore: SelectionStore
    let windowState: WindowStateModel
    var onToggleSidebar: (() -> Void)?
    var onToggleInspector: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Todo> { $0.project == nil && !$0.isCompleted },
           sort: [SortDescriptor(\Todo.sortOrder)])
    private var inboxTodos: [Todo]

    @State private var newlyCreatedTodoID: PersistentIdentifier?
    @State private var orderedTodos: [Todo] = []
    @State private var draggedTodoModelID: PersistentIdentifier?
    @State private var isDragging = false

    private var sortedTodos: [Todo] {
        inboxTodos.sorted { a, b in
            if a.isCompleted != b.isCompleted { return !a.isCompleted }
            return a.sortOrder < b.sortOrder
        }
    }

    var body: some View {
        TaskListContainer(
            title: "Inbox",
            icon: "tray.fill",
            iconColor: .blue,
            selectionStore: selectionStore,
            windowState: windowState,
            onToggleSidebar: onToggleSidebar,
            onToggleInspector: onToggleInspector,
            allTodos: orderedTodos,
            onAddTask: { addTask() },
            isDragging: $isDragging,
            draggedTodoModelID: $draggedTodoModelID,
            onPerformBackgroundDrop: { performBackgroundDrop() }
        ) { proxy in
            if orderedTodos.isEmpty {
                emptyState
            } else {
                ForEach(orderedTodos) { todo in
                    taskRow(for: todo)
                }

                // End-of-list drop target
                Color.clear
                    .frame(height: 8)
                    .contentShape(Rectangle())
                    .onDrop(of: [.text], delegate: InboxEndOfListDropDelegate(
                        orderedTodos: $orderedTodos,
                        draggedTodoModelID: $draggedTodoModelID,
                        isDragging: $isDragging,
                        modelContext: modelContext
                    ))
            }
        }
        .onAppear { syncState() }
        .onChange(of: inboxTodos.count) { old, new in
            guard !isDragging else { return }
            Log.data.debug("[InboxView] inboxTodos.count changed: \(old) → \(new) → syncState")
            syncState()
        }
        .onChange(of: inboxTodos.map(\.persistentModelID)) {
            guard !isDragging else { return }
            Log.data.debug("[InboxView] inboxTodos IDs changed → syncState (animated)")
            withAnimation(.easeInOut(duration: 0.35)) {
                syncState()
            }
        }
        .onChange(of: selectionStore.addTaskRequested) { _, requested in
            if requested {
                selectionStore.addTaskRequested = false
                addTask()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 100)
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("Inbox is empty")
                .font(.appScaled(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Button("Add Task") {
                addTask()
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func taskRow(for todo: Todo) -> some View {
        let isSelected = selectionStore.selectedTodo?.persistentModelID == todo.persistentModelID
        let isBeingDragged = draggedTodoModelID == todo.persistentModelID

        TaskRowView(
            todo: todo,
            isSelected: isSelected,
            startInEditMode: newlyCreatedTodoID == todo.persistentModelID,
            onSelect: {
                selectionStore.selectedTodo = todo
                if windowState.isInspectorCollapsed {
                    onToggleInspector?()
                }
            },
            onEditModeStarted: {
                newlyCreatedTodoID = nil
            }
        )
        .opacity(isBeingDragged ? 0.35 : 1.0)
        .scaleEffect(isBeingDragged ? 0.95 : 1.0)
        .onDrag {
            isDragging = true
            draggedTodoModelID = todo.persistentModelID
            return NSItemProvider(object: todo.persistentModelID.hashValue.description as NSString)
        }
        .onDrop(of: [.text], delegate: InboxTodoDropDelegate(
            targetTodo: todo,
            orderedTodos: $orderedTodos,
            draggedTodoModelID: $draggedTodoModelID,
            isDragging: $isDragging,
            modelContext: modelContext
        ))
        .contextMenu {
            Button("Delete", role: .destructive) {
                deleteTodo(todo)
            }
        }
        .id(todo.persistentModelID)
    }

    // MARK: - State Sync

    private func syncState() {
        orderedTodos = sortedTodos
    }

    private func performBackgroundDrop() {
        for (i, todo) in orderedTodos.enumerated() {
            todo.sortOrder = i
        }
        try? modelContext.save()
    }

    // MARK: - Actions

    private func addTask() {
        let maxOrder = inboxTodos.map(\.sortOrder).max() ?? -1
        let todo = Todo(title: "", sortOrder: maxOrder + 1)
        modelContext.insert(todo)
        try? modelContext.save()
        Log.data.info("[InboxView] addTask – saved, ID: \(todo.persistentModelID.hashValue)")
        selectionStore.selectedTodo = todo
        newlyCreatedTodoID = todo.persistentModelID
        if windowState.isInspectorCollapsed {
            onToggleInspector?()
        }
    }

    private func deleteTodo(_ todo: Todo) {
        if selectionStore.selectedTodo?.persistentModelID == todo.persistentModelID {
            selectionStore.selectedTodo = nil
        }
        modelContext.delete(todo)
    }
}

// MARK: - Drop Delegates

private struct InboxTodoDropDelegate: DropDelegate {
    let targetTodo: Todo
    @Binding var orderedTodos: [Todo]
    @Binding var draggedTodoModelID: PersistentIdentifier?
    @Binding var isDragging: Bool
    let modelContext: ModelContext

    func dropEntered(info: DropInfo) {
        guard let draggedId = draggedTodoModelID,
              draggedId != targetTodo.persistentModelID else { return }

        isDragging = true

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            guard let dragged = removeTodoFromArray(draggedId: draggedId, array: &orderedTodos) else { return }

            if let toIndex = orderedTodos.firstIndex(where: { $0.persistentModelID == targetTodo.persistentModelID }) {
                orderedTodos.insert(dragged, at: toIndex)
            } else {
                orderedTodos.append(dragged)
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard draggedTodoModelID != nil else { return false }

        for (i, todo) in orderedTodos.enumerated() {
            todo.sortOrder = i
        }
        try? modelContext.save()

        draggedTodoModelID = nil
        isDragging = false
        return true
    }
}

private struct InboxEndOfListDropDelegate: DropDelegate {
    @Binding var orderedTodos: [Todo]
    @Binding var draggedTodoModelID: PersistentIdentifier?
    @Binding var isDragging: Bool
    let modelContext: ModelContext

    func dropEntered(info: DropInfo) {
        guard let draggedId = draggedTodoModelID else { return }
        isDragging = true

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            guard let dragged = removeTodoFromArray(draggedId: draggedId, array: &orderedTodos) else { return }
            orderedTodos.append(dragged)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard draggedTodoModelID != nil else { return false }

        for (i, todo) in orderedTodos.enumerated() {
            todo.sortOrder = i
        }
        try? modelContext.save()

        draggedTodoModelID = nil
        isDragging = false
        return true
    }
}

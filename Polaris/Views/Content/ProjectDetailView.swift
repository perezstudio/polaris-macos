//
//  ProjectDetailView.swift
//  Polaris
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ProjectDetailView: View {
    @Bindable var project: Project
    let selectionStore: SelectionStore
    let windowState: WindowStateModel
    var onToggleSidebar: (() -> Void)?
    var onToggleInspector: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @FocusState private var isListFocused: Bool
    @State private var draggedTodoModelID: PersistentIdentifier?
    @State private var orderedTodos: [Todo] = []

    private var sortedTodos: [Todo] {
        project.todos.sorted { a, b in
            if a.isCompleted != b.isCompleted { return !a.isCompleted }
            return a.sortOrder < b.sortOrder
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            taskList

            VStack(spacing: 0) {
                headerBar
                    .background(VisualEffectBackground(material: .headerView, blendingMode: .withinWindow))
                Divider()
            }
            .zIndex(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .focusable()
        .focused($isListFocused)
        .focusEffectDisabled()
        .onAppear { isListFocused = true }
        .onKeyPress(.upArrow) {
            navigateSelection(direction: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            navigateSelection(direction: 1)
            return .handled
        }
        .onKeyPress(.return) {
            if let todo = selectionStore.selectedTodo {
                expandInspector(for: todo)
            }
            return .handled
        }
        .onKeyPress(.escape) {
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

            Image(systemName: project.icon)
                .font(.appScaled(size: 14))
                .foregroundStyle(Color.fromString(project.color))
                .padding(.leading, 4)

            Text(project.name)
                .font(.appScaled(size: 13, weight: .medium))
                .lineLimit(1)

            Spacer()

            Button {
                addTodo()
            } label: {
                Image(systemName: "plus")
                    .font(.appScaled(size: 14))
            }
            .buttonStyle(.polarisHover(size: .large))

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
        .frame(height: 52)
    }

    // MARK: - Task List

    @ViewBuilder
    private var taskList: some View {
        if sortedTodos.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "checklist")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
                Text("No tasks yet")
                    .font(.appScaled(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                Button("Add Task") {
                    addTodo()
                }
                .controlSize(.small)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            GeometryReader { geometry in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(orderedTodos) { todo in
                            taskRow(for: todo)
                        }
                    }
                    .frame(maxWidth: 800)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 68)
                    .padding(.bottom, 24)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                    .contentShape(Rectangle())
                    .onTapGesture { deselectTask() }
                }
            }
            .onAppear { orderedTodos = sortedTodos }
            .onChange(of: project.todos) { orderedTodos = sortedTodos }
        }
    }

    // MARK: - Task Row

    @ViewBuilder
    private func taskRow(for todo: Todo) -> some View {
        let isSelected = selectionStore.selectedTodo?.persistentModelID == todo.persistentModelID
        let isBeingDragged = draggedTodoModelID == todo.persistentModelID

        TaskRowView(
            todo: todo,
            isSelected: isSelected,
            onSelect: {
                selectionStore.selectedTodo = todo
                isListFocused = true
                expandInspector(for: todo)
            }
        )
        .opacity(isBeingDragged ? 0.35 : 1.0)
        .scaleEffect(isBeingDragged ? 0.95 : 1.0)
        .onDrag {
            draggedTodoModelID = todo.persistentModelID
            return NSItemProvider(object: todo.persistentModelID.hashValue.description as NSString)
        }
        .onDrop(of: [.text], delegate: TodoDropDelegate(
            targetTodoModelID: todo.persistentModelID,
            orderedTodos: $orderedTodos,
            draggedTodoModelID: $draggedTodoModelID,
            modelContext: modelContext
        ))
        .contextMenu {
            Button("Delete", role: .destructive) {
                deleteTodo(todo)
            }
        }
    }

    // MARK: - Keyboard Navigation

    private func navigateSelection(direction: Int) {
        let todos = sortedTodos
        guard !todos.isEmpty else { return }

        guard let current = selectionStore.selectedTodo,
              let currentIndex = todos.firstIndex(where: { $0.persistentModelID == current.persistentModelID }) else {
            selectionStore.selectedTodo = todos.first
            if let first = todos.first { expandInspector(for: first) }
            return
        }

        let newIndex = currentIndex + direction
        guard newIndex >= 0 && newIndex < todos.count else { return }
        selectionStore.selectedTodo = todos[newIndex]
        expandInspector(for: todos[newIndex])
    }

    private func expandInspector(for todo: Todo) {
        selectionStore.selectedTodo = todo
        if windowState.isInspectorCollapsed {
            onToggleInspector?()
        }
    }

    private func deselectTask() {
        selectionStore.selectedTodo = nil
        if !windowState.isInspectorCollapsed {
            onToggleInspector?()
        }
        isListFocused = true
    }

    // MARK: - Actions

    private func addTodo() {
        let todo = Todo(title: "", sortOrder: project.todos.count)
        todo.project = project
        modelContext.insert(todo)
        selectionStore.selectedTodo = todo
        expandInspector(for: todo)
        isListFocused = true
    }

    private func deleteTodo(_ todo: Todo) {
        if selectionStore.selectedTodo?.persistentModelID == todo.persistentModelID {
            selectionStore.selectedTodo = nil
        }
        modelContext.delete(todo)
    }
}

// MARK: - Drop Delegate

private struct TodoDropDelegate: DropDelegate {
    let targetTodoModelID: PersistentIdentifier
    @Binding var orderedTodos: [Todo]
    @Binding var draggedTodoModelID: PersistentIdentifier?
    let modelContext: ModelContext

    func dropEntered(info: DropInfo) {
        guard let draggedId = draggedTodoModelID,
              draggedId != targetTodoModelID,
              let fromIndex = orderedTodos.firstIndex(where: { $0.persistentModelID == draggedId }),
              let toIndex = orderedTodos.firstIndex(where: { $0.persistentModelID == targetTodoModelID }) else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            orderedTodos.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        for (i, todo) in orderedTodos.enumerated() {
            todo.sortOrder = i
        }
        try? modelContext.save()
        draggedTodoModelID = nil
        return true
    }

    func dropExited(info: DropInfo) {
        // No-op — items are already in the right position
    }
}

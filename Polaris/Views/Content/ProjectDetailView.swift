//
//  ProjectDetailView.swift
//  Polaris
//

import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Bindable var project: Project
    let selectionStore: SelectionStore
    let windowState: WindowStateModel
    var onToggleSidebar: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @State private var openedTodoId: PersistentIdentifier?

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
                    .background(VisualEffectBackground(material: .titlebar))
                Divider()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.polarisWindowBackground)
        .ignoresSafeArea(edges: .top)
        .onKeyPress(.upArrow) { navigateSelection(direction: -1); return .handled }
        .onKeyPress(.downArrow) { navigateSelection(direction: 1); return .handled }
        .onKeyPress(.return) { toggleOpenCard(); return .handled }
        .onKeyPress(.escape) { closeCard(); return .handled }
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
        }
        .padding(.horizontal, 8)
        .frame(height: 52)
    }

    // MARK: - Task List

    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(sortedTodos) { todo in
                    let isSelected = selectionStore.selectedTodo?.persistentModelID == todo.persistentModelID
                    let isOpen = openedTodoId == todo.persistentModelID

                    if isOpen {
                        TaskCardView(todo: todo) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                openedTodoId = nil
                            }
                        }
                        .padding(.vertical, 4)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        TaskRowView(
                            todo: todo,
                            isSelected: isSelected,
                            onSelect: {
                                selectionStore.selectedTodo = todo
                            },
                            onDoubleClick: {
                                openCard(for: todo)
                            }
                        )
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                deleteTodo(todo)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 800)
            .padding(.horizontal, 12)
            .padding(.top, 60)
        }
    }

    // MARK: - Keyboard Navigation

    private func navigateSelection(direction: Int) {
        let todos = sortedTodos
        guard !todos.isEmpty else { return }

        guard let current = selectionStore.selectedTodo,
              let currentIndex = todos.firstIndex(where: { $0.persistentModelID == current.persistentModelID }) else {
            selectionStore.selectedTodo = todos.first
            return
        }

        let newIndex = currentIndex + direction
        guard newIndex >= 0 && newIndex < todos.count else { return }
        selectionStore.selectedTodo = todos[newIndex]
    }

    private func toggleOpenCard() {
        guard let todo = selectionStore.selectedTodo else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            if openedTodoId == todo.persistentModelID {
                openedTodoId = nil
            } else {
                openedTodoId = todo.persistentModelID
            }
        }
    }

    private func openCard(for todo: Todo) {
        selectionStore.selectedTodo = todo
        withAnimation(.easeInOut(duration: 0.2)) {
            openedTodoId = todo.persistentModelID
        }
    }

    private func closeCard() {
        if openedTodoId != nil {
            withAnimation(.easeInOut(duration: 0.2)) {
                openedTodoId = nil
            }
        }
    }

    // MARK: - Actions

    private func addTodo() {
        let todo = Todo(title: "", sortOrder: project.todos.count)
        todo.project = project
        modelContext.insert(todo)
        selectionStore.selectedTodo = todo
    }

    private func deleteTodo(_ todo: Todo) {
        if openedTodoId == todo.persistentModelID {
            openedTodoId = nil
        }
        if selectionStore.selectedTodo?.persistentModelID == todo.persistentModelID {
            selectionStore.selectedTodo = nil
        }
        modelContext.delete(todo)
    }
}

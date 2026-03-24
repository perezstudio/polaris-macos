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
    var onToggleInspector: (() -> Void)?

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            headerBar

            Divider()

            // Task list
            taskList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.polarisWindowBackground)
        .ignoresSafeArea(edges: .top)
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
                .padding(.leading, windowState.isSidebarCollapsed ? 4 : 4)

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

    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                let sortedTodos = project.todos.sorted { a, b in
                    if a.isCompleted != b.isCompleted { return !a.isCompleted }
                    return a.sortOrder < b.sortOrder
                }

                ForEach(sortedTodos) { todo in
                    TaskRowView(
                        todo: todo,
                        isSelected: selectionStore.selectedTodo?.id == todo.id,
                        onSelect: {
                            selectionStore.selectedTodo = todo
                        }
                    )
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            deleteTodo(todo)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
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
        if selectionStore.selectedTodo?.id == todo.id {
            selectionStore.selectedTodo = nil
        }
        modelContext.delete(todo)
    }
}

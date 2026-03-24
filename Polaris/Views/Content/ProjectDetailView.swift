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
    @FocusState private var isListFocused: Bool

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
                        ForEach(sortedTodos) { todo in
                            let isSelected = selectionStore.selectedTodo?.persistentModelID == todo.persistentModelID

                            TaskRowView(
                                todo: todo,
                                isSelected: isSelected,
                                onSelect: {
                                    selectionStore.selectedTodo = todo
                                    isListFocused = true
                                    expandInspector(for: todo)
                                }
                            )
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    deleteTodo(todo)
                                }
                            }
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

//
//  LogbookView.swift
//  Polaris
//
//  Displays all completed tasks grouped by completion date.
//

import SwiftUI
import SwiftData

struct LogbookView: View {
    @Environment(\.modelContext) private var modelContext
    let selectionStore: SelectionStore
    let windowState: WindowStateModel
    var onToggleSidebar: (() -> Void)?
    var onToggleInspector: (() -> Void)?

    @Query(filter: #Predicate<Todo> { $0.isCompleted },
           sort: [SortDescriptor(\Todo.createdAt, order: .reverse)])
    private var completedTodos: [Todo]

    @State private var collapsedGroups: Set<String> = []

    private struct DateGroup: Identifiable {
        let id: String
        let title: String
        let todos: [Todo]
    }

    private var dateGroups: [DateGroup] {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? startOfToday

        var today: [Todo] = []
        var yesterday: [Todo] = []
        var thisWeek: [Todo] = []
        var thisMonth: [Todo] = []
        var older: [Todo] = []

        for todo in completedTodos {
            let date = todo.completedAt ?? todo.createdAt
            if date >= startOfToday {
                today.append(todo)
            } else if date >= startOfYesterday {
                yesterday.append(todo)
            } else if date >= startOfWeek {
                thisWeek.append(todo)
            } else if date >= startOfMonth {
                thisMonth.append(todo)
            } else {
                older.append(todo)
            }
        }

        var groups: [DateGroup] = []
        if !today.isEmpty { groups.append(DateGroup(id: "today", title: "Today", todos: today)) }
        if !yesterday.isEmpty { groups.append(DateGroup(id: "yesterday", title: "Yesterday", todos: yesterday)) }
        if !thisWeek.isEmpty { groups.append(DateGroup(id: "thisWeek", title: "This Week", todos: thisWeek)) }
        if !thisMonth.isEmpty { groups.append(DateGroup(id: "thisMonth", title: "This Month", todos: thisMonth)) }
        if !older.isEmpty { groups.append(DateGroup(id: "older", title: "Older", todos: older)) }
        return groups
    }

    private var flatTodos: [Todo] {
        dateGroups.flatMap(\.todos)
    }

    var body: some View {
        TaskListContainer(
            title: "Logbook",
            icon: "checkmark.circle.fill",
            iconColor: .green,
            selectionStore: selectionStore,
            windowState: windowState,
            onToggleSidebar: onToggleSidebar,
            onToggleInspector: onToggleInspector,
            allTodos: flatTodos
        ) { proxy in
            if flatTodos.isEmpty {
                emptyState
            } else {
                ForEach(dateGroups) { group in
                    TabSectionHeaderView(
                        title: group.title,
                        icon: "checkmark.circle.fill",
                        color: .green,
                        isCollapsed: collapsedGroups.contains(group.id),
                        onToggleCollapse: { toggleCollapse(group.id) }
                    )
                    .padding(.top, 8)

                    if !collapsedGroups.contains(group.id) {
                        ForEach(group.todos) { todo in
                            taskRow(for: todo)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 100)
            Image(systemName: "checkmark.circle")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No completed tasks")
                .font(.appScaled(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }


    @ViewBuilder
    private func taskRow(for todo: Todo) -> some View {
        let isSelected = selectionStore.isSelected(todo)

        TaskRowView(
            todo: todo,
            isSelected: isSelected,
            selectionPosition: selectionStore.selectionPosition(of: todo, in: flatTodos),
            onSelect: { modifiers in
                if modifiers.contains(.shift) {
                    selectionStore.extendSelection(to: todo, in: flatTodos)
                } else {
                    selectionStore.selectSingle(todo)
                    if windowState.isInspectorCollapsed {
                        onToggleInspector?()
                    }
                }
            }
        )
        .contextMenu {
            Button("Delete", role: .destructive) {
                deleteTodo(todo)
            }
        }
        .id(todo.persistentModelID)
    }

    private func deleteTodo(_ todo: Todo) {
        if selectionStore.selectedTodo?.persistentModelID == todo.persistentModelID {
            selectionStore.selectedTodo = nil
        }
        modelContext.delete(todo)
    }

    private func toggleCollapse(_ key: String) {
        if collapsedGroups.contains(key) {
            collapsedGroups.remove(key)
        } else {
            collapsedGroups.insert(key)
        }
    }
}

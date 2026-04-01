//
//  TodayView.swift
//  Polaris
//
//  Displays all tasks with a due date or deadline on or before today.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct TodayView: View {
    let selectionStore: SelectionStore
    let windowState: WindowStateModel
    var onToggleSidebar: (() -> Void)?
    var onToggleInspector: (() -> Void)?

    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Todo> { !$0.isCompleted },
           sort: [SortDescriptor(\Todo.sortOrder)])
    private var allTodos: [Todo]

    @State private var orderedOverdue: [Todo] = []
    @State private var orderedToday: [Todo] = []
    @State private var draggedTodoModelID: PersistentIdentifier?
    @State private var isDragging = false
    @State private var collapsedSections: Set<String> = []
    @State private var highlightedSection: String?

    private var todayTodos: [Todo] {
        allTodos.filter(\.isToday).sorted { a, b in
            let aDate = a.effectiveDate ?? .distantFuture
            let bDate = b.effectiveDate ?? .distantFuture
            return aDate < bDate
        }
    }

    private var computedOverdue: [Todo] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return todayTodos.filter { todo in
            if let due = todo.dueDate, due < startOfToday { return true }
            if let deadline = todo.deadlineDate, deadline < startOfToday { return true }
            return false
        }
    }

    private var computedDueToday: [Todo] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return todayTodos.filter { todo in
            let dueIsPast = todo.dueDate.map { $0 < startOfToday } ?? false
            let deadlineIsPast = todo.deadlineDate.map { $0 < startOfToday } ?? false
            let dueIsToday = todo.dueDate.map { $0 >= startOfToday } ?? false
            let deadlineIsToday = todo.deadlineDate.map { $0 >= startOfToday } ?? false
            return !dueIsPast && !deadlineIsPast && (dueIsToday || deadlineIsToday)
        }
    }

    private var allVisibleTodos: [Todo] {
        var result: [Todo] = []
        if !collapsedSections.contains("overdue") { result.append(contentsOf: orderedOverdue) }
        if !collapsedSections.contains("today") { result.append(contentsOf: orderedToday) }
        return result
    }

    var body: some View {
        TaskListContainer(
            title: "Today",
            icon: "star.fill",
            iconColor: .yellow,
            selectionStore: selectionStore,
            windowState: windowState,
            onToggleSidebar: onToggleSidebar,
            onToggleInspector: onToggleInspector,
            allTodos: allVisibleTodos
        ) { proxy in
            if orderedOverdue.isEmpty && orderedToday.isEmpty {
                emptyState
            } else {
                if !orderedOverdue.isEmpty {
                    TabSectionHeaderView(
                        title: "Overdue",
                        icon: "exclamationmark.circle.fill",
                        color: .red,
                        isCollapsed: collapsedSections.contains("overdue"),
                        onToggleCollapse: { toggleCollapse("overdue") }
                    )
                    .padding(.top, 8)

                    if !collapsedSections.contains("overdue") {
                        ForEach(orderedOverdue) { todo in
                            taskRow(for: todo, sectionKey: "overdue")
                        }
                    }
                }

                if !orderedToday.isEmpty {
                    TabSectionHeaderView(
                        title: "Today",
                        icon: "star.fill",
                        color: .yellow,
                        isCollapsed: collapsedSections.contains("today"),
                        onToggleCollapse: { toggleCollapse("today") },
                        isDropTarget: highlightedSection == "today"
                    )
                    .padding(.top, 8)
                    .onDrop(of: [.text], delegate: TodaySectionDropDelegate(
                        sectionKey: "today",
                        orderedOverdue: $orderedOverdue,
                        orderedToday: $orderedToday,
                        draggedTodoModelID: $draggedTodoModelID,
                        isDragging: $isDragging,
                        highlightedSection: $highlightedSection,
                        modelContext: modelContext
                    ))

                    if !collapsedSections.contains("today") {
                        ForEach(orderedToday) { todo in
                            taskRow(for: todo, sectionKey: "today")
                        }
                    }
                }
            }
        }
        .onAppear { syncState() }
        .onChange(of: allTodos.count) {
            guard !isDragging else { return }
            syncState()
        }
        .onChange(of: allTodos.map(\.persistentModelID)) {
            guard !isDragging else { return }
            withAnimation(.easeInOut(duration: 0.35)) {
                syncState()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 100)
            Image(systemName: "star")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("Nothing due today")
                .font(.appScaled(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func taskRow(for todo: Todo, sectionKey: String) -> some View {
        let isSelected = selectionStore.selectedTodo?.persistentModelID == todo.persistentModelID
        let isBeingDragged = draggedTodoModelID == todo.persistentModelID

        TaskRowView(
            todo: todo,
            isSelected: isSelected,
            onSelect: {
                selectionStore.selectedTodo = todo
                if windowState.isInspectorCollapsed {
                    onToggleInspector?()
                }
            }
        )
        .opacity(isBeingDragged ? 0.35 : 1.0)
        .scaleEffect(isBeingDragged ? 0.95 : 1.0)
        .onDrag {
            isDragging = true
            draggedTodoModelID = todo.persistentModelID
            return NSItemProvider(object: todo.persistentModelID.hashValue.description as NSString)
        }
        .onDrop(of: [.text], delegate: TodayTodoDropDelegate(
            targetTodo: todo,
            sectionKey: sectionKey,
            orderedOverdue: $orderedOverdue,
            orderedToday: $orderedToday,
            draggedTodoModelID: $draggedTodoModelID,
            isDragging: $isDragging,
            modelContext: modelContext
        ))
        .id(todo.persistentModelID)
    }

    // MARK: - State

    private func syncState() {
        orderedOverdue = computedOverdue
        orderedToday = computedDueToday
    }

    private func toggleCollapse(_ key: String) {
        if collapsedSections.contains(key) {
            collapsedSections.remove(key)
        } else {
            collapsedSections.insert(key)
        }
    }
}

// MARK: - Drop Delegates

private struct TodayTodoDropDelegate: DropDelegate {
    let targetTodo: Todo
    let sectionKey: String
    @Binding var orderedOverdue: [Todo]
    @Binding var orderedToday: [Todo]
    @Binding var draggedTodoModelID: PersistentIdentifier?
    @Binding var isDragging: Bool
    let modelContext: ModelContext

    func dropEntered(info: DropInfo) {
        guard let draggedId = draggedTodoModelID,
              draggedId != targetTodo.persistentModelID else { return }

        isDragging = true

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            // Remove from both arrays
            let dragged = removeTodoFromArray(draggedId: draggedId, array: &orderedOverdue)
                ?? removeTodoFromArray(draggedId: draggedId, array: &orderedToday)
            guard let dragged else { return }

            // Insert into target section
            var targetArray = sectionKey == "overdue" ? orderedOverdue : orderedToday
            if let toIndex = targetArray.firstIndex(where: { $0.persistentModelID == targetTodo.persistentModelID }) {
                targetArray.insert(dragged, at: toIndex)
            } else {
                targetArray.append(dragged)
            }

            if sectionKey == "overdue" {
                orderedOverdue = targetArray
            } else {
                orderedToday = targetArray
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedId = draggedTodoModelID else { return false }

        // Find which section the todo ended up in
        let inToday = orderedToday.contains(where: { $0.persistentModelID == draggedId })
        let draggedTodo = orderedOverdue.first(where: { $0.persistentModelID == draggedId })
            ?? orderedToday.first(where: { $0.persistentModelID == draggedId })

        // If moved from overdue to today, update date
        if inToday, let todo = draggedTodo {
            let startOfToday = Calendar.current.startOfDay(for: Date())
            if let due = todo.dueDate, due < startOfToday {
                todo.dueDate = startOfToday
            }
            if let deadline = todo.deadlineDate, deadline < startOfToday {
                todo.deadlineDate = startOfToday
            }
        }

        // Persist sort orders
        for (i, todo) in orderedOverdue.enumerated() { todo.sortOrder = i }
        for (i, todo) in orderedToday.enumerated() { todo.sortOrder = i }
        try? modelContext.save()

        draggedTodoModelID = nil
        isDragging = false
        return true
    }
}

private struct TodaySectionDropDelegate: DropDelegate {
    let sectionKey: String
    @Binding var orderedOverdue: [Todo]
    @Binding var orderedToday: [Todo]
    @Binding var draggedTodoModelID: PersistentIdentifier?
    @Binding var isDragging: Bool
    @Binding var highlightedSection: String?
    let modelContext: ModelContext

    func dropEntered(info: DropInfo) {
        guard let draggedId = draggedTodoModelID else { return }
        isDragging = true
        highlightedSection = sectionKey

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let dragged = removeTodoFromArray(draggedId: draggedId, array: &orderedOverdue)
                ?? removeTodoFromArray(draggedId: draggedId, array: &orderedToday)
            guard let dragged else { return }

            // Append to target section
            if sectionKey == "today" {
                orderedToday.append(dragged)
            } else {
                orderedOverdue.append(dragged)
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        highlightedSection = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedId = draggedTodoModelID else { return false }
        highlightedSection = nil

        // If dropped on "today" section, update overdue dates
        if sectionKey == "today" {
            let startOfToday = Calendar.current.startOfDay(for: Date())
            if let todo = orderedToday.first(where: { $0.persistentModelID == draggedId }) {
                if let due = todo.dueDate, due < startOfToday {
                    todo.dueDate = startOfToday
                }
                if let deadline = todo.deadlineDate, deadline < startOfToday {
                    todo.deadlineDate = startOfToday
                }
            }
        }

        for (i, todo) in orderedOverdue.enumerated() { todo.sortOrder = i }
        for (i, todo) in orderedToday.enumerated() { todo.sortOrder = i }
        try? modelContext.save()

        draggedTodoModelID = nil
        isDragging = false
        return true
    }
}

//
//  TodayView.swift
//  Polaris
//
//  Displays all tasks with a due date or deadline on or before today.
//  Overdue tasks get their own section; today's tasks are grouped by project.
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

    @Query(sort: \Project.sortOrder) private var projects: [Project]

    @State private var orderedOverdue: [Todo] = []
    @State private var groupTodosMap: [String: [Todo]] = [:]
    @State private var orderedGroupIds: [String] = []
    @State private var draggedTodoModelID: PersistentIdentifier?
    @State private var draggedTodoModelIDs: Set<PersistentIdentifier> = []
    @State private var isDragging = false
    @State private var collapsedSections: Set<String> = []
    @State private var highlightedSection: String?
    @State private var newlyCreatedTodoID: PersistentIdentifier?

    // MARK: - Computed

    private var todayTodos: [Todo] {
        allTodos.filter(\.isToday)
    }

    private var startOfToday: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var computedOverdue: [Todo] {
        todayTodos.filter { todo in
            if let due = todo.dueDate, due < startOfToday { return true }
            if let deadline = todo.deadlineDate, deadline < startOfToday { return true }
            return false
        }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var computedDueToday: [Todo] {
        todayTodos.filter { todo in
            let dueIsPast = todo.dueDate.map { $0 < startOfToday } ?? false
            let deadlineIsPast = todo.deadlineDate.map { $0 < startOfToday } ?? false
            let dueIsToday = todo.dueDate.map { $0 >= startOfToday } ?? false
            let deadlineIsToday = todo.deadlineDate.map { $0 >= startOfToday } ?? false
            return !dueIsPast && !deadlineIsPast && (dueIsToday || deadlineIsToday)
        }
    }

    private struct ProjectGroup: Identifiable {
        let id: String
        let name: String
        let icon: String
        let color: Color
        let project: Project?
    }

    private var computedGroups: [ProjectGroup] {
        let dueTodayTodos = computedDueToday
        var groups: [ProjectGroup] = []

        let inbox = dueTodayTodos.filter { $0.project == nil }
        if !inbox.isEmpty {
            groups.append(ProjectGroup(id: "inbox", name: "Inbox", icon: "tray.fill", color: .blue, project: nil))
        }

        for project in projects {
            let todos = dueTodayTodos.filter { $0.project?.id == project.id }
            if !todos.isEmpty {
                groups.append(ProjectGroup(
                    id: project.id.uuidString,
                    name: project.name,
                    icon: project.icon,
                    color: Color.fromString(project.color),
                    project: project
                ))
            }
        }

        return groups
    }

    private func computedTodos(for groupId: String) -> [Todo] {
        let dueTodayTodos = computedDueToday
        if groupId == "inbox" {
            return dueTodayTodos.filter { $0.project == nil }.sorted { $0.sortOrder < $1.sortOrder }
        }
        return dueTodayTodos
            .filter { $0.project?.id.uuidString == groupId }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var allVisibleTodos: [Todo] {
        var result: [Todo] = []
        if !collapsedSections.contains("overdue") { result.append(contentsOf: orderedOverdue) }
        for groupId in orderedGroupIds {
            if !collapsedSections.contains(groupId) {
                result.append(contentsOf: groupTodosMap[groupId] ?? [])
            }
        }
        return result
    }

    // MARK: - Body

    var body: some View {
        TaskListContainer(
            title: "Today",
            icon: "star.fill",
            iconColor: .yellow,
            selectionStore: selectionStore,
            windowState: windowState,
            onToggleSidebar: onToggleSidebar,
            onToggleInspector: onToggleInspector,
            allTodos: allVisibleTodos,
            onAddTask: { addTask() },
            isDragging: $isDragging,
            draggedTodoModelID: $draggedTodoModelID,
            onPerformBackgroundDrop: { performBackgroundDrop() }
        ) { proxy in
            if orderedOverdue.isEmpty && groupTodosMap.values.allSatisfy(\.isEmpty) {
                emptyState
            } else {
                // Overdue section
                if !orderedOverdue.isEmpty {
                    TabSectionHeaderView(
                        title: "Overdue",
                        icon: "exclamationmark.circle.fill",
                        color: .red,
                        isCollapsed: collapsedSections.contains("overdue"),
                        onToggleCollapse: { toggleCollapse("overdue") },
                        isDropTarget: highlightedSection == "overdue"
                    )
                    .padding(.top, 8)
                    .onDrop(of: [.text], delegate: TodayOverdueSectionDropDelegate(
                        orderedOverdue: $orderedOverdue,
                        groupTodosMap: $groupTodosMap,
                        draggedTodoModelID: $draggedTodoModelID,
                        draggedTodoModelIDs: $draggedTodoModelIDs,
                        isDragging: $isDragging,
                        highlightedSection: $highlightedSection,
                        modelContext: modelContext
                    ))

                    if !collapsedSections.contains("overdue") {
                        ForEach(orderedOverdue) { todo in
                            overdueTaskRow(for: todo)
                        }

                        Color.clear
                            .frame(height: 8)
                            .contentShape(Rectangle())
                            .onDrop(of: [.text], delegate: TodayOverdueEndDropDelegate(
                                orderedOverdue: $orderedOverdue,
                                groupTodosMap: $groupTodosMap,
                                draggedTodoModelID: $draggedTodoModelID,
                                draggedTodoModelIDs: $draggedTodoModelIDs,
                                isDragging: $isDragging,
                                modelContext: modelContext
                            ))
                    }
                }

                // Project groups for today's tasks
                ForEach(computedGroups.filter { orderedGroupIds.contains($0.id) }) { group in
                    TabSectionHeaderView(
                        title: group.name,
                        icon: group.icon,
                        color: group.color,
                        isCollapsed: collapsedSections.contains(group.id),
                        onToggleCollapse: { toggleCollapse(group.id) },
                        isDropTarget: highlightedSection == group.id
                    )
                    .padding(.top, 8)
                    .onDrop(of: [.text], delegate: TodayGroupSectionDropDelegate(
                        targetGroupId: group.id,
                        targetProject: group.project,
                        orderedOverdue: $orderedOverdue,
                        groupTodosMap: $groupTodosMap,
                        draggedTodoModelID: $draggedTodoModelID,
                        draggedTodoModelIDs: $draggedTodoModelIDs,
                        isDragging: $isDragging,
                        highlightedSection: $highlightedSection,
                        modelContext: modelContext
                    ))

                    if !collapsedSections.contains(group.id) {
                        ForEach(groupTodosMap[group.id] ?? []) { todo in
                            groupTaskRow(for: todo, groupId: group.id, project: group.project)
                        }

                        Color.clear
                            .frame(height: 8)
                            .contentShape(Rectangle())
                            .onDrop(of: [.text], delegate: TodayGroupEndDropDelegate(
                                targetGroupId: group.id,
                                targetProject: group.project,
                                orderedOverdue: $orderedOverdue,
                                groupTodosMap: $groupTodosMap,
                                draggedTodoModelID: $draggedTodoModelID,
                                draggedTodoModelIDs: $draggedTodoModelIDs,
                                isDragging: $isDragging,
                                modelContext: modelContext
                            ))
                    }
                }
            }
        }
        .onAppear { syncState() }
        .onChange(of: allTodos.count) { old, new in
            guard !isDragging else { return }
            Log.data.debug("[TodayView] allTodos.count changed: \(old) → \(new) → syncState")
            syncState()
        }
        .onChange(of: allTodos.map(\.persistentModelID)) {
            guard !isDragging else { return }
            Log.data.debug("[TodayView] allTodos IDs changed → syncState (animated)")
            withAnimation(.easeInOut(duration: 0.35)) {
                syncState()
            }
        }
        .onChange(of: projects.count) { old, new in
            guard !isDragging else { return }
            Log.data.debug("[TodayView] projects.count changed: \(old) → \(new) → syncState")
            syncState()
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
            Image(systemName: "star")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("Nothing due today")
                .font(.appScaled(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Task Rows

    @ViewBuilder
    private func overdueTaskRow(for todo: Todo) -> some View {
        let isSelected = selectionStore.isSelected(todo)
        let isBeingDragged = draggedTodoModelIDs.contains(todo.persistentModelID)

        TaskRowView(
            todo: todo,
            isSelected: isSelected,
            selectionPosition: selectionStore.selectionPosition(of: todo, in: allVisibleTodos),
            startInEditMode: newlyCreatedTodoID == todo.persistentModelID,
            onSelect: { modifiers in
                if modifiers.contains(.shift) {
                    selectionStore.extendSelection(to: todo, in: allVisibleTodos)
                } else {
                    selectionStore.selectSingle(todo)
                    if windowState.isInspectorCollapsed {
                        onToggleInspector?()
                    }
                }
            },
            onEditModeStarted: { newlyCreatedTodoID = nil }
        )
        .opacity(isBeingDragged ? 0.35 : 1.0)
        .scaleEffect(isBeingDragged ? 0.95 : 1.0)
        .onDrag {
            isDragging = true
            if selectionStore.isSelected(todo) && selectionStore.selectedTodoIDs.count > 1 {
                draggedTodoModelIDs = selectionStore.selectedTodoIDs
            } else {
                selectionStore.selectSingle(todo)
                draggedTodoModelIDs = [todo.persistentModelID]
            }
            draggedTodoModelID = todo.persistentModelID
            return NSItemProvider(object: todo.persistentModelID.hashValue.description as NSString)
        }
        .onDrop(of: [.text], delegate: TodayOverdueTodoDropDelegate(
            targetTodo: todo,
            orderedOverdue: $orderedOverdue,
            groupTodosMap: $groupTodosMap,
            draggedTodoModelID: $draggedTodoModelID,
            draggedTodoModelIDs: $draggedTodoModelIDs,
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

    @ViewBuilder
    private func groupTaskRow(for todo: Todo, groupId: String, project: Project?) -> some View {
        let isSelected = selectionStore.isSelected(todo)
        let isBeingDragged = draggedTodoModelIDs.contains(todo.persistentModelID)

        TaskRowView(
            todo: todo,
            isSelected: isSelected,
            selectionPosition: selectionStore.selectionPosition(of: todo, in: allVisibleTodos),
            startInEditMode: newlyCreatedTodoID == todo.persistentModelID,
            onSelect: { modifiers in
                if modifiers.contains(.shift) {
                    selectionStore.extendSelection(to: todo, in: allVisibleTodos)
                } else {
                    selectionStore.selectSingle(todo)
                    if windowState.isInspectorCollapsed {
                        onToggleInspector?()
                    }
                }
            },
            onEditModeStarted: { newlyCreatedTodoID = nil }
        )
        .opacity(isBeingDragged ? 0.35 : 1.0)
        .scaleEffect(isBeingDragged ? 0.95 : 1.0)
        .onDrag {
            isDragging = true
            if selectionStore.isSelected(todo) && selectionStore.selectedTodoIDs.count > 1 {
                draggedTodoModelIDs = selectionStore.selectedTodoIDs
            } else {
                selectionStore.selectSingle(todo)
                draggedTodoModelIDs = [todo.persistentModelID]
            }
            draggedTodoModelID = todo.persistentModelID
            return NSItemProvider(object: todo.persistentModelID.hashValue.description as NSString)
        }
        .onDrop(of: [.text], delegate: TodayGroupTodoDropDelegate(
            targetTodo: todo,
            targetGroupId: groupId,
            targetProject: project,
            orderedOverdue: $orderedOverdue,
            groupTodosMap: $groupTodosMap,
            draggedTodoModelID: $draggedTodoModelID,
            draggedTodoModelIDs: $draggedTodoModelIDs,
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

    private func performBackgroundDrop() {
        for (i, todo) in orderedOverdue.enumerated() { todo.sortOrder = i }
        persistGroupSortOrders(groups: groupTodosMap, modelContext: modelContext)
    }

    // MARK: - State

    private func syncState() {
        orderedOverdue = computedOverdue
        let groups = computedGroups
        orderedGroupIds = groups.map(\.id)
        var map: [String: [Todo]] = [:]
        for group in groups {
            map[group.id] = computedTodos(for: group.id)
        }
        groupTodosMap = map
    }

    // MARK: - Actions

    private func addTask() {
        let today = Calendar.current.startOfDay(for: Date())
        let allCurrent = orderedOverdue + groupTodosMap.values.flatMap { $0 }
        let maxOrder = allCurrent.map(\.sortOrder).max() ?? -1
        let todo = Todo(title: "", sortOrder: maxOrder + 1)
        todo.dueDate = today
        modelContext.insert(todo)
        try? modelContext.save()
        Log.data.info("[TodayView] addTask – saved, ID: \(todo.persistentModelID.hashValue)")
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

    private func toggleCollapse(_ key: String) {
        if collapsedSections.contains(key) {
            collapsedSections.remove(key)
        } else {
            collapsedSections.insert(key)
        }
    }
}

// MARK: - Shared Helpers

/// Removes a todo from the overdue array OR grouped map, returning it.
private func removeTodoFromAll(
    draggedId: PersistentIdentifier,
    overdue: inout [Todo],
    groups: inout [String: [Todo]]
) -> Todo? {
    if let todo = removeTodoFromArray(draggedId: draggedId, array: &overdue) {
        return todo
    }
    return removeTodoFromGroups(draggedId: draggedId, groups: &groups)
}

private func removeTodosFromAll(
    draggedIds: Set<PersistentIdentifier>,
    overdue: inout [Todo],
    groups: inout [String: [Todo]]
) -> [Todo] {
    var removed = removeTodosFromArray(draggedIds: draggedIds, array: &overdue)
    removed.append(contentsOf: removeTodosFromGroups(draggedIds: draggedIds, groups: &groups))
    return removed
}

// MARK: - Drop Delegates (Overdue Section)

private struct TodayOverdueTodoDropDelegate: DropDelegate {
    let targetTodo: Todo
    @Binding var orderedOverdue: [Todo]
    @Binding var groupTodosMap: [String: [Todo]]
    @Binding var draggedTodoModelID: PersistentIdentifier?
    @Binding var draggedTodoModelIDs: Set<PersistentIdentifier>
    @Binding var isDragging: Bool
    let modelContext: ModelContext

    func dropEntered(info: DropInfo) {
        guard !draggedTodoModelIDs.isEmpty,
              !draggedTodoModelIDs.contains(targetTodo.persistentModelID) else { return }
        isDragging = true

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let dragged = removeTodosFromAll(draggedIds: draggedTodoModelIDs, overdue: &orderedOverdue, groups: &groupTodosMap)
            guard !dragged.isEmpty else { return }
            if let idx = orderedOverdue.firstIndex(where: { $0.persistentModelID == targetTodo.persistentModelID }) {
                orderedOverdue.insert(contentsOf: dragged, at: idx)
            } else {
                orderedOverdue.append(contentsOf: dragged)
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        for (i, todo) in orderedOverdue.enumerated() { todo.sortOrder = i }
        persistGroupSortOrders(groups: groupTodosMap, modelContext: modelContext)
        draggedTodoModelID = nil
        draggedTodoModelIDs.removeAll()
        isDragging = false
        return true
    }
}

private struct TodayOverdueSectionDropDelegate: DropDelegate {
    @Binding var orderedOverdue: [Todo]
    @Binding var groupTodosMap: [String: [Todo]]
    @Binding var draggedTodoModelID: PersistentIdentifier?
    @Binding var draggedTodoModelIDs: Set<PersistentIdentifier>
    @Binding var isDragging: Bool
    @Binding var highlightedSection: String?
    let modelContext: ModelContext

    func dropEntered(info: DropInfo) {
        guard !draggedTodoModelIDs.isEmpty else { return }
        isDragging = true
        highlightedSection = "overdue"

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let dragged = removeTodosFromAll(draggedIds: draggedTodoModelIDs, overdue: &orderedOverdue, groups: &groupTodosMap)
            orderedOverdue.append(contentsOf: dragged)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func dropExited(info: DropInfo) { highlightedSection = nil }

    func performDrop(info: DropInfo) -> Bool {
        highlightedSection = nil
        for (i, todo) in orderedOverdue.enumerated() { todo.sortOrder = i }
        persistGroupSortOrders(groups: groupTodosMap, modelContext: modelContext)
        draggedTodoModelID = nil
        draggedTodoModelIDs.removeAll()
        isDragging = false
        return true
    }
}

private struct TodayOverdueEndDropDelegate: DropDelegate {
    @Binding var orderedOverdue: [Todo]
    @Binding var groupTodosMap: [String: [Todo]]
    @Binding var draggedTodoModelID: PersistentIdentifier?
    @Binding var draggedTodoModelIDs: Set<PersistentIdentifier>
    @Binding var isDragging: Bool
    let modelContext: ModelContext

    func dropEntered(info: DropInfo) {
        guard !draggedTodoModelIDs.isEmpty else { return }
        isDragging = true

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let dragged = removeTodosFromAll(draggedIds: draggedTodoModelIDs, overdue: &orderedOverdue, groups: &groupTodosMap)
            orderedOverdue.append(contentsOf: dragged)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        for (i, todo) in orderedOverdue.enumerated() { todo.sortOrder = i }
        persistGroupSortOrders(groups: groupTodosMap, modelContext: modelContext)
        draggedTodoModelID = nil
        draggedTodoModelIDs.removeAll()
        isDragging = false
        return true
    }
}

// MARK: - Drop Delegates (Project Group Sections)

private struct TodayGroupTodoDropDelegate: DropDelegate {
    let targetTodo: Todo
    let targetGroupId: String
    let targetProject: Project?
    @Binding var orderedOverdue: [Todo]
    @Binding var groupTodosMap: [String: [Todo]]
    @Binding var draggedTodoModelID: PersistentIdentifier?
    @Binding var draggedTodoModelIDs: Set<PersistentIdentifier>
    @Binding var isDragging: Bool
    let modelContext: ModelContext

    func dropEntered(info: DropInfo) {
        guard !draggedTodoModelIDs.isEmpty,
              !draggedTodoModelIDs.contains(targetTodo.persistentModelID) else { return }
        isDragging = true

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let dragged = removeTodosFromAll(draggedIds: draggedTodoModelIDs, overdue: &orderedOverdue, groups: &groupTodosMap)
            guard !dragged.isEmpty else { return }
            var list = groupTodosMap[targetGroupId] ?? []
            if let idx = list.firstIndex(where: { $0.persistentModelID == targetTodo.persistentModelID }) {
                list.insert(contentsOf: dragged, at: idx)
            } else {
                list.append(contentsOf: dragged)
            }
            groupTodosMap[targetGroupId] = list
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        guard !draggedTodoModelIDs.isEmpty else { return false }

        // Update project + date for all dragged todos in target group
        let startOfToday = Calendar.current.startOfDay(for: Date())
        for todo in groupTodosMap[targetGroupId] ?? [] where draggedTodoModelIDs.contains(todo.persistentModelID) {
            todo.project = targetProject
            todo.section = nil
            if let due = todo.dueDate, due < startOfToday { todo.dueDate = startOfToday }
            if let deadline = todo.deadlineDate, deadline < startOfToday { todo.deadlineDate = startOfToday }
        }

        for (i, todo) in orderedOverdue.enumerated() { todo.sortOrder = i }
        persistGroupSortOrders(groups: groupTodosMap, modelContext: modelContext)
        draggedTodoModelID = nil
        draggedTodoModelIDs.removeAll()
        isDragging = false
        return true
    }
}

private struct TodayGroupSectionDropDelegate: DropDelegate {
    let targetGroupId: String
    let targetProject: Project?
    @Binding var orderedOverdue: [Todo]
    @Binding var groupTodosMap: [String: [Todo]]
    @Binding var draggedTodoModelID: PersistentIdentifier?
    @Binding var draggedTodoModelIDs: Set<PersistentIdentifier>
    @Binding var isDragging: Bool
    @Binding var highlightedSection: String?
    let modelContext: ModelContext

    func dropEntered(info: DropInfo) {
        guard !draggedTodoModelIDs.isEmpty else { return }
        isDragging = true
        highlightedSection = targetGroupId

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let dragged = removeTodosFromAll(draggedIds: draggedTodoModelIDs, overdue: &orderedOverdue, groups: &groupTodosMap)
            var list = groupTodosMap[targetGroupId] ?? []
            list.append(contentsOf: dragged)
            groupTodosMap[targetGroupId] = list
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func dropExited(info: DropInfo) { highlightedSection = nil }

    func performDrop(info: DropInfo) -> Bool {
        guard !draggedTodoModelIDs.isEmpty else { return false }
        highlightedSection = nil

        let startOfToday = Calendar.current.startOfDay(for: Date())
        for todo in groupTodosMap[targetGroupId] ?? [] where draggedTodoModelIDs.contains(todo.persistentModelID) {
            todo.project = targetProject
            todo.section = nil
            if let due = todo.dueDate, due < startOfToday { todo.dueDate = startOfToday }
            if let deadline = todo.deadlineDate, deadline < startOfToday { todo.deadlineDate = startOfToday }
        }

        for (i, todo) in orderedOverdue.enumerated() { todo.sortOrder = i }
        persistGroupSortOrders(groups: groupTodosMap, modelContext: modelContext)
        draggedTodoModelID = nil
        draggedTodoModelIDs.removeAll()
        isDragging = false
        return true
    }
}

private struct TodayGroupEndDropDelegate: DropDelegate {
    let targetGroupId: String
    let targetProject: Project?
    @Binding var orderedOverdue: [Todo]
    @Binding var groupTodosMap: [String: [Todo]]
    @Binding var draggedTodoModelID: PersistentIdentifier?
    @Binding var draggedTodoModelIDs: Set<PersistentIdentifier>
    @Binding var isDragging: Bool
    let modelContext: ModelContext

    func dropEntered(info: DropInfo) {
        guard !draggedTodoModelIDs.isEmpty else { return }
        isDragging = true

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let dragged = removeTodosFromAll(draggedIds: draggedTodoModelIDs, overdue: &orderedOverdue, groups: &groupTodosMap)
            var list = groupTodosMap[targetGroupId] ?? []
            list.append(contentsOf: dragged)
            groupTodosMap[targetGroupId] = list
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        guard !draggedTodoModelIDs.isEmpty else { return false }

        let startOfToday = Calendar.current.startOfDay(for: Date())
        for todo in groupTodosMap[targetGroupId] ?? [] where draggedTodoModelIDs.contains(todo.persistentModelID) {
            todo.project = targetProject
            todo.section = nil
            if let due = todo.dueDate, due < startOfToday { todo.dueDate = startOfToday }
            if let deadline = todo.deadlineDate, deadline < startOfToday { todo.deadlineDate = startOfToday }
        }

        for (i, todo) in orderedOverdue.enumerated() { todo.sortOrder = i }
        persistGroupSortOrders(groups: groupTodosMap, modelContext: modelContext)
        draggedTodoModelID = nil
        draggedTodoModelIDs.removeAll()
        isDragging = false
        return true
    }
}

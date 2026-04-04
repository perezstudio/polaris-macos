//
//  AllTasksView.swift
//  Polaris
//
//  Displays all uncompleted tasks grouped by project.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AllTasksView: View {
    let selectionStore: SelectionStore
    let windowState: WindowStateModel
    var onToggleSidebar: (() -> Void)?
    var onToggleInspector: (() -> Void)?

    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Todo> { !$0.isCompleted },
           sort: [SortDescriptor(\Todo.sortOrder)])
    private var allTodos: [Todo]

    @Query(sort: \Project.sortOrder) private var projects: [Project]

    @State private var groupTodosMap: [String: [Todo]] = [:]
    @State private var orderedGroupIds: [String] = []
    @State private var draggedTodoModelID: PersistentIdentifier?
    @State private var draggedTodoModelIDs: Set<PersistentIdentifier> = []
    @State private var isDragging = false
    @State private var highlightedGroupId: String?
    @State private var collapsedGroups: Set<String> = []
    @State private var newlyCreatedTodoID: PersistentIdentifier?

    // MARK: - Computed

    private struct ProjectGroup: Identifiable {
        let id: String
        let name: String
        let icon: String
        let color: Color
        let project: Project?
    }

    private var computedGroups: [ProjectGroup] {
        var groups: [ProjectGroup] = []

        let inbox = allTodos.filter { $0.project == nil }
        if !inbox.isEmpty {
            groups.append(ProjectGroup(id: "inbox", name: "Inbox", icon: "tray.fill", color: .blue, project: nil))
        }

        for project in projects {
            let todos = allTodos.filter { $0.project?.id == project.id }
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
        if groupId == "inbox" {
            return allTodos.filter { $0.project == nil }.sorted { $0.sortOrder < $1.sortOrder }
        }
        return allTodos
            .filter { $0.project?.id.uuidString == groupId }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var allVisibleTodos: [Todo] {
        orderedGroupIds.flatMap { groupId in
            collapsedGroups.contains(groupId) ? [] : (groupTodosMap[groupId] ?? [])
        }
    }

    // MARK: - Body

    var body: some View {
        TaskListContainer(
            title: "All Tasks",
            icon: "checklist",
            iconColor: .teal,
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
            if allVisibleTodos.isEmpty && groupTodosMap.isEmpty {
                emptyState
            } else {
                ForEach(computedGroups.filter { orderedGroupIds.contains($0.id) }) { group in
                    TabSectionHeaderView(
                        title: group.name,
                        icon: group.icon,
                        color: group.color,
                        isCollapsed: collapsedGroups.contains(group.id),
                        onToggleCollapse: { toggleCollapse(group.id) },
                        isDropTarget: highlightedGroupId == group.id
                    )
                    .padding(.top, 8)
                    .onDrop(of: [.text], delegate: AllTasksSectionDropDelegate(
                        targetGroupId: group.id,
                        targetProject: group.project,
                        groupTodosMap: $groupTodosMap,
                        draggedTodoModelID: $draggedTodoModelID,
                        draggedTodoModelIDs: $draggedTodoModelIDs,
                        isDragging: $isDragging,
                        highlightedGroupId: $highlightedGroupId,
                        modelContext: modelContext
                    ))

                    if !collapsedGroups.contains(group.id) {
                        ForEach(groupTodosMap[group.id] ?? []) { todo in
                            taskRow(for: todo, groupId: group.id, project: group.project)
                        }

                        // End-of-section drop target
                        Color.clear
                            .frame(height: 8)
                            .contentShape(Rectangle())
                            .onDrop(of: [.text], delegate: AllTasksEndOfSectionDropDelegate(
                                targetGroupId: group.id,
                                targetProject: group.project,
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
            Log.data.debug("[AllTasksView] allTodos.count changed: \(old) → \(new) → syncState")
            syncState()
        }
        .onChange(of: allTodos.map(\.persistentModelID)) {
            guard !isDragging else { return }
            Log.data.debug("[AllTasksView] allTodos IDs changed → syncState (animated)")
            withAnimation(.easeInOut(duration: 0.35)) {
                syncState()
            }
        }
        .onChange(of: projects.count) { old, new in
            guard !isDragging else { return }
            Log.data.debug("[AllTasksView] projects.count changed: \(old) → \(new) → syncState")
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
            Image(systemName: "checklist")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No tasks")
                .font(.appScaled(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func taskRow(for todo: Todo, groupId: String, project: Project?) -> some View {
        let isSelected = selectionStore.isSelected(todo)
        let isBeingDragged = draggedTodoModelIDs.contains(todo.persistentModelID)

        TaskRowView(
            todo: todo,
            isSelected: isSelected,
            isSecondarySelected: selectionStore.isSecondarySelected(todo),
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
            onEditModeStarted: { newlyCreatedTodoID = nil },
            onDeleteEmpty: {
                deleteTodo(todo)
            }
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
        .onDrop(of: [.text], delegate: AllTasksTodoDropDelegate(
            targetTodo: todo,
            targetGroupId: groupId,
            targetProject: project,
            groupTodosMap: $groupTodosMap,
            draggedTodoModelID: $draggedTodoModelID,
            draggedTodoModelIDs: $draggedTodoModelIDs,
            isDragging: $isDragging,
            modelContext: modelContext
        ))
        .rightClickMenu(selectionStore: selectionStore, todo: todo) {
            MenuItems.destructiveButton("Delete", systemImage: "trash") {
                deleteTodo(todo)
            }
        }
        .id(todo.persistentModelID)
    }

    private func performBackgroundDrop() {
        persistGroupSortOrders(groups: groupTodosMap, modelContext: modelContext)
    }

    // MARK: - State

    private func syncState() {
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
        let maxOrder = allTodos.map(\.sortOrder).max() ?? -1
        let todo = Todo(title: "", sortOrder: maxOrder + 1)
        modelContext.insert(todo)
        try? modelContext.save()
        Log.data.info("[AllTasksView] addTask – saved, ID: \(todo.persistentModelID.hashValue)")
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
        if collapsedGroups.contains(key) {
            collapsedGroups.remove(key)
        } else {
            collapsedGroups.insert(key)
        }
    }
}

// MARK: - Drop Delegates

private struct AllTasksTodoDropDelegate: DropDelegate {
    let targetTodo: Todo
    let targetGroupId: String
    let targetProject: Project?
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
            let dragged = removeTodosFromGroups(draggedIds: draggedTodoModelIDs, groups: &groupTodosMap)
            guard !dragged.isEmpty else { return }

            var list = groupTodosMap[targetGroupId] ?? []
            if let toIndex = list.firstIndex(where: { $0.persistentModelID == targetTodo.persistentModelID }) {
                list.insert(contentsOf: dragged, at: toIndex)
            } else {
                list.append(contentsOf: dragged)
            }
            groupTodosMap[targetGroupId] = list
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard !draggedTodoModelIDs.isEmpty else { return false }

        // Update project for all dragged todos in target group
        for todo in groupTodosMap[targetGroupId] ?? [] where draggedTodoModelIDs.contains(todo.persistentModelID) {
            if targetGroupId == "inbox" {
                todo.project = nil
            } else {
                todo.project = targetProject
            }
            todo.section = nil
        }

        persistGroupSortOrders(groups: groupTodosMap, modelContext: modelContext)

        draggedTodoModelID = nil
        draggedTodoModelIDs.removeAll()
        isDragging = false
        return true
    }
}

private struct AllTasksSectionDropDelegate: DropDelegate {
    let targetGroupId: String
    let targetProject: Project?
    @Binding var groupTodosMap: [String: [Todo]]
    @Binding var draggedTodoModelID: PersistentIdentifier?
    @Binding var draggedTodoModelIDs: Set<PersistentIdentifier>
    @Binding var isDragging: Bool
    @Binding var highlightedGroupId: String?
    let modelContext: ModelContext

    func dropEntered(info: DropInfo) {
        guard !draggedTodoModelIDs.isEmpty else { return }
        isDragging = true
        highlightedGroupId = targetGroupId

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let dragged = removeTodosFromGroups(draggedIds: draggedTodoModelIDs, groups: &groupTodosMap)
            var list = groupTodosMap[targetGroupId] ?? []
            list.append(contentsOf: dragged)
            groupTodosMap[targetGroupId] = list
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        highlightedGroupId = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard !draggedTodoModelIDs.isEmpty else { return false }
        highlightedGroupId = nil

        for todo in groupTodosMap[targetGroupId] ?? [] where draggedTodoModelIDs.contains(todo.persistentModelID) {
            if targetGroupId == "inbox" {
                todo.project = nil
            } else {
                todo.project = targetProject
            }
            todo.section = nil
        }

        persistGroupSortOrders(groups: groupTodosMap, modelContext: modelContext)

        draggedTodoModelID = nil
        draggedTodoModelIDs.removeAll()
        isDragging = false
        return true
    }
}

private struct AllTasksEndOfSectionDropDelegate: DropDelegate {
    let targetGroupId: String
    let targetProject: Project?
    @Binding var groupTodosMap: [String: [Todo]]
    @Binding var draggedTodoModelID: PersistentIdentifier?
    @Binding var draggedTodoModelIDs: Set<PersistentIdentifier>
    @Binding var isDragging: Bool
    let modelContext: ModelContext

    func dropEntered(info: DropInfo) {
        guard !draggedTodoModelIDs.isEmpty else { return }
        isDragging = true

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let dragged = removeTodosFromGroups(draggedIds: draggedTodoModelIDs, groups: &groupTodosMap)
            var list = groupTodosMap[targetGroupId] ?? []
            list.append(contentsOf: dragged)
            groupTodosMap[targetGroupId] = list
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard !draggedTodoModelIDs.isEmpty else { return false }

        for todo in groupTodosMap[targetGroupId] ?? [] where draggedTodoModelIDs.contains(todo.persistentModelID) {
            if targetGroupId == "inbox" {
                todo.project = nil
            } else {
                todo.project = targetProject
            }
            todo.section = nil
        }

        persistGroupSortOrders(groups: groupTodosMap, modelContext: modelContext)

        draggedTodoModelID = nil
        draggedTodoModelIDs.removeAll()
        isDragging = false
        return true
    }
}

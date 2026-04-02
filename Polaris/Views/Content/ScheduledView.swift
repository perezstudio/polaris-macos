//
//  ScheduledView.swift
//  Polaris
//
//  Displays upcoming tasks grouped by date: individual days (next 7),
//  remaining weeks of the month, remaining months of the year, and future years.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ScheduledView: View {
    let selectionStore: SelectionStore
    let windowState: WindowStateModel
    var onToggleSidebar: (() -> Void)?
    var onToggleInspector: (() -> Void)?

    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Todo> { !$0.isCompleted },
           sort: [SortDescriptor(\Todo.sortOrder)])
    private var allTodos: [Todo]

    @State private var bucketTodosMap: [String: [Todo]] = [:]
    @State private var orderedBucketMeta: [BucketMeta] = []
    @State private var draggedTodoModelID: PersistentIdentifier?
    @State private var draggedTodoModelIDs: Set<PersistentIdentifier> = []
    @State private var isDragging = false
    @State private var highlightedBucketId: String?
    @State private var collapsedBuckets: Set<String> = []
    @State private var newlyCreatedTodoID: PersistentIdentifier?

    private var scheduledTodos: [Todo] {
        allTodos.filter { $0.effectiveDate != nil }
    }

    // MARK: - Bucket Metadata (no todos, just structure)

    struct BucketMeta: Identifiable {
        let id: String
        let title: String
        let icon: String
        let iconColor: Color
        let startDate: Date
    }

    private var computedBuckets: [(meta: BucketMeta, todos: [Todo])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }

        var result: [(meta: BucketMeta, todos: [Todo])] = []

        // Individual days (tomorrow + 6 more)
        for offset in 0..<7 {
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: tomorrow),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            let dayNumber = calendar.component(.day, from: dayStart)
            let todos = todosInRange(start: dayStart, end: dayEnd)
            if !todos.isEmpty {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, MMM d"
                result.append((
                    meta: BucketMeta(
                        id: "day-\(offset)",
                        title: formatter.string(from: dayStart),
                        icon: "\(dayNumber).circle",
                        iconColor: .red,
                        startDate: dayStart
                    ),
                    todos: todos
                ))
            }
        }

        // Remaining weeks of current month
        guard let weekStart = calendar.date(byAdding: .day, value: 7, to: tomorrow) else { return result }
        let currentMonth = calendar.component(.month, from: today)
        let currentYear = calendar.component(.year, from: today)

        var cursor = weekStart
        let weekday = calendar.component(.weekday, from: cursor)
        let daysUntilMonday = (calendar.firstWeekday + 7 - weekday) % 7
        if daysUntilMonday > 0, let aligned = calendar.date(byAdding: .day, value: daysUntilMonday, to: cursor) {
            let eom = endOfMonth(for: today, calendar: calendar)
            let partialEnd = min(aligned, eom)
            if cursor < partialEnd {
                let todos = todosInRange(start: cursor, end: partialEnd)
                if !todos.isEmpty {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM d"
                    result.append((
                        meta: BucketMeta(
                            id: "week-partial",
                            title: "Week of \(formatter.string(from: cursor))",
                            icon: "calendar",
                            iconColor: .red,
                            startDate: cursor
                        ),
                        todos: todos
                    ))
                }
            }
            cursor = aligned
        }

        let endOfCurrentMonth = endOfMonth(for: today, calendar: calendar)
        var weekIndex = 0
        while cursor < endOfCurrentMonth {
            guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: cursor) else { break }
            let end = min(nextWeek, endOfCurrentMonth)
            let todos = todosInRange(start: cursor, end: end)
            if !todos.isEmpty {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                result.append((
                    meta: BucketMeta(
                        id: "week-\(weekIndex)",
                        title: "Week of \(formatter.string(from: cursor))",
                        icon: "calendar",
                        iconColor: .red,
                        startDate: cursor
                    ),
                    todos: todos
                ))
            }
            cursor = end
            weekIndex += 1
        }

        // Remaining months of current year
        let monthAfterCurrent = currentMonth + 1
        for month in monthAfterCurrent...12 {
            var components = DateComponents()
            components.year = currentYear
            components.month = month
            components.day = 1
            guard let monthStart = calendar.date(from: components) else { continue }
            let monthEnd = endOfMonth(for: monthStart, calendar: calendar)
            let todos = todosInRange(start: monthStart, end: monthEnd)
            if !todos.isEmpty {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                result.append((
                    meta: BucketMeta(
                        id: "month-\(month)",
                        title: formatter.string(from: monthStart),
                        icon: "calendar",
                        iconColor: .red,
                        startDate: monthStart
                    ),
                    todos: todos
                ))
            }
        }

        // Future years
        let futureYears = Set(scheduledTodos.compactMap { todo -> Int? in
            guard let date = todo.effectiveDate else { return nil }
            let year = calendar.component(.year, from: date)
            return year > currentYear ? year : nil
        }).sorted()

        for year in futureYears {
            var startComponents = DateComponents()
            startComponents.year = year
            startComponents.month = 1
            startComponents.day = 1
            var endComponents = DateComponents()
            endComponents.year = year + 1
            endComponents.month = 1
            endComponents.day = 1
            guard let yearStart = calendar.date(from: startComponents),
                  let yearEnd = calendar.date(from: endComponents) else { continue }
            let todos = todosInRange(start: yearStart, end: yearEnd)
            if !todos.isEmpty {
                result.append((
                    meta: BucketMeta(
                        id: "year-\(year)",
                        title: "\(year)",
                        icon: "calendar",
                        iconColor: .red,
                        startDate: yearStart
                    ),
                    todos: todos
                ))
            }
        }

        return result
    }

    private func todosInRange(start: Date, end: Date) -> [Todo] {
        scheduledTodos.filter { todo in
            guard let date = todo.effectiveDate else { return false }
            return date >= start && date < end
        }.sorted { ($0.effectiveDate ?? .distantFuture) < ($1.effectiveDate ?? .distantFuture) }
    }

    private func endOfMonth(for date: Date, calendar: Calendar) -> Date {
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let lastDay = calendar.date(byAdding: .day, value: range.count - calendar.component(.day, from: date), to: date) else {
            return date
        }
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: lastDay))!
    }

    private var allVisibleTodos: [Todo] {
        orderedBucketMeta.flatMap { meta in
            collapsedBuckets.contains(meta.id) ? [] : (bucketTodosMap[meta.id] ?? [])
        }
    }

    // MARK: - Body

    var body: some View {
        TaskListContainer(
            title: "Scheduled",
            icon: "calendar",
            iconColor: .red,
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
            if allVisibleTodos.isEmpty && bucketTodosMap.isEmpty {
                emptyState
            } else {
                ForEach(orderedBucketMeta) { meta in
                    TabSectionHeaderView(
                        title: meta.title,
                        icon: meta.icon,
                        color: meta.iconColor,
                        isCollapsed: collapsedBuckets.contains(meta.id),
                        onToggleCollapse: { toggleCollapse(meta.id) },
                        isDropTarget: highlightedBucketId == meta.id
                    )
                    .padding(.top, 8)
                    .onDrop(of: [.text], delegate: ScheduledSectionDropDelegate(
                        targetBucketId: meta.id,
                        targetDate: meta.startDate,
                        bucketTodosMap: $bucketTodosMap,
                        draggedTodoModelID: $draggedTodoModelID,
                        draggedTodoModelIDs: $draggedTodoModelIDs,
                        isDragging: $isDragging,
                        highlightedBucketId: $highlightedBucketId,
                        modelContext: modelContext
                    ))

                    if !collapsedBuckets.contains(meta.id) {
                        ForEach(bucketTodosMap[meta.id] ?? []) { todo in
                            taskRow(for: todo, bucketId: meta.id, bucketDate: meta.startDate)
                        }

                        // End-of-section drop target
                        Color.clear
                            .frame(height: 8)
                            .contentShape(Rectangle())
                            .onDrop(of: [.text], delegate: ScheduledEndOfSectionDropDelegate(
                                targetBucketId: meta.id,
                                targetDate: meta.startDate,
                                bucketTodosMap: $bucketTodosMap,
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
            Log.data.debug("[ScheduledView] allTodos.count changed: \(old) → \(new) → syncState")
            syncState()
        }
        .onChange(of: allTodos.map(\.persistentModelID)) {
            guard !isDragging else { return }
            Log.data.debug("[ScheduledView] allTodos IDs changed → syncState (animated)")
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
            Image(systemName: "calendar")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No scheduled tasks")
                .font(.appScaled(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func taskRow(for todo: Todo, bucketId: String, bucketDate: Date) -> some View {
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
        .onDrop(of: [.text], delegate: ScheduledTodoDropDelegate(
            targetTodo: todo,
            targetBucketId: bucketId,
            targetDate: bucketDate,
            bucketTodosMap: $bucketTodosMap,
            draggedTodoModelID: $draggedTodoModelID,
            draggedTodoModelIDs: $draggedTodoModelIDs,
            isDragging: $isDragging,
            modelContext: modelContext
        ))
        .rightClickMenu(selectionStore: selectionStore, todo: todo) {
            MenuItems.destructiveButton("Delete") {
                deleteTodo(todo)
            }
        }
        .id(todo.persistentModelID)
    }

    private func performBackgroundDrop() {
        persistGroupSortOrders(groups: bucketTodosMap, modelContext: modelContext)
    }

    // MARK: - State

    private func syncState() {
        let computed = computedBuckets
        orderedBucketMeta = computed.map(\.meta)
        var map: [String: [Todo]] = [:]
        for bucket in computed {
            map[bucket.meta.id] = bucket.todos
        }
        bucketTodosMap = map
    }

    // MARK: - Actions

    private func addTask() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
        let maxOrder = scheduledTodos.map(\.sortOrder).max() ?? -1
        let todo = Todo(title: "", sortOrder: maxOrder + 1)
        todo.dueDate = tomorrow
        modelContext.insert(todo)
        try? modelContext.save()
        Log.data.info("[ScheduledView] addTask – saved, ID: \(todo.persistentModelID.hashValue)")
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
        if collapsedBuckets.contains(key) {
            collapsedBuckets.remove(key)
        } else {
            collapsedBuckets.insert(key)
        }
    }
}

// MARK: - Date Update Helper

private func updateTodoDate(_ todo: Todo, to targetDate: Date) {
    if todo.dueDate != nil {
        todo.dueDate = targetDate
    } else if todo.deadlineDate != nil {
        todo.deadlineDate = targetDate
    }
}

// MARK: - Drop Delegates

private struct ScheduledTodoDropDelegate: DropDelegate {
    let targetTodo: Todo
    let targetBucketId: String
    let targetDate: Date
    @Binding var bucketTodosMap: [String: [Todo]]
    @Binding var draggedTodoModelID: PersistentIdentifier?
    @Binding var draggedTodoModelIDs: Set<PersistentIdentifier>
    @Binding var isDragging: Bool
    let modelContext: ModelContext

    func dropEntered(info: DropInfo) {
        guard !draggedTodoModelIDs.isEmpty,
              !draggedTodoModelIDs.contains(targetTodo.persistentModelID) else { return }

        isDragging = true

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let dragged = removeTodosFromGroups(draggedIds: draggedTodoModelIDs, groups: &bucketTodosMap)
            guard !dragged.isEmpty else { return }

            var list = bucketTodosMap[targetBucketId] ?? []
            if let toIndex = list.firstIndex(where: { $0.persistentModelID == targetTodo.persistentModelID }) {
                list.insert(contentsOf: dragged, at: toIndex)
            } else {
                list.append(contentsOf: dragged)
            }
            bucketTodosMap[targetBucketId] = list
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard !draggedTodoModelIDs.isEmpty else { return false }

        for todo in bucketTodosMap[targetBucketId] ?? [] where draggedTodoModelIDs.contains(todo.persistentModelID) {
            updateTodoDate(todo, to: targetDate)
        }

        persistGroupSortOrders(groups: bucketTodosMap, modelContext: modelContext)

        draggedTodoModelID = nil
        draggedTodoModelIDs.removeAll()
        isDragging = false
        return true
    }
}

private struct ScheduledSectionDropDelegate: DropDelegate {
    let targetBucketId: String
    let targetDate: Date
    @Binding var bucketTodosMap: [String: [Todo]]
    @Binding var draggedTodoModelID: PersistentIdentifier?
    @Binding var draggedTodoModelIDs: Set<PersistentIdentifier>
    @Binding var isDragging: Bool
    @Binding var highlightedBucketId: String?
    let modelContext: ModelContext

    func dropEntered(info: DropInfo) {
        guard !draggedTodoModelIDs.isEmpty else { return }
        isDragging = true
        highlightedBucketId = targetBucketId

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let dragged = removeTodosFromGroups(draggedIds: draggedTodoModelIDs, groups: &bucketTodosMap)
            var list = bucketTodosMap[targetBucketId] ?? []
            list.append(contentsOf: dragged)
            bucketTodosMap[targetBucketId] = list
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        highlightedBucketId = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard !draggedTodoModelIDs.isEmpty else { return false }
        highlightedBucketId = nil

        for todo in bucketTodosMap[targetBucketId] ?? [] where draggedTodoModelIDs.contains(todo.persistentModelID) {
            updateTodoDate(todo, to: targetDate)
        }

        persistGroupSortOrders(groups: bucketTodosMap, modelContext: modelContext)

        draggedTodoModelID = nil
        draggedTodoModelIDs.removeAll()
        isDragging = false
        return true
    }
}

private struct ScheduledEndOfSectionDropDelegate: DropDelegate {
    let targetBucketId: String
    let targetDate: Date
    @Binding var bucketTodosMap: [String: [Todo]]
    @Binding var draggedTodoModelID: PersistentIdentifier?
    @Binding var draggedTodoModelIDs: Set<PersistentIdentifier>
    @Binding var isDragging: Bool
    let modelContext: ModelContext

    func dropEntered(info: DropInfo) {
        guard !draggedTodoModelIDs.isEmpty else { return }
        isDragging = true

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let dragged = removeTodosFromGroups(draggedIds: draggedTodoModelIDs, groups: &bucketTodosMap)
            var list = bucketTodosMap[targetBucketId] ?? []
            list.append(contentsOf: dragged)
            bucketTodosMap[targetBucketId] = list
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard !draggedTodoModelIDs.isEmpty else { return false }

        for todo in bucketTodosMap[targetBucketId] ?? [] where draggedTodoModelIDs.contains(todo.persistentModelID) {
            updateTodoDate(todo, to: targetDate)
        }

        persistGroupSortOrders(groups: bucketTodosMap, modelContext: modelContext)

        draggedTodoModelID = nil
        draggedTodoModelIDs.removeAll()
        isDragging = false
        return true
    }
}

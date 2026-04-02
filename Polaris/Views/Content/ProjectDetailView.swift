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
    @Query(sort: \Project.sortOrder) private var allProjects: [Project]
    @FocusState private var isListFocused: Bool
    @State private var draggedTodoModelID: PersistentIdentifier?
    @State private var draggedTodoModelIDs: Set<PersistentIdentifier> = []
    @State private var draggedSectionId: PersistentIdentifier?
    @State private var collapsedForDrag: Set<PersistentIdentifier> = []
    @State private var orderedUnsectionedTodos: [Todo] = []
    @State private var orderedSections: [Section] = []
    @State private var sectionTodosMap: [PersistentIdentifier: [Todo]] = [:]
    @State private var newlyCreatedTodoID: PersistentIdentifier?
    @State private var newlyCreatedSectionID: PersistentIdentifier?
    @State private var isEditingInline = false
    @State private var isDragging = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var movingSectionSheet: Section?
    @State private var editingProject: Project?
    @State private var showDeleteConfirmation = false

    // MARK: - Computed

    private var sortedUnsectionedTodos: [Todo] {
        project.todos.filter { $0.section == nil }.sorted { a, b in
            if a.isCompleted != b.isCompleted { return !a.isCompleted }
            return a.sortOrder < b.sortOrder
        }
    }

    private var sortedSections: [Section] {
        project.sections.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func sortedTodos(for section: Section) -> [Todo] {
        section.todos.sorted { a, b in
            if a.isCompleted != b.isCompleted { return !a.isCompleted }
            return a.sortOrder < b.sortOrder
        }
    }

    /// Flat list of all visible todos for keyboard navigation
    private var allVisibleTodos: [Todo] {
        var result = orderedUnsectionedTodos
        for section in orderedSections {
            if !section.isCollapsed && !collapsedForDrag.contains(section.persistentModelID) {
                result.append(contentsOf: sectionTodosMap[section.persistentModelID] ?? sortedTodos(for: section))
            }
        }
        return result
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
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .focusable()
        .focused($isListFocused)
        .focusEffectDisabled()
        .onPreferenceChange(InlineEditingKey.self) { editing in
            Log.editing.debug("[ProjectDetailView] isEditingInline changed: \(editing)")
            isEditingInline = editing
            if editing {
                isListFocused = false
                Log.focus.debug("[ProjectDetailView] yielded focus for inline editing")
            } else {
                DispatchQueue.main.async {
                    // Don't steal focus from AppKit text views (e.g. notes editor in inspector)
                    if let firstResponder = NSApp.keyWindow?.firstResponder,
                       firstResponder is NSTextView {
                        Log.focus.debug("[ProjectDetailView] skipped focus reclaim – NSTextView is first responder")
                        return
                    }
                    isListFocused = true
                    Log.focus.debug("[ProjectDetailView] reclaimed focus after inline editing")
                }
            }
        }
        .onAppear { isListFocused = true }
        .onKeyPress(.upArrow) {
            guard !isEditingInline else {
                Log.shortcut.debug("[ProjectDetailView] ↑ ignored (editing inline)")
                return .ignored
            }
            let isShift = NSApp.currentEvent?.modifierFlags.contains(.shift) == true
            if isShift {
                navigateSelectionExtending(direction: -1)
            } else {
                navigateSelection(direction: -1)
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            guard !isEditingInline else {
                Log.shortcut.debug("[ProjectDetailView] ↓ ignored (editing inline)")
                return .ignored
            }
            let isShift = NSApp.currentEvent?.modifierFlags.contains(.shift) == true
            if isShift {
                navigateSelectionExtending(direction: 1)
            } else {
                navigateSelection(direction: 1)
            }
            return .handled
        }
        .onKeyPress(.return) {
            guard !isEditingInline else {
                Log.shortcut.debug("[ProjectDetailView] ↩ ignored (editing inline)")
                return .ignored
            }
            if let todo = selectionStore.selectedTodo {
                expandInspector(for: todo)
            }
            return .handled
        }
        .onKeyPress(.escape) {
            guard !isEditingInline else {
                Log.shortcut.debug("[ProjectDetailView] ⎋ ignored (editing inline)")
                return .ignored
            }
            deselectTask()
            return .handled
        }
        .onChange(of: selectionStore.addTaskRequested) { _, requested in
            if requested {
                selectionStore.addTaskRequested = false
                addTodoContextAware()
            }
        }
        .onChange(of: selectionStore.addSectionRequested) { _, requested in
            if requested {
                selectionStore.addSectionRequested = false
                addSectionContextAware()
            }
        }
        .sheet(item: $movingSectionSheet) { section in
            MoveSectionSheet(
                section: section,
                projects: allProjects.filter { $0.id != project.id },
                onMove: { targetProject in
                    moveSection(section, to: targetProject)
                }
            )
        }
        .sheet(item: $editingProject) { project in
            ProjectEditSheet(project: project)
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            DeleteConfirmationDialog(
                icon: project.icon,
                iconColor: Color.fromString(project.color),
                title: "Delete \"\(project.name)\"?",
                message: "This project and all its tasks will be permanently deleted. This action cannot be undone.",
                onDelete: {
                    showDeleteConfirmation = false
                    deleteProject()
                },
                onCancel: {
                    showDeleteConfirmation = false
                }
            )
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
                addTodoContextAware()
            } label: {
                Image(systemName: "plus")
                    .font(.appScaled(size: 14))
            }
            .buttonStyle(.polarisHover(size: .large))

            Button {
                addSectionContextAware()
            } label: {
                Image(systemName: "plus.diamond")
                    .font(.appScaled(size: 14))
            }
            .buttonStyle(.polarisHover(size: .large))

            NSMenuButton(systemImage: "ellipsis", imageSize: 14) {
                MenuItems.button("Edit Project...", systemImage: "pencil") { editingProject = project }
                MenuItems.divider()
                MenuItems.destructiveButton("Remove Project", systemImage: "trash") { showDeleteConfirmation = true }
            }
            .frame(width: 28, height: 28)

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
        .padding(.leading, windowState.isSidebarCollapsed ? 68 : 0)
        .frame(height: 52)
        .onDrop(of: [.text], delegate: BackgroundDropDelegate(
            orderedUnsectionedTodos: $orderedUnsectionedTodos,
            sectionTodosMap: $sectionTodosMap,
            draggedTodoModelID: $draggedTodoModelID,
            draggedTodoModelIDs: $draggedTodoModelIDs,
            draggedSectionId: $draggedSectionId,
            orderedSections: $orderedSections,
            collapsedForDrag: $collapsedForDrag,
            isDragging: $isDragging,
            modelContext: modelContext
        ))
    }

    // MARK: - Task List

    @ViewBuilder
    private var taskList: some View {
        if project.todos.isEmpty && project.sections.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "checklist")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
                Text("No tasks yet")
                    .font(.appScaled(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                Button("Add Task") {
                    addTodo(toSection: nil)
                }
                .controlSize(.small)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Unsectioned tasks
                        ForEach(orderedUnsectionedTodos) { todo in
                            taskRow(for: todo, inSection: nil)
                        }

                        // Drop target at end of unsectioned list
                        if !orderedUnsectionedTodos.isEmpty || !draggedTodoModelIDs.isEmpty {
                            Color.clear
                                .frame(height: 8)
                                .contentShape(Rectangle())
                                .onDrop(of: [.text], delegate: EndOfListDropDelegate(
                                    targetSection: nil,
                                    orderedUnsectionedTodos: $orderedUnsectionedTodos,
                                    sectionTodosMap: $sectionTodosMap,
                                    draggedTodoModelID: $draggedTodoModelID,
                                    draggedTodoModelIDs: $draggedTodoModelIDs,
                                    draggedSectionId: $draggedSectionId,
                                    orderedSections: $orderedSections,
                                    collapsedForDrag: $collapsedForDrag,
                                    isDragging: $isDragging,
                                    modelContext: modelContext
                                ))
                        }

                        // Sections
                        ForEach(orderedSections) { section in
                            sectionGroup(for: section)
                        }
                    }
                    .frame(maxWidth: 800)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 68)
                    .padding(.bottom, 24)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                    .background {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { deselectTask() }
                    }
                    .onDrop(of: [.text], delegate: BackgroundDropDelegate(
                        orderedUnsectionedTodos: $orderedUnsectionedTodos,
                        sectionTodosMap: $sectionTodosMap,
                        draggedTodoModelID: $draggedTodoModelID,
                        draggedTodoModelIDs: $draggedTodoModelIDs,
                        draggedSectionId: $draggedSectionId,
                        orderedSections: $orderedSections,
                        collapsedForDrag: $collapsedForDrag,
                        isDragging: $isDragging,
                        modelContext: modelContext
                    ))
                }
                .onAppear { scrollProxy = proxy }
                }
                .overlay {
                    if isDragging {
                        DragAutoScrollOverlay(
                            isDragging: $isDragging,
                            draggedTodoModelID: $draggedTodoModelID,
                            draggedSectionId: $draggedSectionId,
                            collapsedForDrag: $collapsedForDrag
                        )

                    }
                }

            }
            .onAppear { syncAllState() }
            .onChange(of: project.todos.count) {
                guard !isDragging else { return }
                syncAllState()
            }
            .onChange(of: project.sections.count) {
                guard !isDragging else { return }
                syncAllState()
            }
            .onChange(of: project.todos.map(\.persistentModelID)) {
                guard !isDragging else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    syncAllState()
                }
            }
            .onChange(of: project.sections.map(\.persistentModelID)) {
                guard !isDragging else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    syncAllState()
                }
            }
        }
    }

    // MARK: - Section Group

    @ViewBuilder
    private func sectionGroup(for section: Section) -> some View {
        let isSectionDragged = draggedSectionId == section.persistentModelID
        let isDragCollapsed = collapsedForDrag.contains(section.persistentModelID)
        let todos = sectionTodosMap[section.persistentModelID] ?? []

        VStack(spacing: 0) {
            SectionHeaderView(
                section: section,
                isBeingDragged: isSectionDragged,
                startInEditMode: newlyCreatedSectionID == section.persistentModelID,
                onAddTask: { addTodo(toSection: section) },
                onDeleteKeepTasks: { deleteSection(section, keepTasks: true) },
                onDeleteWithTasks: { deleteSection(section, keepTasks: false) },
                onMoveToProject: { movingSectionSheet = section },
                onConvertToProject: { convertSectionToProject(section) },
                onEditModeStarted: { newlyCreatedSectionID = nil },
                onEditingChanged: { editing in
                    isEditingInline = editing
                    if !editing { reclaimFocusIfAppropriate() }
                }
            )
            .padding(.top, 8)
            .opacity(isSectionDragged ? 0.35 : 1.0)
            .scaleEffect(isSectionDragged ? 0.95 : 1.0)
            .onDrag {
                isDragging = true
                let _ = withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    collapsedForDrag.insert(section.persistentModelID)
                }
                draggedSectionId = section.persistentModelID
                return NSItemProvider(object: section.id.uuidString as NSString)
            }
            .onDrop(of: [.text], delegate: SectionHeaderDropDelegate(
                targetSection: section,
                orderedSections: $orderedSections,
                draggedSectionId: $draggedSectionId,
                draggedTodoModelID: $draggedTodoModelID,
                draggedTodoModelIDs: $draggedTodoModelIDs,
                orderedUnsectionedTodos: $orderedUnsectionedTodos,
                sectionTodosMap: $sectionTodosMap,
                collapsedForDrag: $collapsedForDrag,
                isDragging: $isDragging,
                modelContext: modelContext
            ))

            // Section tasks (hidden when collapsed or drag-collapsed)
            if !section.isCollapsed && !isDragCollapsed {
                ForEach(todos) { todo in
                    taskRow(for: todo, inSection: section)
                }

                // Drop target at end of section
                Color.clear
                    .frame(height: 8)
                    .contentShape(Rectangle())
                    .onDrop(of: [.text], delegate: EndOfListDropDelegate(
                        targetSection: section,
                        orderedUnsectionedTodos: $orderedUnsectionedTodos,
                        sectionTodosMap: $sectionTodosMap,
                        draggedTodoModelID: $draggedTodoModelID,
                        draggedTodoModelIDs: $draggedTodoModelIDs,
                        draggedSectionId: $draggedSectionId,
                        orderedSections: $orderedSections,
                        collapsedForDrag: $collapsedForDrag,
                        isDragging: $isDragging,
                        modelContext: modelContext
                    ))
            }
        }
    }

    // MARK: - Task Row

    @ViewBuilder
    private func taskRow(for todo: Todo, inSection section: Section?) -> some View {
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
                    expandInspector(for: todo)
                }
                isListFocused = true
            },
            onEditModeStarted: {
                newlyCreatedTodoID = nil
            },
            onEditingChanged: { editing in
                isEditingInline = editing
                if !editing { reclaimFocusIfAppropriate() }
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
        .onDrop(of: [.text], delegate: TodoDropDelegate(
            targetTodo: todo,
            targetSection: section,
            orderedUnsectionedTodos: $orderedUnsectionedTodos,
            sectionTodosMap: $sectionTodosMap,
            draggedTodoModelID: $draggedTodoModelID,
            draggedTodoModelIDs: $draggedTodoModelIDs,
            draggedSectionId: $draggedSectionId,
            orderedSections: $orderedSections,
            collapsedForDrag: $collapsedForDrag,
            isDragging: $isDragging,
            modelContext: modelContext
        ))
        .rightClickMenu(selectionStore: selectionStore, todo: todo) {
            if section != nil {
                MenuItems.button("Remove from Section", systemImage: "rectangle.lefthalf.inset.filled.arrow.left") {
                    todo.section = nil
                    try? modelContext.save()
                    syncAllState()
                }
                MenuItems.divider()
            }
            MenuItems.destructiveButton("Delete", systemImage: "trash") {
                deleteTodo(todo)
            }
        }
        .id(todo.persistentModelID)
    }

    // MARK: - Keyboard Navigation

    private func navigateSelection(direction: Int) {
        let todos = allVisibleTodos
        guard !todos.isEmpty else { return }

        guard let current = selectionStore.selectedTodo,
              let currentIndex = todos.firstIndex(where: { $0.persistentModelID == current.persistentModelID }) else {
            if let first = todos.first {
                selectionStore.selectSingle(first)
                expandInspector(for: first)
                scrollToTodo(first)
            }
            return
        }

        let newIndex = currentIndex + direction
        guard newIndex >= 0 && newIndex < todos.count else { return }
        let todo = todos[newIndex]
        selectionStore.selectSingle(todo)
        expandInspector(for: todo)
        scrollToTodo(todo)
    }

    private func navigateSelectionExtending(direction: Int) {
        let todos = allVisibleTodos
        guard !todos.isEmpty else { return }

        guard let current = selectionStore.selectedTodo,
              let currentIndex = todos.firstIndex(where: { $0.persistentModelID == current.persistentModelID }) else {
            if let first = todos.first {
                selectionStore.selectSingle(first)
                scrollToTodo(first)
            }
            return
        }

        let newIndex = currentIndex + direction
        guard newIndex >= 0 && newIndex < todos.count else { return }
        let todo = todos[newIndex]
        selectionStore.extendSelectionStep(to: todo)
        scrollToTodo(todo)
    }

    private func scrollToTodo(_ todo: Todo) {
        withAnimation(.easeInOut(duration: 0.2)) {
            scrollProxy?.scrollTo(todo.persistentModelID, anchor: .center)
        }
    }

    private func expandInspector(for todo: Todo) {
        selectionStore.selectedTodo = todo
        if windowState.isInspectorCollapsed {
            onToggleInspector?()
        }
    }

    private func deselectTask() {
        selectionStore.clearSelection()
        if !windowState.isInspectorCollapsed {
            onToggleInspector?()
        }
        isListFocused = true
    }

    /// Reclaim list focus only if no AppKit text view currently has focus
    /// (e.g. the notes editor or a TextField in the inspector).
    private func reclaimFocusIfAppropriate() {
        if let firstResponder = NSApp.keyWindow?.firstResponder,
           firstResponder is NSTextView {
            return
        }
        isListFocused = true
    }

    // MARK: - State Sync

    private func syncAllState() {
        orderedUnsectionedTodos = sortedUnsectionedTodos
        orderedSections = sortedSections
        var map: [PersistentIdentifier: [Todo]] = [:]
        for section in orderedSections {
            map[section.persistentModelID] = sortedTodos(for: section)
        }
        sectionTodosMap = map
    }

    // MARK: - Actions

    private func addTodoContextAware() {
        if selectionStore.selectedTodo != nil {
            // Find the last selected todo by position in the visible list
            let visibleTodos = allVisibleTodos
            let lastSelected = visibleTodos.last(where: { selectionStore.selectedTodoIDs.contains($0.persistentModelID) }) ?? selectionStore.selectedTodo!

            // Insert below the last selected task, in the same section
            let section = lastSelected.section
            let todosInGroup: [Todo]
            if let section {
                todosInGroup = sectionTodosMap[section.persistentModelID] ?? sortedTodos(for: section)
            } else {
                todosInGroup = orderedUnsectionedTodos
            }

            let selectedIndex = todosInGroup.firstIndex(where: { $0.persistentModelID == lastSelected.persistentModelID }) ?? (todosInGroup.count - 1)
            let insertSortOrder = selectedIndex + 1

            // Shift tasks below
            for todo in todosInGroup where todo.sortOrder >= insertSortOrder {
                todo.sortOrder += 1
            }

            let todo = Todo(title: "", sortOrder: insertSortOrder)
            todo.project = project
            todo.section = section
            modelContext.insert(todo)
            try? modelContext.save()
            Log.data.info("[ProjectDetailView] addTodoContextAware – saved, ID: \(todo.persistentModelID.hashValue)")
            selectionStore.selectSingle(todo)
            newlyCreatedTodoID = todo.persistentModelID
            expandInspector(for: todo)
        } else {
            // No selection: add to bottom of unsectioned tasks
            addTodo(toSection: nil)
        }
    }

    private func addTodo(toSection section: Section?) {
        let todosInGroup: [Todo]
        if let section {
            todosInGroup = section.todos
        } else {
            todosInGroup = project.todos.filter { $0.section == nil }
        }
        let todo = Todo(title: "", sortOrder: todosInGroup.count)
        todo.project = project
        todo.section = section
        modelContext.insert(todo)
        try? modelContext.save()
        Log.data.info("[ProjectDetailView] addTodo(toSection:) – saved, ID: \(todo.persistentModelID.hashValue)")
        selectionStore.selectedTodo = todo
        newlyCreatedTodoID = todo.persistentModelID
        expandInspector(for: todo)
    }

    private func deleteTodo(_ todo: Todo) {
        if selectionStore.selectedTodo?.persistentModelID == todo.persistentModelID {
            selectionStore.selectedTodo = nil
        }
        modelContext.delete(todo)
    }

    private func addSectionContextAware() {
        let insertSortOrder: Int

        if let selectedTodo = selectionStore.selectedTodo {
            if let currentSection = selectedTodo.section {
                // Selected task is in a section → insert below that section
                let currentIndex = orderedSections.firstIndex(where: { $0.persistentModelID == currentSection.persistentModelID }) ?? (orderedSections.count - 1)
                insertSortOrder = currentIndex + 1
            } else {
                // Selected task is unsectioned → insert at the top (index 0)
                insertSortOrder = 0
            }
        } else {
            // No selection → add at the bottom
            insertSortOrder = project.sections.count
        }

        // Shift sections at or below the insertion point
        for section in project.sections where section.sortOrder >= insertSortOrder {
            section.sortOrder += 1
        }

        let section = Section(name: "", sortOrder: insertSortOrder)
        section.project = project
        modelContext.insert(section)
        try? modelContext.save()
        newlyCreatedSectionID = section.persistentModelID
        isListFocused = false
        syncAllState()
    }

    private func deleteSection(_ section: Section, keepTasks: Bool) {
        if keepTasks {
            for todo in section.todos {
                todo.section = nil
            }
        }
        modelContext.delete(section)
        try? modelContext.save()
        syncAllState()
    }

    private func moveSection(_ section: Section, to targetProject: Project) {
        for todo in section.todos {
            todo.project = targetProject
        }
        section.project = targetProject
        try? modelContext.save()
        syncAllState()
    }

    private func deleteProject() {
        selectionStore.selectedTodo = nil
        selectionStore.selectedProject = nil
        modelContext.delete(project)
        try? modelContext.save()
    }

    private func convertSectionToProject(_ section: Section) {
        let newProject = Project(
            name: section.name,
            icon: "folder.fill",
            color: section.color,
            sortOrder: allProjects.count
        )
        modelContext.insert(newProject)

        for todo in section.todos {
            todo.project = newProject
            todo.section = nil
        }
        modelContext.delete(section)
        try? modelContext.save()

        selectionStore.selectedProject = newProject
        selectionStore.selectedTodo = nil
    }
}

// MARK: - Move Section Sheet

private struct MoveSectionSheet: View {
    let section: Section
    let projects: [Project]
    let onMove: (Project) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.right.doc.on.clipboard")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("Move \"\(section.name)\" to...")
                .font(.headline)

            if projects.isEmpty {
                Text("No other projects available.")
                    .foregroundStyle(.secondary)
                    .font(.appScaled(size: 13))
            } else {
                VStack(spacing: 2) {
                    ForEach(projects) { project in
                        Button {
                            onMove(project)
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: project.icon)
                                    .foregroundStyle(Color.fromString(project.color))
                                Text(project.name)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
            }

            Button("Cancel") { dismiss() }
                .controlSize(.small)
        }
        .padding(24)
        .frame(width: 300)
    }
}

// MARK: - Drop Delegate Helpers

/// Removes a todo by ID from ALL UI arrays (unsectioned + every section).
/// Returns the removed Todo, or nil if not found.
private func removeTodoFromAllArrays(
    draggedId: PersistentIdentifier,
    unsectioned: inout [Todo],
    sectionMap: inout [PersistentIdentifier: [Todo]]
) -> Todo? {
    // Check unsectioned
    if let idx = unsectioned.firstIndex(where: { $0.persistentModelID == draggedId }) {
        return unsectioned.remove(at: idx)
    }
    // Check each section
    for key in sectionMap.keys {
        if let idx = sectionMap[key]?.firstIndex(where: { $0.persistentModelID == draggedId }) {
            return sectionMap[key]?.remove(at: idx)
        }
    }
    return nil
}

/// Removes multiple todos by ID from ALL UI arrays, preserving relative order.
/// Returns the removed todos in their original order.
private func removeTodosFromAllArrays(
    draggedIds: Set<PersistentIdentifier>,
    unsectioned: inout [Todo],
    sectionMap: inout [PersistentIdentifier: [Todo]]
) -> [Todo] {
    var removed: [Todo] = []
    unsectioned.removeAll { todo in
        if draggedIds.contains(todo.persistentModelID) {
            removed.append(todo)
            return true
        }
        return false
    }
    for key in sectionMap.keys {
        sectionMap[key]?.removeAll { todo in
            if draggedIds.contains(todo.persistentModelID) {
                removed.append(todo)
                return true
            }
            return false
        }
    }
    return removed
}

/// Persists sortOrder for all UI arrays and saves.
private func persistAllSortOrders(
    unsectioned: [Todo],
    sectionMap: [PersistentIdentifier: [Todo]],
    targetSection: Section?,
    draggedTodo: Todo?,
    modelContext: ModelContext
) {
    // Update section assignment
    if let dragged = draggedTodo {
        dragged.section = targetSection
    }

    for (i, todo) in unsectioned.enumerated() {
        todo.sortOrder = i
    }
    for (_, todos) in sectionMap {
        for (i, todo) in todos.enumerated() {
            todo.sortOrder = i
        }
    }
    try? modelContext.save()
}

/// Persists sortOrder for all UI arrays and assigns section for multiple dragged todos.
private func persistAllSortOrdersMulti(
    unsectioned: [Todo],
    sectionMap: [PersistentIdentifier: [Todo]],
    targetSection: Section?,
    draggedTodos: [Todo],
    modelContext: ModelContext
) {
    for dragged in draggedTodos {
        dragged.section = targetSection
    }

    for (i, todo) in unsectioned.enumerated() {
        todo.sortOrder = i
    }
    for (_, todos) in sectionMap {
        for (i, todo) in todos.enumerated() {
            todo.sortOrder = i
        }
    }
    try? modelContext.save()
}

// MARK: - Drop Delegates

private struct TodoDropDelegate: DropDelegate {
    let targetTodo: Todo
    let targetSection: Section?
    @Binding var orderedUnsectionedTodos: [Todo]
    @Binding var sectionTodosMap: [PersistentIdentifier: [Todo]]
    @Binding var draggedTodoModelID: PersistentIdentifier?
    @Binding var draggedTodoModelIDs: Set<PersistentIdentifier>
    @Binding var draggedSectionId: PersistentIdentifier?
    @Binding var orderedSections: [Section]
    @Binding var collapsedForDrag: Set<PersistentIdentifier>
    @Binding var isDragging: Bool
    let modelContext: ModelContext

    func dropEntered(info: DropInfo) {
        guard !draggedTodoModelIDs.isEmpty,
              !draggedTodoModelIDs.contains(targetTodo.persistentModelID) else { return }

        isDragging = true

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let dragged = removeTodosFromAllArrays(
                draggedIds: draggedTodoModelIDs,
                unsectioned: &orderedUnsectionedTodos,
                sectionMap: &sectionTodosMap
            )
            guard !dragged.isEmpty else { return }

            // Insert at target position
            if let tgtSectionId = targetSection?.persistentModelID {
                var list = sectionTodosMap[tgtSectionId] ?? []
                if let toIndex = list.firstIndex(where: { $0.persistentModelID == targetTodo.persistentModelID }) {
                    list.insert(contentsOf: dragged, at: toIndex)
                } else {
                    list.append(contentsOf: dragged)
                }
                sectionTodosMap[tgtSectionId] = list
            } else {
                if let toIndex = orderedUnsectionedTodos.firstIndex(where: { $0.persistentModelID == targetTodo.persistentModelID }) {
                    orderedUnsectionedTodos.insert(contentsOf: dragged, at: toIndex)
                } else {
                    orderedUnsectionedTodos.append(contentsOf: dragged)
                }
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        // Handle section drop that landed on a task row
        if draggedSectionId != nil {
            for (i, section) in orderedSections.enumerated() {
                section.sortOrder = i
            }
            try? modelContext.save()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                collapsedForDrag.removeAll()
            }
            draggedSectionId = nil
            isDragging = false
            return true
        }

        guard !draggedTodoModelIDs.isEmpty else { return false }

        let allTodos = orderedUnsectionedTodos + sectionTodosMap.values.flatMap({ $0 })
        let draggedTodos = allTodos.filter { draggedTodoModelIDs.contains($0.persistentModelID) }

        persistAllSortOrdersMulti(
            unsectioned: orderedUnsectionedTodos,
            sectionMap: sectionTodosMap,
            targetSection: targetSection,
            draggedTodos: draggedTodos,
            modelContext: modelContext
        )
        draggedTodoModelID = nil
        draggedTodoModelIDs.removeAll()
        isDragging = false
        return true
    }
}

private struct SectionHeaderDropDelegate: DropDelegate {
    let targetSection: Section
    @Binding var orderedSections: [Section]
    @Binding var draggedSectionId: PersistentIdentifier?
    @Binding var draggedTodoModelID: PersistentIdentifier?
    @Binding var draggedTodoModelIDs: Set<PersistentIdentifier>
    @Binding var orderedUnsectionedTodos: [Todo]
    @Binding var sectionTodosMap: [PersistentIdentifier: [Todo]]
    @Binding var collapsedForDrag: Set<PersistentIdentifier>
    @Binding var isDragging: Bool
    let modelContext: ModelContext

    func dropEntered(info: DropInfo) {
        isDragging = true

        // Section reordering
        if let draggedId = draggedSectionId,
           draggedId != targetSection.persistentModelID,
           let fromIndex = orderedSections.firstIndex(where: { $0.persistentModelID == draggedId }),
           let toIndex = orderedSections.firstIndex(where: { $0.persistentModelID == targetSection.persistentModelID }) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                orderedSections.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
            return
        }

        // Tasks dropped onto section header → add to end of section
        if !draggedTodoModelIDs.isEmpty {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                let dragged = removeTodosFromAllArrays(
                    draggedIds: draggedTodoModelIDs,
                    unsectioned: &orderedUnsectionedTodos,
                    sectionMap: &sectionTodosMap
                )
                guard !dragged.isEmpty else { return }

                var list = sectionTodosMap[targetSection.persistentModelID] ?? []
                list.append(contentsOf: dragged)
                sectionTodosMap[targetSection.persistentModelID] = list
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        // Section drop
        if draggedSectionId != nil {
            for (i, section) in orderedSections.enumerated() {
                section.sortOrder = i
            }
            try? modelContext.save()

            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                collapsedForDrag.removeAll()
            }
            draggedSectionId = nil
            isDragging = false
            return true
        }

        // Task drop onto section
        if !draggedTodoModelIDs.isEmpty {
            let allTodos = orderedUnsectionedTodos + sectionTodosMap.values.flatMap({ $0 })
            let draggedTodos = allTodos.filter { draggedTodoModelIDs.contains($0.persistentModelID) }

            persistAllSortOrdersMulti(
                unsectioned: orderedUnsectionedTodos,
                sectionMap: sectionTodosMap,
                targetSection: targetSection,
                draggedTodos: draggedTodos,
                modelContext: modelContext
            )
            draggedTodoModelID = nil
            draggedTodoModelIDs.removeAll()
            isDragging = false
            return true
        }

        return false
    }
}

private struct EndOfListDropDelegate: DropDelegate {
    let targetSection: Section?
    @Binding var orderedUnsectionedTodos: [Todo]
    @Binding var sectionTodosMap: [PersistentIdentifier: [Todo]]
    @Binding var draggedTodoModelID: PersistentIdentifier?
    @Binding var draggedTodoModelIDs: Set<PersistentIdentifier>
    @Binding var draggedSectionId: PersistentIdentifier?
    @Binding var orderedSections: [Section]
    @Binding var collapsedForDrag: Set<PersistentIdentifier>
    @Binding var isDragging: Bool
    let modelContext: ModelContext

    func dropEntered(info: DropInfo) {
        guard !draggedTodoModelIDs.isEmpty else { return }
        isDragging = true

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let dragged = removeTodosFromAllArrays(
                draggedIds: draggedTodoModelIDs,
                unsectioned: &orderedUnsectionedTodos,
                sectionMap: &sectionTodosMap
            )
            guard !dragged.isEmpty else { return }

            // Append to end of target group
            if let tgtSectionId = targetSection?.persistentModelID {
                var list = sectionTodosMap[tgtSectionId] ?? []
                list.append(contentsOf: dragged)
                sectionTodosMap[tgtSectionId] = list
            } else {
                orderedUnsectionedTodos.append(contentsOf: dragged)
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        // Handle section drop
        if draggedSectionId != nil {
            for (i, section) in orderedSections.enumerated() {
                section.sortOrder = i
            }
            try? modelContext.save()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                collapsedForDrag.removeAll()
            }
            draggedSectionId = nil
            isDragging = false
            return true
        }

        guard !draggedTodoModelIDs.isEmpty else { return false }

        let allTodos = orderedUnsectionedTodos + sectionTodosMap.values.flatMap({ $0 })
        let draggedTodos = allTodos.filter { draggedTodoModelIDs.contains($0.persistentModelID) }

        persistAllSortOrdersMulti(
            unsectioned: orderedUnsectionedTodos,
            sectionMap: sectionTodosMap,
            targetSection: targetSection,
            draggedTodos: draggedTodos,
            modelContext: modelContext
        )
        draggedTodoModelID = nil
        draggedTodoModelIDs.removeAll()
        isDragging = false
        return true
    }
}

private struct BackgroundDropDelegate: DropDelegate {
    @Binding var orderedUnsectionedTodos: [Todo]
    @Binding var sectionTodosMap: [PersistentIdentifier: [Todo]]
    @Binding var draggedTodoModelID: PersistentIdentifier?
    @Binding var draggedTodoModelIDs: Set<PersistentIdentifier>
    @Binding var draggedSectionId: PersistentIdentifier?
    @Binding var orderedSections: [Section]
    @Binding var collapsedForDrag: Set<PersistentIdentifier>
    @Binding var isDragging: Bool
    let modelContext: ModelContext

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        // Section drop on background
        if draggedSectionId != nil {
            for (i, section) in orderedSections.enumerated() {
                section.sortOrder = i
            }
            try? modelContext.save()

            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                collapsedForDrag.removeAll()
            }
            draggedSectionId = nil
            isDragging = false
            return true
        }

        // Task drop on background → unsection them
        if !draggedTodoModelIDs.isEmpty {
            let allTodos = orderedUnsectionedTodos + sectionTodosMap.values.flatMap({ $0 })
            let draggedTodos = allTodos.filter { draggedTodoModelIDs.contains($0.persistentModelID) }

            persistAllSortOrdersMulti(
                unsectioned: orderedUnsectionedTodos,
                sectionMap: sectionTodosMap,
                targetSection: nil,
                draggedTodos: draggedTodos,
                modelContext: modelContext
            )
            draggedTodoModelID = nil
            draggedTodoModelIDs.removeAll()
            isDragging = false
            return true
        }

        return false
    }
}


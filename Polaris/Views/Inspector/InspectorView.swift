//
//  InspectorView.swift
//  Polaris
//
//  Right-panel inspector for editing the selected task's details.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct InspectorView: View {
    let selectionStore: SelectionStore
    var onToggleInspector: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Query private var allTags: [Tag]

    @State private var tagSearchText = ""

    private var todo: Todo? { selectionStore.selectedTodo }

    var body: some View {
        ZStack(alignment: .top) {
            if let todo {
                inspectorContent(for: todo)
            } else {
                emptyState
            }

            VStack(spacing: 0) {
                inspectorToolbar
                    .background(VisualEffectBackground(material: .headerView, blendingMode: .withinWindow))
                Divider()
            }
            .zIndex(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Toolbar

    private var inspectorToolbar: some View {
        HStack(spacing: 4) {
            Button {
                onToggleInspector?()
            } label: {
                Image(systemName: "sidebar.trailing")
                    .font(.appScaled(size: 14))
            }
            .buttonStyle(.polarisHover(size: .large))

            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(height: 52)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "sidebar.trailing")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("Select a task")
                .font(.appScaled(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Inspector Content

    private func inspectorContent(for todo: Todo) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                titleSection(for: todo)
                fieldsSection(for: todo)
                checklistSection(for: todo)
                notesSection(for: todo)
            }
            .padding(.horizontal, 12)
            .padding(.top, 60)
            .padding(.bottom, 16)
        }
    }

    private func inspectorCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private func sectionLabel(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.appScaled(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(title)
                .font(.appScaled(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Title

    private func titleSection(for todo: Todo) -> some View {
        inspectorCard {
            HStack(spacing: 8) {
                Button {
                    todo.isCompleted.toggle()
                } label: {
                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(todo.isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)

                TextField("Task title", text: Binding(
                    get: { todo.title },
                    set: { todo.title = $0 }
                ))
                .textFieldStyle(.plain)
                .font(.appScaled(size: 16, weight: .semibold))
            }
        }
    }

    // MARK: - Fields

    private func fieldsSection(for todo: Todo) -> some View {
        inspectorCard {
            sectionLabel(icon: "slider.horizontal.3", title: "Properties")
                .padding(.bottom, 10)

            VStack(spacing: 12) {
                fieldRow(icon: "folder.fill", label: "Project") {
                    Picker("", selection: Binding(
                        get: { todo.project?.id },
                        set: { newId in
                            todo.project = projects.first(where: { $0.id == newId })
                        }
                    )) {
                        Text("None").tag(nil as UUID?)
                        ForEach(projects) { project in
                            Label {
                                Text(project.name)
                            } icon: {
                                Image(systemName: project.icon)
                            }
                            .tag(project.id as UUID?)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }

                fieldRow(icon: "flag.fill", label: "Priority") {
                    Picker("", selection: Binding(
                        get: { todo.priority },
                        set: { todo.priority = $0 }
                    )) {
                        ForEach(Priority.allCases, id: \.self) { priority in
                            Text(priority.label).tag(priority)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }

                fieldRow(icon: "calendar", label: "Due Date") {
                    dateField(date: Binding(
                        get: { todo.dueDate },
                        set: { todo.dueDate = $0 }
                    ))
                }

                fieldRow(icon: "clock.badge.exclamationmark", label: "Deadline") {
                    dateField(date: Binding(
                        get: { todo.deadlineDate },
                        set: { todo.deadlineDate = $0 }
                    ))
                }

                fieldRow(icon: "tag.fill", label: "Tags") {
                    tagsField(for: todo)
                }
            }
        }
    }

    private func fieldRow<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.appScaled(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                Text(label)
                    .font(.appScaled(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: 90)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Date Field

    private func dateField(date: Binding<Date?>) -> some View {
        HStack {
            if let d = date.wrappedValue {
                DatePicker("", selection: Binding(
                    get: { d },
                    set: { date.wrappedValue = $0 }
                ), displayedComponents: .date)
                .labelsHidden()
                .controlSize(.small)

                Button {
                    date.wrappedValue = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.appScaled(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            } else {
                Button("Set Date") {
                    date.wrappedValue = Date()
                }
                .controlSize(.small)
            }
        }
    }

    // MARK: - Tags

    private var availableTags: [Tag] {
        guard let todo else { return [] }
        guard !tagSearchText.isEmpty else { return [] }
        let assignedIds = Set(todo.tags.map(\.persistentModelID))
        return allTags
            .filter { !assignedIds.contains($0.persistentModelID) }
            .filter { $0.name.localizedCaseInsensitiveContains(tagSearchText) }
    }

    private var canCreateTag: Bool {
        let trimmed = tagSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return !allTags.contains(where: { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame })
    }

    private func tagsField(for todo: Todo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !todo.tags.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(todo.tags.sorted(by: { $0.name < $1.name })) { tag in
                        HStack(spacing: 3) {
                            Text(tag.name)
                                .font(.appScaled(size: 11))
                            Button {
                                todo.tags.removeAll(where: { $0.persistentModelID == tag.persistentModelID })
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.fromString(tag.color).opacity(0.2)))
                        .foregroundStyle(Color.fromString(tag.color))
                    }
                }
            }

            TextField("Search or create tag...", text: $tagSearchText)
                .textFieldStyle(.roundedBorder)
                .font(.appScaled(size: 12))
                .onSubmit {
                    if canCreateTag {
                        createAndAssignTag(to: todo)
                    } else if let first = availableTags.first {
                        assignTag(first, to: todo)
                    }
                }

            if !availableTags.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(availableTags.prefix(5)) { tag in
                        Button { assignTag(tag, to: todo) } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.fromString(tag.color))
                                    .frame(width: 8, height: 8)
                                Text(tag.name)
                                    .font(.appScaled(size: 12))
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
            }

            if canCreateTag {
                Button { createAndAssignTag(to: todo) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.appScaled(size: 12))
                        Text("Create \"\(tagSearchText.trimmingCharacters(in: .whitespacesAndNewlines))\"")
                            .font(.appScaled(size: 12))
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func assignTag(_ tag: Tag, to todo: Todo) {
        tag.todos.append(todo)
        try? modelContext.save()
        tagSearchText = ""
    }

    private func createAndAssignTag(to todo: Todo) {
        let name = tagSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let tag = Tag(name: name, color: ProjectColor.random.rawValue)
        modelContext.insert(tag)
        try? modelContext.save()
        tag.project = todo.project
        tag.todos.append(todo)
        try? modelContext.save()
        tagSearchText = ""
    }

    // MARK: - Notes

    private func notesSection(for todo: Todo) -> some View {
        inspectorCard {
            sectionLabel(icon: "note.text", title: "Notes")
                .padding(.bottom, 10)

            LiveMarkdownEditor(
                text: Binding(
                    get: { todo.note },
                    set: { todo.note = $0 }
                ),
                baseFontSize: 13,
                growsVertically: true,
                placeholder: "Add my details here…",
                compactInsets: true
            )
            .frame(minHeight: 40)
        }
    }

    // MARK: - Checklist

    @State private var focusedChecklistItemId: PersistentIdentifier?
    @State private var orderedChecklistItems: [ChecklistItem] = []
    @State private var draggedChecklistItemId: PersistentIdentifier?

    private func checklistSection(for todo: Todo) -> some View {
        inspectorCard {
            sectionLabel(icon: "checklist", title: "Checklist")
                .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(orderedChecklistItems) { item in
                    let isBeingDragged = item.persistentModelID == draggedChecklistItemId

                    ChecklistItemRow(
                        item: item,
                        isFocused: focusedChecklistItemId == item.persistentModelID,
                        onRequestFocus: { focusedChecklistItemId = item.persistentModelID },
                        onEnter: {
                            let currentSort = item.sortOrder
                            let itemsToShift = todo.checklistItems.filter {
                                $0.persistentModelID != item.persistentModelID && $0.sortOrder > currentSort
                            }
                            for other in itemsToShift {
                                other.sortOrder += 1
                            }
                            let newItem = ChecklistItem(title: "", sortOrder: currentSort + 1)
                            newItem.todo = todo
                            modelContext.insert(newItem)
                            try? modelContext.save()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                syncChecklistOrder(for: todo)
                                focusedChecklistItemId = newItem.persistentModelID
                            }
                        },
                        onDeleteEmpty: {
                            let prev = orderedChecklistItems.last(where: { $0.sortOrder < item.sortOrder })
                            let prevId = prev?.persistentModelID
                            modelContext.delete(item)
                            try? modelContext.save()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                syncChecklistOrder(for: todo)
                                focusedChecklistItemId = prevId
                            }
                        }
                    )
                    .opacity(isBeingDragged ? 0.35 : 1.0)
                    .scaleEffect(isBeingDragged ? 0.95 : 1.0)
                    .onDrag {
                        draggedChecklistItemId = item.persistentModelID
                        return NSItemProvider(object: "\(item.sortOrder)" as NSString)
                    }
                    .onDrop(of: [.text], delegate: ChecklistDropDelegate(
                        targetItemId: item.persistentModelID,
                        orderedItems: $orderedChecklistItems,
                        draggedItemId: $draggedChecklistItemId,
                        modelContext: modelContext
                    ))
                }

                Button {
                    let item = ChecklistItem(title: "", sortOrder: todo.checklistItems.count)
                    item.todo = todo
                    modelContext.insert(item)
                    try? modelContext.save()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        syncChecklistOrder(for: todo)
                        focusedChecklistItemId = item.persistentModelID
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.appScaled(size: 13))
                        Text("Add Item")
                            .font(.appScaled(size: 13))
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear { syncChecklistOrder(for: todo) }
        .onChange(of: todo.checklistItems.count) { _, _ in syncChecklistOrder(for: todo) }
    }

    private func syncChecklistOrder(for todo: Todo) {
        let sorted = todo.checklistItems.sorted { $0.sortOrder < $1.sortOrder }
        if orderedChecklistItems.map(\.persistentModelID) != sorted.map(\.persistentModelID) {
            orderedChecklistItems = sorted
        }
    }
}

// MARK: - Checklist Item Row

private struct ChecklistItemRow: View {
    @Bindable var item: ChecklistItem
    let isFocused: Bool
    var onRequestFocus: (() -> Void)?
    var onEnter: (() -> Void)?
    var onDeleteEmpty: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            // Drag handle — visible on hover
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.tertiary)
                .frame(width: 14)
                .opacity(isHovered ? 1 : 0)

            Button {
                item.isCompleted.toggle()
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.appScaled(size: 14))
                    .foregroundStyle(item.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            ChecklistTextField(
                text: $item.title,
                isFocused: isFocused,
                cursorAtEnd: isFocused,
                isCompleted: item.isCompleted,
                onEnter: { onEnter?() },
                onDeleteEmpty: { onDeleteEmpty?() },
                onFocus: { onRequestFocus?() }
            )
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

// MARK: - Checklist TextField (AppKit)

private struct ChecklistTextField: NSViewRepresentable {
    @Binding var text: String
    let isFocused: Bool
    let cursorAtEnd: Bool
    let isCompleted: Bool
    var onEnter: (() -> Void)?
    var onDeleteEmpty: (() -> Void)?
    var onFocus: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> ChecklistNSTextField {
        let textField = ChecklistNSTextField()
        textField.stringValue = text
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = NSFont.systemFont(ofSize: AppSettings.shared.scaledSize(13))
        textField.lineBreakMode = .byTruncatingTail
        textField.cell?.truncatesLastVisibleLine = true
        textField.placeholderString = "Checklist item"
        updateStrikethrough(textField)
        return textField
    }

    func updateNSView(_ textField: ChecklistNSTextField, context: Context) {
        if textField.stringValue != text && !context.coordinator.isEditing {
            textField.stringValue = text
        }
        updateStrikethrough(textField)

        if isFocused && textField.window?.firstResponder !== textField.currentEditor() {
            DispatchQueue.main.async {
                textField.window?.makeFirstResponder(textField)
                if cursorAtEnd, let editor = textField.currentEditor() {
                    editor.selectedRange = NSRange(location: textField.stringValue.count, length: 0)
                }
            }
        }
    }

    private func updateStrikethrough(_ textField: NSTextField) {
        textField.textColor = isCompleted ? .secondaryLabelColor : .labelColor
        if let cell = textField.cell as? NSTextFieldCell {
            let attrs: [NSAttributedString.Key: Any] = [
                .strikethroughStyle: isCompleted ? NSUnderlineStyle.single.rawValue : 0,
                .font: textField.font ?? NSFont.systemFont(ofSize: 13),
                .foregroundColor: isCompleted ? NSColor.secondaryLabelColor : NSColor.labelColor
            ]
            cell.attributedStringValue = NSAttributedString(string: textField.stringValue, attributes: attrs)
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: ChecklistTextField
        var isEditing = false

        init(_ parent: ChecklistTextField) {
            self.parent = parent
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            parent.onFocus?()
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            isEditing = true
            parent.text = textField.stringValue
            isEditing = false
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onEnter?()
                return true
            }
            if commandSelector == #selector(NSResponder.deleteBackward(_:)) {
                if textView.string.isEmpty {
                    parent.onDeleteEmpty?()
                    return true
                }
            }
            return false
        }
    }
}

private final class ChecklistNSTextField: NSTextField {
    // Key interception now handled by delegate's control(_:textView:doCommandBy:)
}

// MARK: - Checklist Drop Delegate

private struct ChecklistDropDelegate: DropDelegate {
    let targetItemId: PersistentIdentifier
    @Binding var orderedItems: [ChecklistItem]
    @Binding var draggedItemId: PersistentIdentifier?
    let modelContext: ModelContext

    func dropEntered(info: DropInfo) {
        guard let draggedId = draggedItemId,
              draggedId != targetItemId,
              let fromIndex = orderedItems.firstIndex(where: { $0.persistentModelID == draggedId }),
              let toIndex = orderedItems.firstIndex(where: { $0.persistentModelID == targetItemId }) else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            orderedItems.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        for (i, item) in orderedItems.enumerated() {
            item.sortOrder = i
        }
        try? modelContext.save()
        draggedItemId = nil
        return true
    }
}

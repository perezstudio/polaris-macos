//
//  TaskCardView.swift
//  Polaris
//
//  Unified task row / expanded card. Animates between compact and open states.
//  Checkbox + title persist; card content fades in after expansion.
//

import SwiftUI
import SwiftData

struct TaskCardView: View {
    @Bindable var todo: Todo
    let isOpen: Bool
    let isSelected: Bool
    let isCardOpenGlobally: Bool
    var onSelect: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    var onClose: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Query private var allTags: [Tag]

    @FocusState private var isTitleFocused: Bool
    @State private var expandedField: FieldKind?
    @State private var showCardContent = false
    @State private var isHovered = false

    private enum FieldKind: Hashable {
        case status, priority, dueDate, deadline, tags, checklist, project
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row — always visible, morphs between row and card header
            headerRow

            // Card content — fades in after expansion
            if isOpen && showCardContent {
                cardContent
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, isOpen ? 20 : 8)
        .padding(.vertical, isOpen ? 16 : 6)
        .frame(maxWidth: isOpen ? 900 : 800)
        .background(
            RoundedRectangle(cornerRadius: isOpen ? 10 : 6)
                .fill(
                    isOpen
                        ? Color(nsColor: .controlBackgroundColor)
                        : isSelected
                            ? Color.accentColor.opacity(0.15)
                            : isHovered
                                ? Color.primary.opacity(0.04)
                                : Color.clear
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: isOpen ? 10 : 6))
        .overlay(
            RoundedRectangle(cornerRadius: isOpen ? 10 : 6)
                .strokeBorder(Color.primary.opacity(isOpen ? 0.08 : 0), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isOpen ? 0.08 : 0), radius: 2, y: 1)
        .shadow(color: .black.opacity(isOpen ? 0.12 : 0), radius: 16, y: 8)
        .shadow(color: .black.opacity(isOpen ? 0.06 : 0), radius: 32, y: 16)
        .padding(.vertical, isOpen ? 40 : 0)
        .opacity(!isOpen && isCardOpenGlobally ? 0.4 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if !isOpen { onDoubleClick?() }
        }
        .onTapGesture(count: 1) {
            if !isOpen { onSelect?() }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            if !isOpen {
                Button("Delete", role: .destructive) {
                    // Handled by parent via deleteTodo
                }
            }
        }
        .onChange(of: isOpen) { _, newValue in
            if newValue {
                // Fade in card content after expansion starts
                withAnimation(.easeInOut(duration: 0.2).delay(0.12)) {
                    showCardContent = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    isTitleFocused = true
                }
            } else {
                // Immediately hide card content before collapse
                showCardContent = false
                expandedField = nil
            }
        }
    }

    // MARK: - Header Row (persists across both states)

    private var headerRow: some View {
        HStack(spacing: isOpen ? 10 : 8) {
            // Checkbox — single Image, no Button wrapper to preserve identity
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: isOpen ? 22 : 16))
                .foregroundStyle(todo.isCompleted ? .green : .secondary)
                .frame(width: isOpen ? 22 : 16, height: isOpen ? 22 : 16)
                .contentShape(Rectangle())
                .highPriorityGesture(TapGesture().onEnded {
                    todo.isCompleted.toggle()
                })

            // Title — Text when closed (non-interactive), TextField when open
            ZStack(alignment: .leading) {
                // Visible text layer when closed — matches TextField appearance
                Text(todo.title.isEmpty ? "Untitled" : todo.title)
                    .font(.appScaled(size: isOpen ? 18 : 13, weight: isOpen ? .semibold : .regular))
                    .foregroundStyle(todo.isCompleted && !isOpen ? .secondary : .primary)
                    .strikethrough(todo.isCompleted && !isOpen)
                    .lineLimit(isOpen ? nil : 1)
                    .opacity(isOpen ? 0 : 1)

                // Editable TextField — only interactive when open
                TextField("Task title", text: $todo.title)
                    .textFieldStyle(.plain)
                    .font(.appScaled(size: isOpen ? 18 : 13, weight: isOpen ? .semibold : .regular))
                    .lineLimit(isOpen ? nil : 1)
                    .focused($isTitleFocused)
                    .opacity(isOpen ? 1 : 0)
                    .allowsHitTesting(isOpen)
            }

            Spacer()

            // Row metadata — visible only when closed
            if !isOpen {
                rowMetadata
                    .transition(.opacity)
            }

            // Close button — visible only when open
            if isOpen {
                Button {
                    onClose?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.appScaled(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
    }

    // MARK: - Row Metadata (closed state)

    private var rowMetadata: some View {
        HStack(spacing: 6) {
            if let dueDate = todo.dueDate {
                Text(dueDate, style: .date)
                    .font(.appScaled(size: 11))
                    .foregroundStyle(isPastDue(dueDate) ? .red : .secondary)
            }

            ForEach(todo.tags) { tag in
                Text(tag.name)
                    .font(.appScaled(size: 10))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.fromString(tag.color).opacity(0.2))
                    )
                    .foregroundStyle(Color.fromString(tag.color))
            }

            if todo.priority != .low {
                Image(systemName: priorityIcon)
                    .font(.appScaled(size: 11))
                    .foregroundStyle(Color.fromString(todo.priority.color))
            }
        }
    }

    private var priorityIcon: String {
        switch todo.priority {
        case .none: "minus"
        case .low: "arrow.down"
        case .medium: "minus"
        case .high: "arrow.up"
        case .urgent: "exclamationmark.2"
        }
    }

    // MARK: - Card Content (fades in after expansion)

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Description
            LiveMarkdownEditor(
                text: $todo.note,
                baseFontSize: 13,
                growsVertically: true
            )
            .frame(minHeight: 60)
            .padding(.top, 8)
            .padding(.bottom, 12)

            Divider()

            // Field icon row with badges
            fieldRow
                .padding(.vertical, 10)

            // Expanded field editor (if any)
            if let field = expandedField {
                Divider()

                expandedFieldEditor(for: field)
                    .padding(.vertical, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Field Row

    private var fieldRow: some View {
        HStack(spacing: 6) {
            fieldBadge(
                icon: "folder.fill",
                iconColor: todo.project.map { Color.fromString($0.color) } ?? .secondary,
                label: todo.project?.name,
                field: .project
            )

            fieldBadge(
                icon: "flag.fill",
                iconColor: todo.priority != .low ? Color.fromString(todo.priority.color) : .secondary,
                label: todo.priority != .low ? todo.priority.label : nil,
                field: .priority
            )

            fieldBadge(
                icon: "calendar",
                iconColor: todo.dueDate != nil ? (isPastDue(todo.dueDate) ? .red : .secondary) : .secondary,
                label: todo.dueDate.map { formatDate($0) },
                field: .dueDate
            )

            fieldBadge(
                icon: "clock.badge.exclamationmark",
                iconColor: todo.deadlineDate != nil ? (isPastDue(todo.deadlineDate) ? .red : .secondary) : .secondary,
                label: todo.deadlineDate.map { formatDate($0) },
                field: .deadline
            )

            fieldBadge(
                icon: "tag.fill",
                iconColor: todo.tags.isEmpty ? .secondary : Color.fromString(todo.tags.first?.color ?? "gray"),
                label: todo.tags.isEmpty ? nil : (todo.tags.count == 1 ? todo.tags.first?.name : "\(todo.tags.count) tags"),
                field: .tags
            )

            let completedCount = todo.checklistItems.filter(\.isCompleted).count
            let totalCount = todo.checklistItems.count
            fieldBadge(
                icon: "checklist",
                iconColor: totalCount > 0 ? (completedCount == totalCount ? .green : .secondary) : .secondary,
                label: totalCount > 0 ? "\(completedCount)/\(totalCount)" : nil,
                field: .checklist
            )

            Spacer()
        }
    }

    private func fieldBadge(icon: String, iconColor: Color, label: String?, field: FieldKind) -> some View {
        let isExpanded = expandedField == field
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                expandedField = isExpanded ? nil : field
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.appScaled(size: 12))
                    .foregroundStyle(isExpanded ? Color.accentColor : iconColor)

                if let label {
                    Text(label)
                        .font(.appScaled(size: 11))
                        .foregroundStyle(isExpanded ? Color.accentColor : .primary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isExpanded
                        ? Color.accentColor.opacity(0.1)
                        : label != nil
                            ? Color.primary.opacity(0.05)
                            : Color.clear
                    )
            )
        }
        .buttonStyle(.plain)
        .help(fieldTooltip(field))
    }

    private func fieldTooltip(_ field: FieldKind) -> String {
        switch field {
        case .project: "Project"
        case .priority: "Priority"
        case .dueDate: "Due Date"
        case .deadline: "Deadline"
        case .tags: "Tags"
        case .checklist: "Checklist"
        case .status: "Status"
        }
    }

    // MARK: - Expanded Field Editors

    @ViewBuilder
    private func expandedFieldEditor(for field: FieldKind) -> some View {
        switch field {
        case .project:
            projectEditor
        case .priority:
            priorityEditor
        case .dueDate:
            dueDateEditor
        case .deadline:
            deadlineEditor
        case .tags:
            tagsEditor
        case .checklist:
            checklistEditor
        case .status:
            EmptyView()
        }
    }

    // MARK: Project Editor

    private var projectEditor: some View {
        Picker("Project", selection: Binding(
            get: { todo.project?.id },
            set: { newId in
                todo.project = projects.first(where: { $0.id == newId })
            }
        )) {
            Text("None")
                .tag(nil as UUID?)

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

    // MARK: Priority Editor

    private var priorityEditor: some View {
        HStack {
            Picker("Priority", selection: Binding(
                get: { todo.priority },
                set: { todo.priority = $0 }
            )) {
                ForEach(Priority.allCases, id: \.self) { priority in
                    Text(priority.label).tag(priority)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if todo.priority != .low {
                Button {
                    todo.priority = .low
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.appScaled(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Due Date Editor

    private var dueDateEditor: some View {
        HStack {
            if let date = todo.dueDate {
                DatePicker("", selection: Binding(
                    get: { date },
                    set: { todo.dueDate = $0 }
                ), displayedComponents: .date)
                .labelsHidden()
                .controlSize(.small)

                Button {
                    todo.dueDate = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.appScaled(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            } else {
                Button("Set Due Date") {
                    todo.dueDate = Date()
                }
                .controlSize(.small)
            }
        }
    }

    // MARK: Deadline Editor

    private var deadlineEditor: some View {
        HStack {
            if let date = todo.deadlineDate {
                DatePicker("", selection: Binding(
                    get: { date },
                    set: { todo.deadlineDate = $0 }
                ), displayedComponents: .date)
                .labelsHidden()
                .controlSize(.small)

                Button {
                    todo.deadlineDate = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.appScaled(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            } else {
                Button("Set Deadline") {
                    todo.deadlineDate = Date()
                }
                .controlSize(.small)
            }
        }
    }

    // MARK: Tags Editor

    @State private var tagSearchText = ""

    private var availableTags: [Tag] {
        let assignedIds = Set(todo.tags.map(\.persistentModelID))
        let filtered = allTags.filter { !assignedIds.contains($0.persistentModelID) }
        if tagSearchText.isEmpty { return filtered }
        return filtered.filter { $0.name.localizedCaseInsensitiveContains(tagSearchText) }
    }

    private var canCreateTag: Bool {
        let trimmed = tagSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return !allTags.contains(where: { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame })
    }

    private var tagsEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !todo.tags.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(todo.tags) { tag in
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
                        .background(
                            Capsule()
                                .fill(Color.fromString(tag.color).opacity(0.2))
                        )
                        .foregroundStyle(Color.fromString(tag.color))
                    }
                }
            }

            TextField("Search or create tag...", text: $tagSearchText)
                .textFieldStyle(.roundedBorder)
                .font(.appScaled(size: 12))
                .onSubmit {
                    if canCreateTag {
                        createAndAssignTag()
                    } else if let first = availableTags.first {
                        assignTag(first)
                    }
                }

            if !availableTags.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(availableTags.prefix(5)) { tag in
                        Button {
                            assignTag(tag)
                        } label: {
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
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.04))
                )
            }

            if canCreateTag {
                Button {
                    createAndAssignTag()
                } label: {
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

    private func assignTag(_ tag: Tag) {
        todo.tags.append(tag)
        tagSearchText = ""
    }

    private func createAndAssignTag() {
        let name = tagSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let tag = Tag(name: name, color: ProjectColor.random.rawValue)
        tag.project = todo.project
        modelContext.insert(tag)
        todo.tags.append(tag)
        tagSearchText = ""
    }

    // MARK: Checklist Editor

    private var checklistEditor: some View {
        VStack(alignment: .leading, spacing: 2) {
            let sortedItems = todo.checklistItems.sorted { $0.sortOrder < $1.sortOrder }
            ForEach(sortedItems) { item in
                ChecklistItemRow(item: item) {
                    modelContext.delete(item)
                }
            }

            Button {
                let item = ChecklistItem(title: "", sortOrder: todo.checklistItems.count)
                item.todo = todo
                modelContext.insert(item)
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

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func isPastDue(_ date: Date?) -> Bool {
        guard let date else { return false }
        return date < Date() && !todo.isCompleted
    }
}

// MARK: - Checklist Item Row

private struct ChecklistItemRow: View {
    @Bindable var item: ChecklistItem
    var onDelete: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Button {
                item.isCompleted.toggle()
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.appScaled(size: 14))
                    .foregroundStyle(item.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            TextField("Checklist item", text: $item.title)
                .textFieldStyle(.plain)
                .font(.appScaled(size: 13))
                .strikethrough(item.isCompleted)
                .foregroundStyle(item.isCompleted ? .secondary : .primary)

            if isHovered {
                Button {
                    onDelete?()
                } label: {
                    Image(systemName: "trash")
                        .font(.appScaled(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.polarisHover(size: .small))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

//
//  TaskCardView.swift
//  Polaris
//
//  Expanded task card that appears inline, hovering over the task list.
//  Contains all task editing options.
//

import SwiftUI
import SwiftData

struct TaskCardView: View {
    @Bindable var todo: Todo
    var onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Query private var allTags: [Tag]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header
            cardHeader

            Divider()

            // Card content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    titleSection
                    statusAndPrioritySection
                    datesSection
                    projectSection
                    tagsSection

                    Divider()

                    notesSection

                    Divider()

                    checklistSection
                }
                .padding(20)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Card Header

    private var cardHeader: some View {
        HStack {
            // Completion checkbox
            Button {
                todo.isCompleted.toggle()
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.appScaled(size: 18))
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Text(todo.title.isEmpty ? "Untitled" : todo.title)
                .font(.appScaled(size: 15, weight: .semibold))
                .lineLimit(1)

            Spacer()

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.appScaled(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Title

    private var titleSection: some View {
        propertyRow(label: "Title") {
            TextField("Task title", text: $todo.title)
                .textFieldStyle(.plain)
                .font(.appScaled(size: 13))
        }
    }

    // MARK: - Status & Priority

    private var statusAndPrioritySection: some View {
        HStack(alignment: .top, spacing: 24) {
            propertyRow(label: "Status") {
                Toggle(isOn: $todo.isCompleted) {
                    Text(todo.isCompleted ? "Completed" : "Open")
                        .font(.appScaled(size: 13))
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            propertyRow(label: "Priority") {
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
            }
        }
    }

    // MARK: - Dates

    private var datesSection: some View {
        HStack(alignment: .top, spacing: 24) {
            propertyRow(label: "Due Date") {
                DatePickerRow(date: $todo.dueDate, placeholder: "No due date")
            }

            propertyRow(label: "Deadline") {
                DatePickerRow(date: $todo.deadlineDate, placeholder: "No deadline")
            }
        }
    }

    // MARK: - Project

    private var projectSection: some View {
        propertyRow(label: "Project") {
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
                            .foregroundStyle(Color.fromString(project.color))
                    }
                    .tag(project.id as UUID?)
                }
            }
            .labelsHidden()
            .controlSize(.small)
        }
    }

    // MARK: - Tags

    @State private var tagSearchText = ""
    @State private var isAddingTag = false

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

    private var tagsSection: some View {
        propertyRow(label: "Tags") {
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

                if isAddingTag {
                    VStack(alignment: .leading, spacing: 4) {
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
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    Button {
                        isAddingTag = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                                .font(.appScaled(size: 12))
                            Text("Add Tag")
                                .font(.appScaled(size: 12))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func assignTag(_ tag: Tag) {
        todo.tags.append(tag)
        tagSearchText = ""
        isAddingTag = false
    }

    private func createAndAssignTag() {
        let name = tagSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let tag = Tag(name: name, color: ProjectColor.random.rawValue)
        tag.project = todo.project
        modelContext.insert(tag)
        todo.tags.append(tag)
        tagSearchText = ""
        isAddingTag = false
    }

    // MARK: - Notes

    private var notesSection: some View {
        propertyRow(label: "Notes") {
            LiveMarkdownEditor(
                text: $todo.note,
                baseFontSize: 13
            )
            .frame(minHeight: 100)
        }
    }

    // MARK: - Checklist

    private var checklistSection: some View {
        propertyRow(label: "Checklist") {
            VStack(spacing: 2) {
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
    }

    // MARK: - Helpers

    private func propertyRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.appScaled(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            content()
        }
    }
}

// MARK: - Date Picker Row

private struct DatePickerRow: View {
    @Binding var date: Date?
    let placeholder: String

    var body: some View {
        HStack {
            if let date = date {
                DatePicker("", selection: Binding(
                    get: { date },
                    set: { self.date = $0 }
                ), displayedComponents: .date)
                .labelsHidden()
                .controlSize(.small)

                Button {
                    self.date = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.appScaled(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    date = Date()
                } label: {
                    Text(placeholder)
                        .font(.appScaled(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
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

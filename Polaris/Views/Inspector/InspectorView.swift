//
//  InspectorView.swift
//  Polaris
//

import SwiftUI
import SwiftData

struct InspectorView: View {
    let selectionStore: SelectionStore
    let windowState: WindowStateModel
    var onToggleInspector: (() -> Void)?

    @State private var selectedTab: Int = 0

    private let tabs: [PolarisTabBar.TabItem] = [
        .init(id: 0, symbolName: "info.circle", tooltip: "Details"),
        .init(id: 1, symbolName: "doc.text", tooltip: "Notes"),
        .init(id: 2, symbolName: "checklist", tooltip: "Checklist"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            inspectorHeader

            Divider()

            // Content
            if let todo = selectionStore.selectedTodo {
                inspectorContent(for: todo)
            } else {
                noSelectionView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectBackground(material: .sidebar))
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Header

    private var inspectorHeader: some View {
        HStack(spacing: 8) {
            Button(action: { onToggleInspector?() }) {
                Image(systemName: "sidebar.trailing")
                    .font(.appScaled(size: 14))
            }
            .buttonStyle(.polarisHover(size: .large))

            Spacer()

            PolarisTabBar(tabs: tabs, selectedIndex: $selectedTab)
                .frame(width: 160)

            Spacer()

            // Balance the toggle button width
            Color.clear
                .frame(width: 32, height: 32)
        }
        .padding(.horizontal, 8)
        .frame(height: 52)
    }

    // MARK: - Content

    @ViewBuilder
    private func inspectorContent(for todo: Todo) -> some View {
        switch selectedTab {
        case 0:
            detailsTab(for: todo)
        case 1:
            notesTab(for: todo)
        case 2:
            checklistTab(for: todo)
        default:
            EmptyView()
        }
    }

    // MARK: - Details Tab

    private func detailsTab(for todo: Todo) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                propertyRow(label: "Title") {
                    TextField("Task title", text: Binding(
                        get: { todo.title },
                        set: { todo.title = $0 }
                    ))
                    .textFieldStyle(.plain)
                    .font(.appScaled(size: 13))
                }

                // Status
                propertyRow(label: "Status") {
                    Toggle(isOn: Binding(
                        get: { todo.isCompleted },
                        set: { todo.isCompleted = $0 }
                    )) {
                        Text(todo.isCompleted ? "Completed" : "Open")
                            .font(.appScaled(size: 13))
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }

                // Priority
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

                // Due Date
                propertyRow(label: "Due Date") {
                    DatePickerRow(
                        date: Binding(
                            get: { todo.dueDate },
                            set: { todo.dueDate = $0 }
                        ),
                        placeholder: "No due date"
                    )
                }

                // Deadline
                propertyRow(label: "Deadline") {
                    DatePickerRow(
                        date: Binding(
                            get: { todo.deadlineDate },
                            set: { todo.deadlineDate = $0 }
                        ),
                        placeholder: "No deadline"
                    )
                }

                // Project
                if let project = todo.project {
                    propertyRow(label: "Project") {
                        HStack(spacing: 4) {
                            Image(systemName: project.icon)
                                .font(.appScaled(size: 12))
                                .foregroundStyle(Color.fromString(project.color))
                            Text(project.name)
                                .font(.appScaled(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Tags
                propertyRow(label: "Tags") {
                    if todo.tags.isEmpty {
                        Text("No tags")
                            .font(.appScaled(size: 13))
                            .foregroundStyle(.tertiary)
                    } else {
                        FlowLayout(spacing: 4) {
                            ForEach(todo.tags) { tag in
                                Text(tag.name)
                                    .font(.appScaled(size: 11))
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
                }
            }
            .padding(16)
        }
    }

    // MARK: - Notes Tab

    private func notesTab(for todo: Todo) -> some View {
        LiveMarkdownEditor(
            text: Binding(
                get: { todo.note },
                set: { todo.note = $0 }
            ),
            baseFontSize: 13
        )
    }

    // MARK: - Checklist Tab

    private func checklistTab(for todo: Todo) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 2) {
                    let sortedItems = todo.checklistItems.sorted { $0.sortOrder < $1.sortOrder }
                    ForEach(sortedItems) { item in
                        ChecklistItemRow(item: item) {
                            deleteChecklistItem(item, from: todo)
                        }
                    }
                }
                .padding(12)
            }

            Divider()

            // Add checklist item button
            Button {
                addChecklistItem(to: todo)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                        .font(.appScaled(size: 13))
                    Text("Add Item")
                        .font(.appScaled(size: 13))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - No Selection

    private var noSelectionView: some View {
        VStack(spacing: 8) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 28))
                .foregroundStyle(.quaternary)
            Text("No task selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    @Environment(\.modelContext) private var modelContext

    private func addChecklistItem(to todo: Todo) {
        let item = ChecklistItem(title: "", sortOrder: todo.checklistItems.count)
        item.todo = todo
        modelContext.insert(item)
    }

    private func deleteChecklistItem(_ item: ChecklistItem, from todo: Todo) {
        modelContext.delete(item)
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

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (positions, CGSize(width: maxWidth, height: totalHeight))
    }
}

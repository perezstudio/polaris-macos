//
//  TaskRowView.swift
//  Polaris
//

import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Bindable var todo: Todo
    let isSelected: Bool
    var startInEditMode: Bool = false
    var onSelect: (() -> Void)?
    var onEditModeStarted: (() -> Void)?
    var onEditingChanged: ((Bool) -> Void)?

    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editingTitle = ""
    @FocusState private var titleFieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Completion checkbox
            Button {
                todo.isCompleted.toggle()
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.appScaled(size: 16))
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            // Due date badge (between checkbox and title)
            if let dueDate = todo.dueDate {
                Text(relativeDate(dueDate))
                    .font(.appScaled(size: 10, weight: .medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(dueDateColor(dueDate).opacity(0.12))
                    )
                    .foregroundStyle(dueDateColor(dueDate))
            }

            // Title
            if isEditing {
                TextField("New Task", text: $editingTitle)
                    .textFieldStyle(.plain)
                    .font(.appScaled(size: 13))
                    .focused($titleFieldFocused)
                    .onSubmit { commitEdit() }
                    .onExitCommand { cancelEdit() }
                    .onChange(of: titleFieldFocused) { _, focused in
                        if !focused { commitEdit() }
                    }
            } else {
                Text(todo.title.isEmpty ? "Untitled" : todo.title)
                    .font(.appScaled(size: 13))
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                    .strikethrough(todo.isCompleted)
                    .lineLimit(1)
                    .onTapGesture(count: 2) { startEditing() }
            }

            // Notes / checklist indicators
            if !todo.note.isEmpty {
                Image(systemName: "note.text")
                    .font(.appScaled(size: 11))
                    .foregroundStyle(.tertiary)
            }

            if !todo.checklistItems.isEmpty {
                let completed = todo.checklistItems.filter(\.isCompleted).count
                let total = todo.checklistItems.count
                HStack(spacing: 2) {
                    Image(systemName: "checklist")
                        .font(.appScaled(size: 11))
                    Text("\(completed)/\(total)")
                        .font(.appScaled(size: 10))
                }
                .foregroundStyle(completed == total ? Color.green : Color(nsColor: .tertiaryLabelColor))
            }

            Spacer()

            // Tag pills
            ForEach(todo.tags.sorted(by: {
                if $0.name != $1.name { return $0.name < $1.name }
                return $0.persistentModelID.hashValue < $1.persistentModelID.hashValue
            })) { tag in
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

            // Priority indicator
            if todo.priority != .none {
                priorityBadge
            }

            // Deadline (right edge)
            if let deadline = todo.deadlineDate {
                HStack(spacing: 3) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.appScaled(size: 11))
                    Text(relativeDate(deadline))
                        .font(.appScaled(size: 11))
                }
                .foregroundStyle(dueDateColor(deadline))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isSelected ? Color.accentColor.opacity(0.15) :
                    isHovered ? Color.primary.opacity(0.04) :
                    Color.clear
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect?() }
        .onHover { isHovered = $0 }
        .onAppear {
            if startInEditMode {
                startEditing()
                onEditModeStarted?()
            }
        }
    }

    private func startEditing() {
        editingTitle = todo.title
        isEditing = true
        titleFieldFocused = true
        onEditingChanged?(true)
    }

    private func commitEdit() {
        guard isEditing else { return }
        todo.title = editingTitle
        isEditing = false
        onEditingChanged?(false)
    }

    private func cancelEdit() {
        isEditing = false
        onEditingChanged?(false)
    }

    private var priorityBadge: some View {
        Image(systemName: priorityIcon)
            .font(.appScaled(size: 11))
            .foregroundStyle(Color.fromString(todo.priority.color))
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

    private func isPastDue(_ date: Date) -> Bool {
        Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date()) && !todo.isCompleted
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    private func dueDateColor(_ date: Date) -> Color {
        if isPastDue(date) { return .red }
        if isToday(date) { return .yellow }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days == 1 { return .orange }
        return .secondary
    }

    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0

        switch days {
        case ..<(-1): return "\(abs(days))d ago"
        case -1: return "Yesterday"
        case 0: return "Today"
        case 1: return "Tomorrow"
        case 2...6:
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        default:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

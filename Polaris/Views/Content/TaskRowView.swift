//
//  TaskRowView.swift
//  Polaris
//

import SwiftUI

struct TaskRowView: View {
    @Bindable var todo: Todo
    let isSelected: Bool
    var onSelect: (() -> Void)?

    @State private var isHovered = false

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

            // Title
            if todo.title.isEmpty && isSelected {
                TextField("New Task", text: $todo.title)
                    .textFieldStyle(.plain)
                    .font(.appScaled(size: 13))
            } else {
                Text(todo.title.isEmpty ? "Untitled" : todo.title)
                    .font(.appScaled(size: 13))
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                    .strikethrough(todo.isCompleted)
                    .lineLimit(1)
            }

            Spacer()

            // Priority indicator
            if todo.priority != .low {
                priorityBadge
            }

            // Due date
            if let dueDate = todo.dueDate {
                Text(dueDate, style: .date)
                    .font(.appScaled(size: 11))
                    .foregroundStyle(isPastDue(dueDate) ? .red : .secondary)
            }

            // Tag pills
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
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect?()
        }
    }

    private var priorityBadge: some View {
        Image(systemName: priorityIcon)
            .font(.appScaled(size: 11))
            .foregroundStyle(Color.fromString(todo.priority.color))
    }

    private var priorityIcon: String {
        switch todo.priority {
        case .low: "arrow.down"
        case .medium: "minus"
        case .high: "arrow.up"
        case .urgent: "exclamationmark.2"
        }
    }

    private func isPastDue(_ date: Date) -> Bool {
        date < Date() && !todo.isCompleted
    }
}

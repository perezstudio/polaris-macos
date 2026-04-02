//
//  ProjectRowView.swift
//  Polaris
//
//  Project row in the sidebar with icon, name, and hover ellipsis menu.
//  Supports inline name editing for newly created projects.
//

import SwiftUI

struct ProjectRowView: View {
    @Bindable var project: Project
    let isSelected: Bool
    let isEditing: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onCommitRename: () -> Void

    @State private var isHovered = false
    @FocusState private var nameFieldFocused: Bool

    private var projectColor: Color {
        Color.fromString(project.color)
    }

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
                .frame(width: 10)

            Image(systemName: project.icon)
                .font(.appScaled(size: 14, weight: .medium))
                .foregroundStyle(projectColor)
                .frame(width: 18)

            if isEditing {
                TextField("New Project", text: $project.name)
                    .font(.appScaled(size: 14, weight: .semibold))
                    .textFieldStyle(.plain)
                    .padding(.leading, 6)
                    .focused($nameFieldFocused)
                    .onSubmit {
                        onCommitRename()
                    }
                    .onAppear {
                        nameFieldFocused = true
                    }
            } else {
                Text(project.name)
                    .font(.appScaled(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .padding(.leading, 6)
            }

            Spacer(minLength: 0)

            if isHovered && !isEditing {
                let todoCount = project.todos.filter { !$0.isCompleted }.count
                if todoCount > 0 {
                    Text("\(todoCount)")
                        .font(.appScaled(size: 11))
                        .foregroundStyle(.tertiary)
                        .padding(.trailing, 4)
                }

                NSMenuButton(systemImage: "ellipsis", imageSize: 9, imageWeight: .bold) {
                    MenuItems.button("Edit Project...", systemImage: "pencil") { onEdit() }
                    MenuItems.divider()
                    MenuItems.destructiveButton("Remove Project", systemImage: "trash") { onDelete() }
                }
                .frame(width: 24, height: 24)
                .transition(.opacity)
            }

            Spacer()
                .frame(width: 10)
        }
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    isSelected ? Color.accentColor.opacity(0.2) :
                    Color.primary.opacity(isHovered ? 0.08 : 0)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .rightClickMenu {
            MenuItems.button("Edit Project...", systemImage: "pencil") { onEdit() }
            MenuItems.divider()
            MenuItems.destructiveButton("Remove Project", systemImage: "trash") { onDelete() }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

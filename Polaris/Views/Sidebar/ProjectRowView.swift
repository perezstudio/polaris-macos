//
//  ProjectRowView.swift
//  Polaris
//
//  Project row in the sidebar with icon, name, and hover ellipsis menu.
//

import SwiftUI

struct ProjectRowView: View {
    let project: Project
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

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

            Text(project.name)
                .font(.appScaled(size: 14, weight: .semibold))
                .lineLimit(1)
                .padding(.leading, 6)

            Spacer(minLength: 0)

            if isHovered {
                let todoCount = project.todos.filter { !$0.isCompleted }.count
                if todoCount > 0 {
                    Text("\(todoCount)")
                        .font(.appScaled(size: 11))
                        .foregroundStyle(.tertiary)
                        .padding(.trailing, 4)
                }

                Menu {
                    Button {
                        onEdit()
                    } label: {
                        Label("Edit Project...", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Remove Project", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.appScaled(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.polarisHover(size: .small))
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
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit Project...", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Remove Project", systemImage: "trash")
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Color from String

extension Color {
    static func fromString(_ string: String) -> Color {
        switch string.lowercased() {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "mint": return .mint
        case "teal": return .teal
        case "cyan": return .cyan
        case "blue": return .blue
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        case "brown": return .brown
        case "gray", "grey": return .gray
        default: return .blue
        }
    }
}

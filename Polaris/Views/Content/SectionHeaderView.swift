//
//  SectionHeaderView.swift
//  Polaris
//

import SwiftUI
import SwiftData

struct SectionHeaderView: View {
    @Bindable var section: Section
    let isBeingDragged: Bool
    var startInEditMode: Bool = false
    var onAddTask: (() -> Void)?
    var onDeleteKeepTasks: (() -> Void)?
    var onDeleteWithTasks: (() -> Void)?
    var onMoveToProject: (() -> Void)?
    var onConvertToProject: (() -> Void)?
    var onEditModeStarted: (() -> Void)?
    var onEditingChanged: ((Bool) -> Void)?

    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editingName = ""
    @FocusState private var nameFieldFocused: Bool

    private var sectionColor: Color {
        Color.fromString(section.color)
    }

    private var taskCount: Int {
        section.todos.count
    }

    private var incompleteCount: Int {
        section.todos.filter { !$0.isCompleted }.count
    }

    @ViewBuilder
    private var sectionMenu: some View {
        Button("Add Task") { onAddTask?() }
        Divider()

        Menu("Color") {
            ForEach(ProjectColor.allCases, id: \.self) { pc in
                Button {
                    section.color = pc.rawValue
                } label: {
                    HStack {
                        Circle()
                            .fill(pc.color)
                            .frame(width: 8, height: 8)
                        Text(pc.label)
                        if section.color == pc.rawValue {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }

        Divider()
        Button("Move to Another Project...") { onMoveToProject?() }
        Button("Convert to Project") { onConvertToProject?() }
        Divider()
        Button("Delete Section Only") { onDeleteKeepTasks?() }
        Button("Delete Section and Tasks", role: .destructive) { onDeleteWithTasks?() }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Collapse chevron
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    section.isCollapsed.toggle()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.appScaled(size: 10, weight: .semibold))
                    .foregroundStyle(sectionColor)
                    .rotationEffect(.degrees(section.isCollapsed ? 0 : 90))
            }
            .buttonStyle(.plain)
            .frame(width: 16)

            // Section name (editable)
            if isEditing {
                TextField("Section Name", text: $editingName)
                    .textFieldStyle(.plain)
                    .font(.appScaled(size: 12, weight: .semibold))
                    .foregroundStyle(sectionColor)
                    .focused($nameFieldFocused)
                    .onSubmit { commitEdit() }
                    .onExitCommand { commitEdit() }
                    .onChange(of: nameFieldFocused) { _, focused in
                        if !focused { commitEdit() }
                    }
            } else {
                Text(section.name.isEmpty ? "Untitled Section" : section.name)
                    .font(.appScaled(size: 12, weight: .semibold))
                    .foregroundStyle(sectionColor)
                    .lineLimit(1)
                    .onTapGesture {
                        startEditing()
                    }
            }

            Spacer()

            // Task count
            if taskCount > 0 {
                Text("\(incompleteCount)/\(taskCount)")
                    .font(.appScaled(size: 10, weight: .medium))
                    .foregroundStyle(sectionColor.opacity(0.7))
            }

            // Ellipsis menu — always reserves space, only visible on hover
            Menu {
                sectionMenu
            } label: {
                Image(systemName: "ellipsis")
                    .font(.appScaled(size: 11))
            }
            .menuStyle(.polarisHover(size: .small))
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(sectionColor.opacity(0.1))
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            sectionMenu
        }
        .onAppear {
            if startInEditMode {
                startEditing()
                onEditModeStarted?()
            }
        }
    }

    // MARK: - Editing

    private func startEditing() {
        editingName = section.name
        isEditing = true
        nameFieldFocused = true
        onEditingChanged?(true)
    }

    private func commitEdit() {
        guard isEditing else { return }
        section.name = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        if section.name.isEmpty {
            section.name = "Untitled Section"
        }
        isEditing = false
        onEditingChanged?(false)
    }
}

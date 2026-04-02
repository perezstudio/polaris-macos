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

    var body: some View {
        HStack(spacing: 8) {
            // Collapse toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    section.isCollapsed.toggle()
                }
            } label: {
                Image(systemName: section.isCollapsed ? "diamond.fill" : "diamond")
                    .font(.appScaled(size: 11))
            }
            .buttonStyle(.polarisHover(size: .small, iconColor: sectionColor))

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

            // Ellipsis menu — always reserves space, only visible on hover
            NSMenuButton(systemImage: "ellipsis", imageSize: 11, imageWeight: .bold, tintColor: NSColor(sectionColor)) {
                MenuItems.button("Add Task", systemImage: "plus") { onAddTask?() }
                MenuItems.divider()
                MenuItems.submenu("Color", systemImage: "paintpalette") {
                    ProjectColor.allCases.map { pc in
                        let title = section.color == pc.rawValue ? "\(pc.label) ✓" : pc.label
                        return MenuItems.button(title) { section.color = pc.rawValue }
                    }
                }
                MenuItems.divider()
                MenuItems.button("Move to Another Project...", systemImage: "arrow.right") { onMoveToProject?() }
                MenuItems.button("Convert to Project", systemImage: "folder") { onConvertToProject?() }
                MenuItems.divider()
                MenuItems.destructiveButton("Delete Section Only", systemImage: "xmark.rectangle") { onDeleteKeepTasks?() }
                MenuItems.destructiveButton("Delete Section and Tasks", systemImage: "trash") { onDeleteWithTasks?() }
            }
            .frame(width: 24, height: 24)
            .opacity(isHovered ? 1 : 0)
            .allowsHitTesting(isHovered)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(sectionColor.opacity(0.1))
        )
        .contentShape(Rectangle())
        .preference(key: InlineEditingKey.self, value: isEditing)
        .onHover { isHovered = $0 }
        .rightClickMenu {
            MenuItems.button("Add Task", systemImage: "plus") { onAddTask?() }
            MenuItems.divider()
            MenuItems.submenu("Color", systemImage: "paintpalette") {
                ProjectColor.allCases.map { pc in
                    let title = section.color == pc.rawValue ? "\(pc.label) ✓" : pc.label
                    return MenuItems.button(title) { section.color = pc.rawValue }
                }
            }
            MenuItems.divider()
            MenuItems.button("Move to Another Project...", systemImage: "arrow.right") { onMoveToProject?() }
            MenuItems.button("Convert to Project", systemImage: "folder") { onConvertToProject?() }
            MenuItems.divider()
            MenuItems.destructiveButton("Delete Section Only", systemImage: "xmark.rectangle") { onDeleteKeepTasks?() }
            MenuItems.destructiveButton("Delete Section and Tasks", systemImage: "trash") { onDeleteWithTasks?() }
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

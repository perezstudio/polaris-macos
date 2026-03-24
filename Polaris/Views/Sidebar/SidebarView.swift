//
//  SidebarView.swift
//  Polaris
//

import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.createdAt) private var projects: [Project]

    let selectionStore: SelectionStore
    let windowState: WindowStateModel
    var onToggleSidebar: (() -> Void)?

    @State private var editingProject: Project?

    var body: some View {
        VStack(spacing: 0) {
            header
            addProjectButton
            projectList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectBackground(material: .sidebar))
        .ignoresSafeArea(edges: .top)
        .sheet(item: $editingProject) { project in
            ProjectEditSheet(project: project)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Spacer()

            Button(action: { onToggleSidebar?() }) {
                Image(systemName: "sidebar.leading")
                    .font(.appScaled(size: 14))
            }
            .buttonStyle(.polarisHover(size: .large))
        }
        .padding(.horizontal, 8)
        .frame(height: 52)
    }

    // MARK: - Add Project Button

    private var addProjectButton: some View {
        Button { addProject() } label: {
            AddProjectRow()
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.top, 4)
    }

    // MARK: - Project List

    private var projectList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(projects) { project in
                    ProjectRowView(
                        project: project,
                        isSelected: selectionStore.selectedProject?.id == project.id,
                        onSelect: {
                            selectionStore.selectedProject = project
                            selectionStore.selectedTodo = nil
                        },
                        onEdit: {
                            editingProject = project
                        },
                        onDelete: {
                            deleteProject(project)
                        }
                    )
                    .padding(.horizontal, 10)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Actions

    private func addProject() {
        let project = Project(name: "New Project")
        modelContext.insert(project)
        selectionStore.selectedProject = project
    }

    private func deleteProject(_ project: Project) {
        if selectionStore.selectedProject?.id == project.id {
            selectionStore.selectedProject = nil
            selectionStore.selectedTodo = nil
        }
        modelContext.delete(project)
    }
}

// MARK: - Add Project Row

private struct AddProjectRow: View {
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
                .frame(width: 10)

            Image(systemName: "plus.circle")
                .font(.appScaled(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text("Add Project")
                .font(.appScaled(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 6)

            Spacer()
        }
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.primary.opacity(isHovered ? 0.08 : 0))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

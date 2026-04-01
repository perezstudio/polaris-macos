//
//  SidebarView.swift
//  Polaris
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.sortOrder) private var projects: [Project]

    let selectionStore: SelectionStore
    let windowState: WindowStateModel
    var onToggleSidebar: (() -> Void)?

    @State private var editingProject: Project?
    @State private var renamingProjectId: PersistentIdentifier?
    @State private var orderedProjects: [Project] = []
    @State private var draggedProjectId: UUID?
    @State private var projectPendingDeletion: Project?

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    addProjectButton
                    projectList
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectBackground(material: .sidebar))
        .ignoresSafeArea(edges: .top)
        .sheet(item: $editingProject) { project in
            ProjectEditSheet(project: project)
        }
        .sheet(item: $projectPendingDeletion) { project in
            DeleteConfirmationDialog(
                icon: project.icon,
                iconColor: Color.fromString(project.color),
                title: "Delete \"\(project.name)\"?",
                message: "This project and all its tasks will be permanently deleted. This action cannot be undone.",
                onDelete: {
                    projectPendingDeletion = nil
                    deleteProject(project)
                },
                onCancel: {
                    projectPendingDeletion = nil
                }
            )
        }
        .onAppear { orderedProjects = projects }
        .onChange(of: projects.map(\.id)) { _, _ in orderedProjects = projects }
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
        .padding(.top, 2)
        .padding(.bottom, 4)
    }

    // MARK: - Project List

    private var projectList: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(orderedProjects) { project in
                let isBeingDragged = project.id == draggedProjectId

                ProjectRowView(
                    project: project,
                    isSelected: selectionStore.selectedProject?.id == project.id,
                    isEditing: renamingProjectId == project.persistentModelID,
                    onSelect: {
                        if renamingProjectId != nil {
                            commitRename()
                        }
                        selectionStore.selectedProject = project
                        selectionStore.selectedTodo = nil
                    },
                    onEdit: {
                        editingProject = project
                    },
                    onDelete: {
                        projectPendingDeletion = project
                    },
                    onCommitRename: {
                        commitRename()
                    }
                )
                .padding(.horizontal, 10)
                .opacity(isBeingDragged ? 0.35 : 1.0)
                .scaleEffect(isBeingDragged ? 0.95 : 1.0)
                .onDrag {
                    draggedProjectId = project.id
                    return NSItemProvider(object: project.id.uuidString as NSString)
                }
                .onDrop(of: [.text], delegate: ProjectDropDelegate(
                    targetProjectId: project.id,
                    orderedProjects: $orderedProjects,
                    draggedProjectId: $draggedProjectId,
                    modelContext: modelContext
                ))
            }
        }
    }

    // MARK: - Actions

    private func addProject() {
        commitRename()

        let maxOrder = projects.map(\.sortOrder).max() ?? -1
        let project = Project(name: "New Project", sortOrder: maxOrder + 1)
        modelContext.insert(project)
        selectionStore.selectedProject = project
        selectionStore.selectedTodo = nil

        renamingProjectId = project.persistentModelID
    }

    private func commitRename() {
        guard renamingProjectId != nil else { return }
        if let project = projects.first(where: { $0.persistentModelID == renamingProjectId }),
           project.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            project.name = "New Project"
        }
        renamingProjectId = nil
        try? modelContext.save()
    }

    private func deleteProject(_ project: Project) {
        if renamingProjectId == project.persistentModelID {
            renamingProjectId = nil
        }
        if selectionStore.selectedProject?.id == project.id {
            selectionStore.selectedProject = nil
            selectionStore.selectedTodo = nil
        }
        modelContext.delete(project)

        DispatchQueue.main.async {
            for (i, p) in projects.enumerated() {
                p.sortOrder = i
            }
            try? modelContext.save()
        }
    }
}

// MARK: - Drop Delegate

private struct ProjectDropDelegate: DropDelegate {
    let targetProjectId: UUID
    @Binding var orderedProjects: [Project]
    @Binding var draggedProjectId: UUID?
    let modelContext: ModelContext

    func dropEntered(info: DropInfo) {
        guard let draggedId = draggedProjectId,
              draggedId != targetProjectId,
              let fromIndex = orderedProjects.firstIndex(where: { $0.id == draggedId }),
              let toIndex = orderedProjects.firstIndex(where: { $0.id == targetProjectId }) else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            orderedProjects.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        for (i, project) in orderedProjects.enumerated() {
            project.sortOrder = i
        }
        try? modelContext.save()
        draggedProjectId = nil
        return true
    }

    func dropExited(info: DropInfo) {
        // No-op — items are already in the right position
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

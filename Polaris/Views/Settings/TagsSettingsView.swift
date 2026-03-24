//
//  TagsSettingsView.swift
//  Polaris
//
//  Tag management view for the Settings window.
//

import SwiftUI
import SwiftData

struct TagsSettingsView: View {
    @Query(sort: \Tag.name) private var tags: [Tag]
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTagID: PersistentIdentifier?
    @State private var editingName: String = ""
    @State private var editingColor: String = "blue"
    @State private var isAddingNew = false

    var body: some View {
        VStack(spacing: 0) {
            // Tag list
            List(selection: $selectedTagID) {
                ForEach(tags) { tag in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.fromString(tag.color))
                            .frame(width: 10, height: 10)

                        Text(tag.name)
                            .lineLimit(1)

                        Spacer()

                        Text("\(tag.todos.count) tasks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(tag.persistentModelID)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            Divider()

            // Bottom bar
            HStack(spacing: 0) {
                Button {
                    addTag()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)

                Button {
                    deleteSelectedTag()
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .disabled(selectedTagID == nil)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .safeAreaInset(edge: .trailing) {
            if let selectedTag = tags.first(where: { $0.persistentModelID == selectedTagID }) {
                tagEditor(for: selectedTag)
                    .frame(width: 220)
            }
        }
        .onChange(of: selectedTagID) { _, newValue in
            if let tag = tags.first(where: { $0.persistentModelID == newValue }) {
                editingName = tag.name
                editingColor = tag.color
            }
        }
    }

    // MARK: - Tag Editor

    private func tagEditor(for tag: Tag) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Tag name", text: $editingName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        tag.name = editingName
                    }
                    .onChange(of: editingName) { _, newValue in
                        tag.name = newValue
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Color")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(24), spacing: 6), count: 6), spacing: 6) {
                    ForEach(ProjectColor.allCases, id: \.self) { pc in
                        Circle()
                            .fill(pc.color)
                            .frame(width: 22, height: 22)
                            .overlay {
                                if tag.color == pc.rawValue {
                                    Image(systemName: "checkmark")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                            .onTapGesture {
                                tag.color = pc.rawValue
                                editingColor = pc.rawValue
                            }
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Actions

    private func addTag() {
        let tag = Tag(name: "New Tag", color: ProjectColor.random.rawValue)
        modelContext.insert(tag)
        try? modelContext.save()
        selectedTagID = tag.persistentModelID
        editingName = tag.name
        editingColor = tag.color
    }

    private func deleteSelectedTag() {
        guard let id = selectedTagID,
              let tag = tags.first(where: { $0.persistentModelID == id }) else { return }
        selectedTagID = nil
        modelContext.delete(tag)
        try? modelContext.save()
    }
}

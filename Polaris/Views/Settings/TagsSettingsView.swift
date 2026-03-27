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

    @State private var tagToEdit: Tag?
    @State private var tagPendingDeletion: Tag?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if tags.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tag")
                            .font(.system(size: 28))
                            .foregroundStyle(.quaternary)
                        Text("No Tags")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("Create a tag to get started.")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(tags.enumerated()), id: \.element.persistentModelID) { index, tag in
                            TagRow(
                                tag: tag,
                                onEdit: { tagToEdit = tag },
                                onDelete: { tagPendingDeletion = tag }
                            )

                            if index < tags.count - 1 {
                                Divider()
                                    .padding(.horizontal, 14)
                            }
                        }
                    }
                    .formGroupBackground()
                }

                Button {
                    addTag()
                } label: {
                    Text("Add Tag")
                }
                .controlSize(.regular)
            }
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $tagToEdit) { tag in
            TagEditSheet(tag: tag)
        }
        .confirmationDialog(
            "Delete \"\(tagPendingDeletion?.name ?? "Tag")\"?",
            isPresented: Binding(
                get: { tagPendingDeletion != nil },
                set: { if !$0 { tagPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let tag = tagPendingDeletion {
                    tagPendingDeletion = nil
                    modelContext.delete(tag)
                    try? modelContext.save()
                }
            }
            Button("Cancel", role: .cancel) {
                tagPendingDeletion = nil
            }
        } message: {
            Text("This tag will be removed from all tasks. This action cannot be undone.")
        }
    }

    private func addTag() {
        let tag = Tag(name: "New Tag", color: ProjectColor.random.rawValue)
        modelContext.insert(tag)
        try? modelContext.save()
        tagToEdit = tag
    }
}

// MARK: - Tag Row

private struct TagRow: View {
    let tag: Tag
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.fromString(tag.color))
                        .frame(width: 10, height: 10)

                    Text(tag.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Text("\(tag.todos.count) task\(tag.todos.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 18)
            }

            Spacer()

            HStack(spacing: 6) {
                Button("Edit", action: onEdit)
                    .controlSize(.small)

                Button("Delete", role: .destructive, action: onDelete)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Tag Edit Sheet

private struct TagEditSheet: View {
    @Bindable var tag: Tag
    @Environment(\.dismiss) private var dismiss

    @State private var editingName: String = ""
    @State private var editingColor: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Tag")
                .font(.headline)

            VStack(alignment: .leading, spacing: 16) {
                // Name
                VStack(alignment: .leading, spacing: 0) {
                    Text("Name")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 6)

                    TextField("Tag name", text: $editingName)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .formGroupBackground()
                }

                // Color
                VStack(alignment: .leading, spacing: 0) {
                    Text("Color")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 6)

                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(24), spacing: 6), count: 6), spacing: 6) {
                        ForEach(ProjectColor.allCases, id: \.self) { pc in
                            Circle()
                                .fill(pc.color)
                                .frame(width: 22, height: 22)
                                .overlay {
                                    if editingColor == pc.rawValue {
                                        Image(systemName: "checkmark")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture {
                                    editingColor = pc.rawValue
                                }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .formGroupBackground()
                }
            }

            HStack {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    tag.name = editingName
                    tag.color = editingColor
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(editingName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 320)
        .onAppear {
            editingName = tag.name
            editingColor = tag.color
        }
    }
}

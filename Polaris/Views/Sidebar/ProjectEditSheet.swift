//
//  ProjectEditSheet.swift
//  Polaris
//

import SwiftUI

struct ProjectEditSheet: View {
    var project: Project
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var icon: String = ""
    @State private var color: String = ""

    private let availableColors = ProjectColor.allCases

    private let availableIcons = [
        "folder.fill", "star.fill", "heart.fill", "bolt.fill",
        "flag.fill", "bookmark.fill", "tag.fill", "cube.fill",
        "briefcase.fill", "house.fill", "building.2.fill", "globe",
        "gear", "wrench.fill", "paintbrush.fill", "pencil",
        "doc.fill", "book.fill", "graduationcap.fill", "lightbulb.fill",
        "flame.fill", "leaf.fill", "drop.fill", "sun.max.fill",
        "moon.fill", "cloud.fill", "music.note", "gamecontroller.fill",
        "camera.fill", "photo.fill", "gift.fill", "cart.fill"
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Edit Project")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Name
            VStack(alignment: .leading, spacing: 4) {
                Text("NAME")
                    .font(.appScaled(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Project name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(.appScaled(size: 13))
            }

            // Icon picker
            VStack(alignment: .leading, spacing: 4) {
                Text("ICON")
                    .font(.appScaled(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 4), count: 8), spacing: 4) {
                    ForEach(availableIcons, id: \.self) { ic in
                        Button {
                            icon = ic
                        } label: {
                            Image(systemName: ic)
                                .font(.system(size: 14))
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(icon == ic ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.04))
                                )
                                .foregroundStyle(icon == ic ? Color.accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Color picker
            VStack(alignment: .leading, spacing: 4) {
                Text("COLOR")
                    .font(.appScaled(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 4), count: 8), spacing: 4) {
                    ForEach(availableColors, id: \.self) { pc in
                        Button {
                            color = pc.rawValue
                        } label: {
                            Circle()
                                .fill(pc.color)
                                .frame(width: 22, height: 22)
                                .overlay {
                                    if color == pc.rawValue {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    project.name = name
                    project.icon = icon
                    project.color = color
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 340)
        .onAppear {
            name = project.name
            icon = project.icon
            color = project.color
        }
    }
}

//
//  ProjectEditSheet.swift
//  Polaris
//

import SwiftUI

struct ProjectEditSheet: View {
    @Bindable var project: Project
    @Environment(\.dismiss) private var dismiss

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
                TextField("Project name", text: $project.name)
                    .textFieldStyle(.roundedBorder)
                    .font(.appScaled(size: 13))
            }

            // Icon picker
            VStack(alignment: .leading, spacing: 4) {
                Text("ICON")
                    .font(.appScaled(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 4), count: 8), spacing: 4) {
                    ForEach(availableIcons, id: \.self) { icon in
                        Button {
                            project.icon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 14))
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(project.icon == icon ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.04))
                                )
                                .foregroundStyle(project.icon == icon ? Color.accentColor : .secondary)
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

                HStack(spacing: 6) {
                    ForEach(availableColors, id: \.self) { pc in
                        Button {
                            project.color = pc.rawValue
                        } label: {
                            Circle()
                                .fill(pc.color)
                                .frame(width: 22, height: 22)
                                .overlay {
                                    if project.color == pc.rawValue {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 340, height: 380)
    }
}

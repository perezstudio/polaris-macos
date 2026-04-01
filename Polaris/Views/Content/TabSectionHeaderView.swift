//
//  TabSectionHeaderView.swift
//  Polaris
//
//  Section header for tab views (virtual sections not backed by Section model).
//  Matches SectionHeaderView styling.
//

import SwiftUI

struct TabSectionHeaderView: View {
    let title: String
    let icon: String
    let color: Color
    var isCollapsed: Bool = false
    var onToggleCollapse: (() -> Void)? = nil
    var isDropTarget: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            if let onToggleCollapse {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onToggleCollapse()
                    }
                } label: {
                    Image(systemName: isCollapsed ? "diamond.fill" : "diamond")
                        .font(.appScaled(size: 11))
                }
                .buttonStyle(.polarisHover(size: .small, iconColor: color))
            }

            Image(systemName: icon)
                .font(.appScaled(size: 11))
                .foregroundStyle(color)

            Text(title)
                .font(.appScaled(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(isDropTarget ? 0.2 : 0.1))
        )
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.15), value: isDropTarget)
    }
}

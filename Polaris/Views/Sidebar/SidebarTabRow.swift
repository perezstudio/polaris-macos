//
//  SidebarTabRow.swift
//  Polaris
//
//  Sidebar row for smart filter tabs (Inbox, Today, Scheduled, etc.).
//

import SwiftUI

struct SidebarTabRow: View {
    let tab: SidebarTab
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
                .frame(width: 10)

            Image(systemName: tab.icon)
                .font(.appScaled(size: 14, weight: .medium))
                .foregroundStyle(tab.color)
                .frame(width: 18)

            Text(tab.title)
                .font(.appScaled(size: 14, weight: .semibold))
                .lineLimit(1)
                .padding(.leading, 6)

            Spacer(minLength: 0)

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
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

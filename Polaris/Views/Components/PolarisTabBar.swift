//
//  PolarisTabBar.swift
//  Polaris
//
//  Icon-based tab bar with selection indicator and hover effects.
//

import SwiftUI

struct PolarisTabBar: View {

    struct TabItem: Identifiable {
        let id: Int
        let symbolName: String
        let tooltip: String
    }

    let tabs: [TabItem]
    @Binding var selectedIndex: Int

    @State private var hoveredIndex: Int?
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedIndex = tab.id
                    }
                } label: {
                    Image(systemName: tab.symbolName)
                        .font(.appScaled(size: 14))
                        .foregroundStyle(tab.id == selectedIndex ? Color.accentColor : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background {
                            if tab.id == selectedIndex {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.accentColor.opacity(0.2))
                                    .matchedGeometryEffect(id: "selection", in: selectionNamespace)
                            }
                        }
                        .background {
                            if hoveredIndex == tab.id && tab.id != selectedIndex {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.primary.opacity(0.08))
                            }
                        }
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoveredIndex = hovering ? tab.id : nil
                }
                .help(tab.tooltip)
            }
        }
        .padding(2)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.primary.opacity(0.04))
        )
        .animation(.easeInOut(duration: 0.15), value: hoveredIndex)
    }
}

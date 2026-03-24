//
//  PolarisStyles.swift
//  Polaris
//
//  Shared SwiftUI styles, modifiers, and color extensions.
//

import SwiftUI

// MARK: - Hover Button Style

enum HoverButtonSize {
    case small, regular, large

    var dimension: CGFloat {
        switch self {
        case .small: return 24
        case .regular: return 28
        case .large: return 32
        }
    }

    var symbolSize: CGFloat {
        switch self {
        case .small: return 12
        case .regular: return 13
        case .large: return 15
        }
    }
}

struct HoverButtonStyle: ButtonStyle {
    let size: HoverButtonSize
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size.dimension, height: size.dimension)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(
                        configuration.isPressed ? 0.15 :
                        isHovered ? 0.08 : 0
                    ))
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}

extension ButtonStyle where Self == HoverButtonStyle {
    static func polarisHover(size: HoverButtonSize = .regular) -> HoverButtonStyle {
        HoverButtonStyle(size: size)
    }
}

// MARK: - Hover Menu Style

struct HoverMenuStyle: MenuStyle {
    let size: HoverButtonSize
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        Menu(configuration)
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .frame(width: size.dimension, height: size.dimension)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(isHovered ? 0.08 : 0))
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}

extension MenuStyle where Self == HoverMenuStyle {
    static func polarisHover(size: HoverButtonSize = .regular) -> HoverMenuStyle {
        HoverMenuStyle(size: size)
    }
}

// MARK: - Sheet Layout Modifier

struct PolarisSheetLayout: ViewModifier {
    let icon: String
    let title: String

    func body(content: Content) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            content
        }
        .padding(24)
    }
}

extension View {
    func polarisSheetLayout(icon: String, title: String) -> some View {
        modifier(PolarisSheetLayout(icon: icon, title: title))
    }
}

// MARK: - Visual Effect Background

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    init(material: NSVisualEffectView.Material = .sidebar, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Color Extensions

extension Color {
    static let polarisAccent = Color.accentColor
    static let polarisSecondaryLabel = Color(nsColor: .secondaryLabelColor)
    static let polarisTertiaryLabel = Color(nsColor: .tertiaryLabelColor)
    static let polarisSeparator = Color(nsColor: .separatorColor)
    static let polarisControlBackground = Color(nsColor: .controlBackgroundColor)
    static let polarisWindowBackground = Color(nsColor: .windowBackgroundColor)
}

//
//  RightClickMenu.swift
//  Polaris
//
//  Provides a right-click context menu modifier that sets secondary selection
//  before showing the menu and clears it on dismiss.
//

import AppKit
import SwiftUI

// MARK: - View Modifier

struct RightClickMenuModifier: ViewModifier {
    let menu: NSMenu
    let onShow: () -> Void
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        content.overlay(
            RightClickMenuRepresentable(menu: menu, onShow: onShow, onDismiss: onDismiss)
        )
    }
}

extension View {
    func rightClickMenu(
        selectionStore: SelectionStore,
        todo: Todo,
        @RightClickMenuBuilder items: () -> [NSMenuItem]
    ) -> some View {
        let menu = NSMenu()
        for item in items() {
            menu.addItem(item)
        }
        return modifier(RightClickMenuModifier(
            menu: menu,
            onShow: { selectionStore.setSecondarySelection(todo) },
            onDismiss: { selectionStore.clearSecondarySelection() }
        ))
    }

    func rightClickMenu(
        @RightClickMenuBuilder items: () -> [NSMenuItem]
    ) -> some View {
        let menu = NSMenu()
        for item in items() {
            menu.addItem(item)
        }
        return modifier(RightClickMenuModifier(
            menu: menu,
            onShow: {},
            onDismiss: {}
        ))
    }
}

// MARK: - Menu Builder

@resultBuilder
struct RightClickMenuBuilder {
    static func buildBlock(_ components: [NSMenuItem]...) -> [NSMenuItem] {
        components.flatMap { $0 }
    }

    static func buildExpression(_ expression: NSMenuItem) -> [NSMenuItem] {
        [expression]
    }

    static func buildExpression(_ expression: [NSMenuItem]) -> [NSMenuItem] {
        expression
    }

    static func buildOptional(_ component: [NSMenuItem]?) -> [NSMenuItem] {
        component ?? []
    }

    static func buildEither(first component: [NSMenuItem]) -> [NSMenuItem] {
        component
    }

    static func buildEither(second component: [NSMenuItem]) -> [NSMenuItem] {
        component
    }
}

// MARK: - Menu Item Helpers

enum MenuItems {
    static func button(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) -> NSMenuItem {
        let item = CallbackMenuItem(title: title, callback: action)
        if let systemImage, let image = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil) {
            item.image = image
        }
        return item
    }

    static func destructiveButton(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) -> NSMenuItem {
        let item = CallbackMenuItem(title: title, callback: action)
        let image: NSImage? = systemImage.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
        if let image {
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
            item.image = image.withSymbolConfiguration(config)
        }
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.foregroundColor: NSColor.systemRed]
        )
        return item
    }

    static func submenu(_ title: String, systemImage: String? = nil, @RightClickMenuBuilder items: () -> [NSMenuItem]) -> NSMenuItem {
        let sub = NSMenu()
        for item in items() {
            sub.addItem(item)
        }
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = sub
        if let systemImage, let image = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil) {
            item.image = image
        }
        return item
    }

    static func divider() -> NSMenuItem {
        .separator()
    }
}

// MARK: - Callback Menu Item

private class CallbackMenuItem: NSMenuItem {
    private let callback: () -> Void

    init(title: String, callback: @escaping () -> Void) {
        self.callback = callback
        super.init(title: title, action: #selector(performAction), keyEquivalent: "")
        self.target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError()
    }

    @objc private func performAction() {
        callback()
    }
}

// MARK: - NSView Representable

private struct RightClickMenuRepresentable: NSViewRepresentable {
    let menu: NSMenu
    let onShow: () -> Void
    let onDismiss: () -> Void

    func makeNSView(context: Context) -> RightClickMenuView {
        let view = RightClickMenuView()
        view.menu = menu
        view.onShow = onShow
        view.onDismiss = onDismiss
        return view
    }

    func updateNSView(_ nsView: RightClickMenuView, context: Context) {
        nsView.menu = menu
        nsView.onShow = onShow
        nsView.onDismiss = onDismiss
    }
}

// MARK: - AppKit View

private class RightClickMenuView: NSView {
    var onShow: (() -> Void)?
    var onDismiss: (() -> Void)?
    private var dismissObserver: NSObjectProtocol?

    // Only intercept right-clicks; pass all other events through to SwiftUI
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let currentEvent = NSApp.currentEvent else { return nil }
        switch currentEvent.type {
        case .rightMouseDown, .rightMouseUp, .rightMouseDragged:
            return super.hitTest(point)
        default:
            return nil
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu else { return }

        onShow?()

        // Observe menu dismissal
        dismissObserver = NotificationCenter.default.addObserver(
            forName: NSMenu.didEndTrackingNotification,
            object: menu,
            queue: .main
        ) { [weak self] _ in
            self?.onDismiss?()
            if let observer = self?.dismissObserver {
                NotificationCenter.default.removeObserver(observer)
                self?.dismissObserver = nil
            }
        }

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    deinit {
        if let observer = dismissObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - NSMenu Button (replaces SwiftUI Menu for proper destructive styling)

struct NSMenuButton: NSViewRepresentable {
    let systemImage: String
    let imageSize: CGFloat
    let imageWeight: NSFont.Weight
    let tintColor: NSColor?
    let menu: NSMenu

    init(
        systemImage: String,
        imageSize: CGFloat = 14,
        imageWeight: NSFont.Weight = .regular,
        tintColor: NSColor? = nil,
        @RightClickMenuBuilder items: () -> [NSMenuItem]
    ) {
        self.systemImage = systemImage
        self.imageSize = imageSize
        self.imageWeight = imageWeight
        self.tintColor = tintColor
        let menu = NSMenu()
        for item in items() {
            menu.addItem(item)
        }
        self.menu = menu
    }

    func makeNSView(context: Context) -> NSMenuButtonView {
        let view = NSMenuButtonView()
        view.configure(systemImage: systemImage, imageSize: imageSize, imageWeight: imageWeight, tintColor: tintColor, menu: menu)
        return view
    }

    func updateNSView(_ nsView: NSMenuButtonView, context: Context) {
        nsView.configure(systemImage: systemImage, imageSize: imageSize, imageWeight: imageWeight, tintColor: tintColor, menu: menu)
    }
}

class NSMenuButtonView: NSView {
    private let imageView = NSImageView()
    private var popupMenu: NSMenu?
    private var trackingArea: NSTrackingArea?
    private var isHovered = false {
        didSet { updateAppearance() }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        wantsLayer = true
        layer?.cornerRadius = 4
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(systemImage: String, imageSize: CGFloat, imageWeight: NSFont.Weight, tintColor: NSColor?, menu: NSMenu) {
        let config = NSImage.SymbolConfiguration(pointSize: imageSize, weight: imageWeight)
        if let image = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) {
            imageView.image = image
        }
        imageView.contentTintColor = tintColor ?? .secondaryLabelColor
        popupMenu = menu
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self)
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }

    private func updateAppearance() {
        layer?.backgroundColor = isHovered
            ? NSColor.labelColor.withAlphaComponent(0.08).cgColor
            : nil
    }

    override func mouseDown(with event: NSEvent) {
        guard let popupMenu else { return }
        let point = NSPoint(x: 0, y: bounds.height)
        popupMenu.popUp(positioning: nil, at: point, in: self)
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 24, height: 24)
    }
}

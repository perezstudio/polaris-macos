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
    static func button(_ title: String, action: @escaping () -> Void) -> NSMenuItem {
        let item = CallbackMenuItem(title: title, callback: action)
        return item
    }

    static func destructiveButton(_ title: String, action: @escaping () -> Void) -> NSMenuItem {
        let item = CallbackMenuItem(title: title, callback: action)
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.foregroundColor: NSColor.systemRed]
        )
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

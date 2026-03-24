//
//  SettingsWindowController.swift
//  Polaris
//
//  Preferences window with NSToolbar-based tab navigation.
//

import AppKit
import SwiftUI
import SwiftData

final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    private static weak var shared: SettingsWindowController?
    private let modelContainer: ModelContainer

    enum Tab: String, CaseIterable {
        case tags

        var label: String {
            switch self {
            case .tags: return "Tags"
            }
        }

        var iconName: String {
            switch self {
            case .tags: return "tag.fill"
            }
        }
    }

    static func showSettings(modelContainer: ModelContainer) {
        if let existing = shared {
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }
        let wc = SettingsWindowController(modelContainer: modelContainer)
        shared = wc
        wc.showWindow(nil)
        wc.window?.makeKeyAndOrderFront(nil)
    }

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Settings"
        window.center()

        super.init(window: window)

        window.delegate = self

        setupToolbar()
        selectTab(.tags)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Toolbar

    private func setupToolbar() {
        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false

        if #available(macOS 13.0, *) {
            toolbar.centeredItemIdentifiers = Set(Tab.allCases.map { NSToolbarItem.Identifier($0.rawValue) })
        }

        window?.toolbar = toolbar
        window?.toolbarStyle = .preference
    }

    // MARK: - Tab Selection

    func selectTab(_ tab: Tab) {
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(tab.rawValue)
        window?.title = tab.label

        let view: AnyView
        switch tab {
        case .tags:
            view = AnyView(
                TagsSettingsView()
                    .modelContainer(modelContainer)
            )
        }

        let hostingVC = NSHostingController(rootView: view)
        window?.contentViewController = hostingVC
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        SettingsWindowController.shared = nil
    }
}

// MARK: - NSToolbarDelegate

extension SettingsWindowController: NSToolbarDelegate {

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Tab.allCases.map { NSToolbarItem.Identifier($0.rawValue) }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Tab.allCases.map { NSToolbarItem.Identifier($0.rawValue) }
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Tab.allCases.map { NSToolbarItem.Identifier($0.rawValue) }
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let tab = Tab(rawValue: itemIdentifier.rawValue) else { return nil }

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = tab.label
        item.image = NSImage(systemSymbolName: tab.iconName, accessibilityDescription: tab.label)
        item.target = self
        item.action = #selector(toolbarTabClicked(_:))
        return item
    }

    @objc private func toolbarTabClicked(_ sender: NSToolbarItem) {
        guard let tab = Tab(rawValue: sender.itemIdentifier.rawValue) else { return }
        selectTab(tab)
    }
}

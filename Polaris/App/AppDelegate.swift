//
//  AppDelegate.swift
//  Polaris
//

import AppKit
import SwiftData

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    private var windowController: MainWindowController?

    lazy var modelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: PolarisSchema.self)

        let modelConfiguration = ModelConfiguration(
            "Polaris",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: PolarisMigrationPlan.self,
                configurations: [modelConfiguration]
            )
        } catch {
            // Schema changed and the existing store can't be migrated — delete and retry
            print("⚠️ SwiftData migration failed, resetting store: \(error)")
            let storeURL = modelConfiguration.url
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
            }
            do {
                return try ModelContainer(
                    for: schema,
                    migrationPlan: PolarisMigrationPlan.self,
                    configurations: [modelConfiguration]
                )
            } catch {
                fatalError("Could not create ModelContainer after reset: \(error)")
            }
        }
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()

        let controller = MainWindowController(modelContainer: modelContainer)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        self.windowController = controller
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // MARK: - Menu

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Polaris", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Polaris", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // File menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New Task", action: #selector(MainSplitViewController.newTask(_:)), keyEquivalent: "n")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // Edit menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // View menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")

        let sidebarItem = NSMenuItem(title: "Toggle Sidebar", action: #selector(MainSplitViewController.toggleSidebarMenu(_:)), keyEquivalent: "1")
        sidebarItem.keyEquivalentModifierMask = .command
        viewMenu.addItem(sidebarItem)

        let inspectorItem = NSMenuItem(title: "Toggle Inspector", action: #selector(MainSplitViewController.toggleInspectorMenu(_:)), keyEquivalent: "i")
        inspectorItem.keyEquivalentModifierMask = .command
        viewMenu.addItem(inspectorItem)

        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func openSettings() {
        SettingsWindowController.showSettings(modelContainer: modelContainer)
    }
}

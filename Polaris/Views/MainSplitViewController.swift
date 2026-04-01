//
//  MainSplitViewController.swift
//  Polaris
//

import AppKit
import SwiftData
import SwiftUI

final class MainSplitViewController: NSSplitViewController {
    private let modelContainer: ModelContainer
    private let windowState = WindowStateModel()
    private let selectionStore = SelectionStore()

    private var sidebarItem: NSSplitViewItem!
    private var contentItem: NSSplitViewItem!
    private var inspectorItem: NSSplitViewItem!

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        splitView.dividerStyle = .thin
        splitView.isVertical = true

        setupViewControllers()
    }

    private func setupViewControllers() {
        // Sidebar
        let sidebarView = SidebarView(
            selectionStore: selectionStore,
            windowState: windowState,
            onToggleSidebar: { [weak self] in
                self?.toggleSidebar()
            }
        )
        .modelContainer(modelContainer)
        let sidebarVC = NSHostingController(rootView: sidebarView)

        sidebarItem = NSSplitViewItem(viewController: sidebarVC)
        sidebarItem.canCollapse = true
        sidebarItem.minimumThickness = 200
        sidebarItem.maximumThickness = 300
        sidebarItem.holdingPriority = .defaultLow + 1
        addSplitViewItem(sidebarItem)

        // Content — single hosting controller, SwiftUI switches between empty/detail
        let contentView = ContentAreaView(
            selectionStore: selectionStore,
            windowState: windowState,
            onToggleSidebar: { [weak self] in
                self?.toggleSidebar()
            },
            onToggleInspector: { [weak self] in
                self?.toggleInspector()
            }
        )
        .modelContainer(modelContainer)
        let contentVC = NSHostingController(rootView: contentView)

        contentItem = NSSplitViewItem(viewController: contentVC)
        contentItem.minimumThickness = 400
        contentItem.holdingPriority = .defaultLow
        addSplitViewItem(contentItem)

        // Inspector
        let inspectorView = InspectorView(
            selectionStore: selectionStore,
            onToggleInspector: { [weak self] in
                self?.toggleInspector()
            }
        )
        .modelContainer(modelContainer)
        let inspectorHC = NSHostingController(rootView: inspectorView)
        inspectorHC.sizingOptions = []

        inspectorItem = NSSplitViewItem(viewController: inspectorHC)
        inspectorItem.canCollapse = true
        inspectorItem.minimumThickness = 280
        inspectorItem.holdingPriority = .defaultLow + 1
        inspectorItem.isCollapsed = true
        addSplitViewItem(inspectorItem)

        // Observe selection for inspector expand/collapse
        setupSelectionObserver()
    }

    private func setupSelectionObserver() {
        func observeTodo() {
            withObservationTracking {
                _ = selectionStore.selectedTodo
            } onChange: { [weak self] in
                DispatchQueue.main.async {
                    self?.handleTodoSelectionChanged()
                    observeTodo()
                }
            }
        }

        observeTodo()
    }

    private func handleTodoSelectionChanged() {
        if selectionStore.selectedTodo != nil {
            expandInspectorIfNeeded()
        }
    }

    // MARK: - Panel Toggles

    func toggleSidebar() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            sidebarItem.animator().isCollapsed.toggle()
        } completionHandler: { [weak self] in
            self?.updateCollapseState()
        }
    }

    func toggleInspector() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            inspectorItem.animator().isCollapsed.toggle()
        } completionHandler: { [weak self] in
            self?.updateCollapseState()
        }
    }

    private func expandInspectorIfNeeded() {
        guard inspectorItem.isCollapsed else { return }
        toggleInspector()
    }

    private func updateCollapseState() {
        windowState.isSidebarCollapsed = sidebarItem.isCollapsed
        windowState.isInspectorCollapsed = inspectorItem.isCollapsed
    }

    // MARK: - Menu Actions

    @IBAction func toggleSidebarMenu(_ sender: Any?) {
        toggleSidebar()
    }

    @IBAction func toggleInspectorMenu(_ sender: Any?) {
        toggleInspector()
    }

    @IBAction func newTask(_ sender: Any?) {
        guard selectionStore.selectedProject != nil || selectionStore.selectedTab != nil else {
            Log.shortcut.debug("[MainSplit] newTask ignored – no project or tab selected")
            return
        }
        Log.shortcut.info("[MainSplit] newTask → addTaskRequested = true")
        selectionStore.addTaskRequested = true
    }

    @IBAction func newSection(_ sender: Any?) {
        guard selectionStore.selectedProject != nil else { return }
        selectionStore.addSectionRequested = true
    }
}

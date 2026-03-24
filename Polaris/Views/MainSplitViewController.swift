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

    private var sidebarHostingVC: NSViewController!
    private var emptyStateHostingVC: NSViewController!
    private var inspectorHostingVC: NSViewController!

    private var sidebarItem: NSSplitViewItem!
    private var contentItem: NSSplitViewItem!
    private var inspectorItem: NSSplitViewItem!

    // Track current project to avoid redundant swaps
    private var currentProjectId: PersistentIdentifier?

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
        sidebarHostingVC = NSHostingController(rootView: sidebarView)

        sidebarItem = NSSplitViewItem(viewController: sidebarHostingVC)
        sidebarItem.canCollapse = true
        sidebarItem.minimumThickness = 200
        sidebarItem.maximumThickness = 300
        sidebarItem.holdingPriority = .defaultLow + 1
        addSplitViewItem(sidebarItem)

        // Content — start with empty state
        let emptyView = EmptyStateView(windowState: windowState)
        emptyStateHostingVC = NSHostingController(rootView: emptyView)

        contentItem = NSSplitViewItem(viewController: emptyStateHostingVC)
        contentItem.minimumThickness = 400
        contentItem.holdingPriority = .defaultLow
        addSplitViewItem(contentItem)

        // Inspector
        let inspectorView = InspectorView(
            selectionStore: selectionStore,
            windowState: windowState,
            onToggleInspector: { [weak self] in
                self?.toggleInspector()
            }
        )
        .modelContainer(modelContainer)
        let inspectorHosting = NSHostingController(rootView: inspectorView)
        inspectorHosting.sizingOptions = []
        inspectorHostingVC = inspectorHosting

        inspectorItem = NSSplitViewItem(viewController: inspectorHostingVC)
        inspectorItem.canCollapse = true
        inspectorItem.minimumThickness = 280
        inspectorItem.maximumThickness = 350
        inspectorItem.holdingPriority = .defaultLow + 1
        inspectorItem.isCollapsed = true
        addSplitViewItem(inspectorItem)

        // Observe selection changes
        setupSelectionObserver()
    }

    private func setupSelectionObserver() {
        func observeProject() {
            withObservationTracking {
                _ = selectionStore.selectedProject
            } onChange: { [weak self] in
                DispatchQueue.main.async {
                    self?.handleProjectSelectionChanged()
                    observeProject()
                }
            }
        }
        observeProject()

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

    private func handleProjectSelectionChanged() {
        guard let project = selectionStore.selectedProject else {
            // No project selected — show empty state
            if currentProjectId != nil {
                currentProjectId = nil
                swapContentViewController(to: emptyStateHostingVC)
            }
            return
        }

        // Same project — do nothing
        if currentProjectId == project.persistentModelID { return }
        currentProjectId = project.persistentModelID

        // Show project detail view
        let detailView = ProjectDetailView(
            project: project,
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

        let hostingVC = NSHostingController(rootView: detailView)
        swapContentViewController(to: hostingVC)
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

    private func updateCollapseState() {
        windowState.isSidebarCollapsed = sidebarItem.isCollapsed
        windowState.isInspectorCollapsed = inspectorItem.isCollapsed
    }

    // MARK: - Content Swapping

    private func swapContentViewController(to viewController: NSViewController) {
        let currentVC = contentItem.viewController
        if currentVC === viewController { return }

        removeSplitViewItem(contentItem)

        contentItem = NSSplitViewItem(viewController: viewController)
        contentItem.minimumThickness = 400
        contentItem.holdingPriority = .defaultLow
        insertSplitViewItem(contentItem, at: 1)

        windowState.isSidebarCollapsed = sidebarItem.isCollapsed
        windowState.isInspectorCollapsed = inspectorItem.isCollapsed
    }

    func expandInspectorIfNeeded() {
        if inspectorItem.isCollapsed {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.allowsImplicitAnimation = true
                inspectorItem.animator().isCollapsed = false
            } completionHandler: { [weak self] in
                self?.updateCollapseState()
            }
        }
    }

    func collapseInspectorIfNeeded() {
        if !inspectorItem.isCollapsed {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.allowsImplicitAnimation = true
                inspectorItem.animator().isCollapsed = true
            } completionHandler: { [weak self] in
                self?.updateCollapseState()
            }
        }
    }

    // MARK: - Menu Actions

    @IBAction func toggleSidebarMenu(_ sender: Any?) {
        toggleSidebar()
    }

    @IBAction func toggleInspectorMenu(_ sender: Any?) {
        toggleInspector()
    }

    @IBAction func newTask(_ sender: Any?) {
        guard let project = selectionStore.selectedProject else { return }
        let modelContext = ModelContext(modelContainer)
        let todo = Todo(title: "", sortOrder: project.todos.count)
        todo.project = project
        modelContext.insert(todo)
        try? modelContext.save()
        selectionStore.selectedTodo = todo
    }
}

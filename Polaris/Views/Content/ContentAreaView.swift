//
//  ContentAreaView.swift
//  Polaris
//
//  Wraps empty state, project detail, and tab views, switching based on selectionStore.

import SwiftUI

struct ContentAreaView: View {
    let selectionStore: SelectionStore
    let windowState: WindowStateModel
    var onToggleSidebar: (() -> Void)?
    var onToggleInspector: (() -> Void)?

    var body: some View {
        if let tab = selectionStore.selectedTab {
            tabContentView(for: tab)
        } else if let project = selectionStore.selectedProject {
            ProjectDetailView(
                project: project,
                selectionStore: selectionStore,
                windowState: windowState,
                onToggleSidebar: onToggleSidebar,
                onToggleInspector: onToggleInspector
            )
        } else {
            EmptyStateView(windowState: windowState)
        }
    }

    @ViewBuilder
    private func tabContentView(for tab: SidebarTab) -> some View {
        switch tab {
        case .inbox:
            InboxView(
                selectionStore: selectionStore,
                windowState: windowState,
                onToggleSidebar: onToggleSidebar,
                onToggleInspector: onToggleInspector
            )
        case .today:
            TodayView(
                selectionStore: selectionStore,
                windowState: windowState,
                onToggleSidebar: onToggleSidebar,
                onToggleInspector: onToggleInspector
            )
        case .scheduled:
            ScheduledView(
                selectionStore: selectionStore,
                windowState: windowState,
                onToggleSidebar: onToggleSidebar,
                onToggleInspector: onToggleInspector
            )
        case .allTasks:
            AllTasksView(
                selectionStore: selectionStore,
                windowState: windowState,
                onToggleSidebar: onToggleSidebar,
                onToggleInspector: onToggleInspector
            )
        case .logbook:
            LogbookView(
                selectionStore: selectionStore,
                windowState: windowState,
                onToggleSidebar: onToggleSidebar,
                onToggleInspector: onToggleInspector
            )
        }
    }
}

//
//  ContentAreaView.swift
//  Polaris
//
//  Wraps empty state and project detail, switching based on selectionStore.

import SwiftUI

struct ContentAreaView: View {
    let selectionStore: SelectionStore
    let windowState: WindowStateModel
    var onToggleSidebar: (() -> Void)?
    var onToggleInspector: (() -> Void)?

    var body: some View {
        if let project = selectionStore.selectedProject {
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
}

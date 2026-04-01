//
//  SelectionStore.swift
//  Polaris
//
//  Holds the current selection state shared across sidebar and content panels.
//

import Foundation
import SwiftUI
import SwiftData

enum SidebarTab: String, CaseIterable {
    case inbox
    case today
    case scheduled
    case allTasks
    case logbook

    var title: String {
        switch self {
        case .inbox: "Inbox"
        case .today: "Today"
        case .scheduled: "Scheduled"
        case .allTasks: "All Tasks"
        case .logbook: "Logbook"
        }
    }

    var icon: String {
        switch self {
        case .inbox: "tray.fill"
        case .today: "star.fill"
        case .scheduled: "calendar"
        case .allTasks: "checklist"
        case .logbook: "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .inbox: .blue
        case .today: .yellow
        case .scheduled: .red
        case .allTasks: .teal
        case .logbook: .green
        }
    }
}

@MainActor @Observable
final class SelectionStore {
    var selectedProject: Project? {
        didSet {
            if selectedProject != nil {
                Log.focus.info("[SelectionStore] selectedProject set → clearing tab & todo")
                selectedTab = nil
                selectedTodo = nil
                selectedTodoIDs.removeAll()
                anchorTodoID = nil
            }
        }
    }

    var selectedTab: SidebarTab? {
        didSet {
            if let tab = selectedTab {
                Log.focus.info("[SelectionStore] selectedTab set to \(tab.rawValue) → clearing project & todo")
                selectedProject = nil
                selectedTodo = nil
                selectedTodoIDs.removeAll()
                anchorTodoID = nil
            }
        }
    }

    var selectedTodo: Todo? {
        didSet {
            if let todo = selectedTodo {
                Log.focus.debug("[SelectionStore] selectedTodo set – ID: \(todo.persistentModelID.hashValue)")
            } else if oldValue != nil {
                Log.focus.debug("[SelectionStore] selectedTodo cleared (was ID: \(oldValue!.persistentModelID.hashValue))")
            }
        }
    }

    /// All currently selected todo IDs (for multi-select)
    var selectedTodoIDs: Set<PersistentIdentifier> = []

    /// Anchor for shift-click range selection
    var anchorTodoID: PersistentIdentifier?

    var addTaskRequested = false
    var addSectionRequested = false

    // MARK: - Multi-Selection Helpers

    /// Select a single todo, clearing any multi-selection
    func selectSingle(_ todo: Todo) {
        let id = todo.persistentModelID
        selectedTodo = todo
        selectedTodoIDs = [id]
        anchorTodoID = id
    }

    /// Extend selection from anchor to target (shift-click)
    func extendSelection(to todo: Todo, in orderedList: [Todo]) {
        let targetId = todo.persistentModelID
        guard let anchorId = anchorTodoID,
              let anchorIndex = orderedList.firstIndex(where: { $0.persistentModelID == anchorId }),
              let targetIndex = orderedList.firstIndex(where: { $0.persistentModelID == targetId })
        else {
            selectSingle(todo)
            return
        }

        let range = min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)
        selectedTodoIDs = Set(orderedList[range].map(\.persistentModelID))
        selectedTodo = todo
        // anchorTodoID stays unchanged
    }

    /// Extend selection by one step (shift+arrow)
    func extendSelectionStep(to todo: Todo) {
        let id = todo.persistentModelID
        selectedTodoIDs.insert(id)
        selectedTodo = todo
        // anchorTodoID stays unchanged
    }

    /// Check if a todo is part of the current selection
    func isSelected(_ todo: Todo) -> Bool {
        selectedTodoIDs.contains(todo.persistentModelID)
    }

    /// Clear all selection state
    func clearSelection() {
        selectedTodo = nil
        selectedTodoIDs.removeAll()
        anchorTodoID = nil
    }
}

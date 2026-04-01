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
            }
        }
    }

    var selectedTab: SidebarTab? {
        didSet {
            if let tab = selectedTab {
                Log.focus.info("[SelectionStore] selectedTab set to \(tab.rawValue) → clearing project & todo")
                selectedProject = nil
                selectedTodo = nil
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
    var addTaskRequested = false
    var addSectionRequested = false
}

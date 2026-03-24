//
//  SelectionStore.swift
//  Polaris
//
//  Holds the current selection state shared across sidebar, content, and inspector panels.
//

import Foundation
import SwiftData

@MainActor @Observable
final class SelectionStore {
    var selectedProject: Project?
    var selectedTodo: Todo?
}

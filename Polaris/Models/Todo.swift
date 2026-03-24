//
//  Todo.swift
//  Polaris
//

import Foundation
import SwiftData

enum Priority: Int, Codable, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
    case urgent = 3

    var label: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .urgent: "Urgent"
        }
    }

    var color: String {
        switch self {
        case .low: "gray"
        case .medium: "blue"
        case .high: "orange"
        case .urgent: "red"
        }
    }
}

@Model
final class Todo {
    var title: String
    var note: String
    var isCompleted: Bool
    var dueDate: Date?
    var deadlineDate: Date?
    var priorityRawValue: Int
    var createdAt: Date
    var sortOrder: Int

    var project: Project?

    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.todo)
    var checklistItems: [ChecklistItem] = []

    @Relationship(inverse: \Tag.todos)
    var tags: [Tag] = []

    var priority: Priority {
        get { Priority(rawValue: priorityRawValue) ?? .medium }
        set { priorityRawValue = newValue.rawValue }
    }

    init(
        title: String,
        note: String = "",
        isCompleted: Bool = false,
        priority: Priority = .medium,
        sortOrder: Int = 0
    ) {
        self.title = title
        self.note = note
        self.isCompleted = isCompleted
        self.priorityRawValue = priority.rawValue
        self.createdAt = Date()
        self.sortOrder = sortOrder
    }
}

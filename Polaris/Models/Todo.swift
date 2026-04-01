//
//  Todo.swift
//  Polaris
//

import Foundation
import SwiftData

enum Priority: Int, Codable, CaseIterable {
    case none = -1
    case low = 0
    case medium = 1
    case high = 2
    case urgent = 3

    var label: String {
        switch self {
        case .none: "None"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .urgent: "Urgent"
        }
    }

    var color: String {
        switch self {
        case .none: "gray"
        case .low: "green"
        case .medium: "yellow"
        case .high: "orange"
        case .urgent: "red"
        }
    }

    var variableValue: Double {
        switch self {
        case .none: 0.0
        case .low: 0.25
        case .medium: 0.5
        case .high: 0.75
        case .urgent: 1.0
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
    var completedAt: Date?
    var priorityRawValue: Int
    var createdAt: Date
    var sortOrder: Int

    var project: Project?
    var section: Section?

    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.todo)
    var checklistItems: [ChecklistItem] = []

    @Relationship(inverse: \Tag.todos)
    var tags: [Tag] = []

    var priority: Priority {
        get { Priority(rawValue: priorityRawValue) ?? .none }
        set { priorityRawValue = newValue.rawValue }
    }

    var isToday: Bool {
        let calendar = Calendar.current
        let endOfToday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date())!)
        if let due = dueDate, due < endOfToday { return true }
        if let deadline = deadlineDate, deadline < endOfToday { return true }
        return false
    }

    func toggleCompletion() {
        isCompleted.toggle()
        completedAt = isCompleted ? Date() : nil
    }

    var effectiveDate: Date? {
        switch (dueDate, deadlineDate) {
        case let (due?, deadline?): return min(due, deadline)
        case let (due?, nil): return due
        case let (nil, deadline?): return deadline
        case (nil, nil): return nil
        }
    }

    init(
        title: String,
        note: String = "",
        isCompleted: Bool = false,
        priority: Priority = .none,
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

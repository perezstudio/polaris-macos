//
//  Project.swift
//  Polaris
//

import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var note: String
    var icon: String
    var color: String
    var createdAt: Date
    var sortOrder: Int

    @Relationship(deleteRule: .cascade, inverse: \Todo.project)
    var todos: [Todo] = []

    @Relationship(deleteRule: .cascade, inverse: \Tag.project)
    var tags: [Tag] = []

    init(name: String, note: String = "", icon: String = "folder.fill", color: String? = nil, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.note = note
        self.icon = icon
        self.color = color ?? ProjectColor.random.rawValue
        self.createdAt = Date()
        self.sortOrder = sortOrder
    }
}

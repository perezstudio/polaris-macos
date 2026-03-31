//
//  Section.swift
//  Polaris
//

import Foundation
import SwiftData

@Model
final class Section {
    @Attribute(.unique) var id: UUID
    var name: String
    var color: String
    var sortOrder: Int
    var isCollapsed: Bool
    var createdAt: Date

    var project: Project?

    @Relationship(deleteRule: .cascade, inverse: \Todo.section)
    var todos: [Todo] = []

    init(name: String, color: String = "blue", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.color = color
        self.sortOrder = sortOrder
        self.isCollapsed = false
        self.createdAt = Date()
    }
}

//
//  Project.swift
//  Polaris
//

import Foundation
import SwiftData

@Model
final class Project {
    var name: String
    var note: String
    var icon: String
    var color: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Todo.project)
    var todos: [Todo] = []

    @Relationship(deleteRule: .cascade, inverse: \Tag.project)
    var tags: [Tag] = []

    init(name: String, note: String = "", icon: String = "folder.fill", color: String = "blue") {
        self.name = name
        self.note = note
        self.icon = icon
        self.color = color
        self.createdAt = Date()
    }
}

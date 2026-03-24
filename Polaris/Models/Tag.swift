//
//  Tag.swift
//  Polaris
//

import Foundation
import SwiftData

@Model
final class Tag {
    var name: String
    var color: String

    var project: Project?
    var todos: [Todo] = []

    init(name: String, color: String = "gray") {
        self.name = name
        self.color = color
    }
}

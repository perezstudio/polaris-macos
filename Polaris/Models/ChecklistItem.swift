//
//  ChecklistItem.swift
//  Polaris
//

import Foundation
import SwiftData

@Model
final class ChecklistItem {
    var title: String
    var isCompleted: Bool
    var sortOrder: Int

    var todo: Todo?

    init(title: String, isCompleted: Bool = false, sortOrder: Int = 0) {
        self.title = title
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
    }
}

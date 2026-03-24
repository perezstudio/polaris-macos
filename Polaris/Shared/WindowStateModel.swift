//
//  WindowStateModel.swift
//  Polaris
//
//  Shared observable state for window-level layout information.
//  Updated by MainSplitViewController, observed by SwiftUI views.
//

import Foundation

@Observable
final class WindowStateModel {
    var isSidebarCollapsed: Bool = false
    var isInspectorCollapsed: Bool = false
}

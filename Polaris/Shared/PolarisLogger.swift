//
//  PolarisLogger.swift
//  Polaris
//
//  Unified logging for debugging focus, editing, and shortcut issues.
//  View logs in Console.app → filter by subsystem "com.polaris.app"
//

import Foundation
@_exported import os

enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.polaris.app"

    static let focus    = Logger(subsystem: subsystem, category: "focus")
    static let editing  = Logger(subsystem: subsystem, category: "editing")
    static let shortcut = Logger(subsystem: subsystem, category: "shortcut")
    static let data     = Logger(subsystem: subsystem, category: "data")
    static let view     = Logger(subsystem: subsystem, category: "view")
}

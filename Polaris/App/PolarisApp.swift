//
//  PolarisApp.swift
//  Polaris
//

import SwiftUI

@main
struct PolarisApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

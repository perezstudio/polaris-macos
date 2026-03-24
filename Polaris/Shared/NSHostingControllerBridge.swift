//
//  NSHostingControllerBridge.swift
//  Polaris
//
//  Convenience wrapper for hosting SwiftUI views in AppKit containers
//  with transparent background and proper sizing.
//

import AppKit
import SwiftUI

func hostSwiftUI<V: View>(_ view: V) -> NSHostingController<V> {
    let controller = NSHostingController(rootView: view)
    controller.sizingOptions = [.preferredContentSize]
    controller.view.wantsLayer = true
    controller.view.layer?.backgroundColor = .clear
    return controller
}

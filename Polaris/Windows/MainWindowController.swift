//
//  MainWindowController.swift
//  Polaris
//

import AppKit
import SwiftData

final class MainWindowController: NSWindowController {
    private let modelContainer: ModelContainer
    private var splitViewController: MainSplitViewController?

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .windowBackgroundColor
        window.minSize = NSSize(width: 900, height: 600)
        window.setFrameAutosaveName("PolarisMainWindow")
        window.center()
        window.titlebarSeparatorStyle = .none

        super.init(window: window)

        window.delegate = self
        setupContentViewController()

        DispatchQueue.main.async { [weak self] in
            self?.constrainWindowToScreen()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContentViewController() {
        let splitVC = MainSplitViewController(modelContainer: modelContainer)
        self.splitViewController = splitVC

        guard let contentView = window?.contentView else { return }
        splitVC.view.frame = contentView.bounds
        splitVC.view.autoresizingMask = [.width, .height]
        contentView.addSubview(splitVC.view)
    }

    // MARK: - Public API

    func toggleSidebar() {
        splitViewController?.toggleSidebar()
    }

    func toggleInspector() {
        splitViewController?.toggleInspector()
    }
}

// MARK: - NSWindowDelegate

extension MainWindowController: NSWindowDelegate {

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        guard let screen = sender.screen ?? NSScreen.main else { return frameSize }
        let visibleFrame = screen.visibleFrame
        var size = frameSize
        if size.height > visibleFrame.height {
            size.height = visibleFrame.height
        }
        if size.width > visibleFrame.width {
            size.width = visibleFrame.width
        }
        return size
    }

    private func constrainWindowToScreen() {
        guard let window = window,
              let screen = window.screen ?? NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        var frame = window.frame
        var needsAdjust = false

        if frame.size.height > visibleFrame.height {
            frame.size.height = visibleFrame.height
            needsAdjust = true
        }
        if frame.size.width > visibleFrame.width {
            frame.size.width = visibleFrame.width
            needsAdjust = true
        }
        if frame.origin.y < visibleFrame.origin.y {
            frame.origin.y = visibleFrame.origin.y
            needsAdjust = true
        }
        if frame.maxY > visibleFrame.maxY {
            frame.origin.y = visibleFrame.maxY - frame.size.height
            needsAdjust = true
        }

        if needsAdjust {
            window.setFrame(frame, display: true)
        }
    }
}

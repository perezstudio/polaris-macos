//
//  AppSettings.swift
//  Polaris
//

import AppKit
import SwiftUI

@MainActor @Observable
final class AppSettings {
    static let shared = AppSettings()

    enum AppearanceMode: String, CaseIterable {
        case system
        case light
        case dark
    }

    var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
            applyAppearance()
        }
    }

    var textSizeScale: CGFloat {
        didSet {
            UserDefaults.standard.set(textSizeScale, forKey: "textSizeScale")
        }
    }

    private init() {
        let modeString = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
        self.appearanceMode = AppearanceMode(rawValue: modeString) ?? .system

        let savedScale = UserDefaults.standard.double(forKey: "textSizeScale")
        self.textSizeScale = savedScale > 0 ? CGFloat(savedScale) : 1.0
    }

    func applyAppearance() {
        switch appearanceMode {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    func scaledSize(_ baseSize: CGFloat) -> CGFloat {
        baseSize * textSizeScale
    }
}

// MARK: - SwiftUI Font Extension

extension Font {
    static func appScaled(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .system(size: AppSettings.shared.scaledSize(size), weight: weight, design: design)
    }
}

// MARK: - NSFont Extension

extension NSFont {
    static func appScaled(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        .systemFont(ofSize: AppSettings.shared.scaledSize(size), weight: weight)
    }

    static func appScaledMonospaced(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        .monospacedSystemFont(ofSize: AppSettings.shared.scaledSize(size), weight: weight)
    }
}

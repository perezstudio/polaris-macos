//
//  ProjectColor.swift
//  Polaris
//

import SwiftUI

enum ProjectColor: String, CaseIterable, Codable {
    case red
    case orange
    case yellow
    case green
    case mint
    case teal
    case cyan
    case blue
    case indigo
    case purple
    case pink
    case brown
    case gray

    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .cyan: .cyan
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .brown: .brown
        case .gray: .gray
        }
    }

    var label: String {
        rawValue.capitalized
    }

    static var random: ProjectColor {
        allCases.randomElement() ?? .blue
    }
}

extension Color {
    static func fromString(_ string: String) -> Color {
        (ProjectColor(rawValue: string.lowercased()) ?? .blue).color
    }
}

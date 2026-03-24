//
//  EmptyStateView.swift
//  Polaris
//

import SwiftUI

struct EmptyStateView: View {
    let windowState: WindowStateModel

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)

            Text("Select a Project")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Choose a project from the sidebar to view its tasks.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.polarisWindowBackground)
        .ignoresSafeArea(edges: .top)
    }
}

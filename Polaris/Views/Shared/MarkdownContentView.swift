//
//  MarkdownContentView.swift
//  Polaris
//
//  Self-sizing NSTextView that renders markdown via MarkdownRenderer.
//  No NSScrollView wrapper — designed to be placed inside a SwiftUI ScrollView.
//

import SwiftUI

struct MarkdownContentView: NSViewRepresentable {
    let markdown: String
    let baseFontSize: CGFloat

    init(_ markdown: String, baseFontSize: CGFloat = 12) {
        self.markdown = markdown
        self.baseFontSize = baseFontSize
    }

    func makeNSView(context: Context) -> SelfSizingTextView {
        let textView = SelfSizingTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)

        let renderer = MarkdownRenderer(baseFontSize: baseFontSize)
        textView.textStorage?.setAttributedString(renderer.render(markdown))

        return textView
    }

    func updateNSView(_ textView: SelfSizingTextView, context: Context) {
        let renderer = MarkdownRenderer(baseFontSize: baseFontSize)
        textView.textStorage?.setAttributedString(renderer.render(markdown))
        textView.invalidateIntrinsicContentSize()
    }
}

final class SelfSizingTextView: NSTextView {
    override var intrinsicContentSize: NSSize {
        guard let container = textContainer, let layoutManager = layoutManager else {
            return super.intrinsicContentSize
        }
        layoutManager.ensureLayout(for: container)
        let rect = layoutManager.usedRect(for: container)
        return NSSize(width: NSView.noIntrinsicMetric, height: ceil(rect.height))
    }

    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
    }

    override func layout() {
        super.layout()
        invalidateIntrinsicContentSize()
    }
}

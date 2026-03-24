//
//  LiveMarkdownEditor.swift
//  Polaris
//
//  Editable NSTextView that applies markdown formatting to raw text in place.
//  Syntax markers remain in the text but lines are styled live (headings get
//  larger fonts, bold text renders bold, etc.) — similar to Notion's editing
//  experience.
//

import SwiftUI
import AppKit

struct LiveMarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    let baseFontSize: CGFloat
    let maxContentWidth: CGFloat?

    init(text: Binding<String>, baseFontSize: CGFloat = 12, maxContentWidth: CGFloat? = nil) {
        self._text = text
        self.baseFontSize = baseFontSize
        self.maxContentWidth = maxContentWidth
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = .init(top: 0, left: 0, bottom: 0, right: 0)

        let textView = MarkdownTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isRichText = false
        textView.usesFontPanel = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 16, height: 32)
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]
        textView.maxContentWidth = maxContentWidth

        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        scrollView.documentView = textView

        // Set initial text and apply styling
        textView.string = text
        applyMarkdownStyling(to: textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? MarkdownTextView else { return }

        // Only update if the text changed externally (not from user typing)
        if textView.string != text && !context.coordinator.isUpdating {
            context.coordinator.isUpdating = true
            textView.string = text
            applyMarkdownStyling(to: textView)
            context.coordinator.isUpdating = false
        }
    }

    // MARK: - Markdown Styling

    static func applyMarkdownStyling(to textView: NSTextView, baseFontSize: CGFloat) {
        guard let textStorage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)
        let content = textStorage.string

        let scaled = AppSettings.shared.scaledSize(baseFontSize)
        let bodyFont = NSFont.systemFont(ofSize: scaled)
        let boldFont = NSFont.systemFont(ofSize: scaled, weight: .semibold)
        let italicFont: NSFont = {
            let descriptor = NSFont.systemFont(ofSize: scaled).fontDescriptor.withSymbolicTraits(.italic)
            return NSFont(descriptor: descriptor, size: scaled) ?? NSFont.systemFont(ofSize: scaled)
        }()
        let codeFont = NSFont.monospacedSystemFont(ofSize: scaled - 1, weight: .regular)
        let h1Font = NSFont.systemFont(ofSize: scaled + 4, weight: .bold)
        let h2Font = NSFont.systemFont(ofSize: scaled + 2, weight: .bold)
        let h3Font = NSFont.systemFont(ofSize: scaled + 1, weight: .semibold)
        let textColor = NSColor.labelColor
        let syntaxColor = NSColor.tertiaryLabelColor
        let codeBlockBgColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.1)

        // Reset to body style
        textStorage.beginEditing()
        textStorage.setAttributes([
            .font: bodyFont,
            .foregroundColor: textColor
        ], range: fullRange)

        let lines = content.components(separatedBy: "\n")
        var lineStart = 0
        var inCodeBlock = false

        for line in lines {
            let lineLength = (line as NSString).length
            let lineRange = NSRange(location: lineStart, length: lineLength)

            // Code block fences
            if line.hasPrefix("```") {
                textStorage.addAttributes([
                    .font: codeFont,
                    .foregroundColor: syntaxColor
                ], range: lineRange)

                inCodeBlock.toggle()
                lineStart += lineLength + 1
                continue
            }

            // Lines inside a code block
            if inCodeBlock {
                textStorage.addAttributes([
                    .font: codeFont,
                    .backgroundColor: codeBlockBgColor
                ], range: lineRange)
                lineStart += lineLength + 1
                continue
            }

            // Headers
            if line.hasPrefix("### ") {
                textStorage.addAttribute(.font, value: h3Font, range: lineRange)
                let markerRange = NSRange(location: lineStart, length: 4)
                textStorage.addAttribute(.foregroundColor, value: syntaxColor, range: markerRange)
            } else if line.hasPrefix("## ") {
                textStorage.addAttribute(.font, value: h2Font, range: lineRange)
                let markerRange = NSRange(location: lineStart, length: 3)
                textStorage.addAttribute(.foregroundColor, value: syntaxColor, range: markerRange)
            } else if line.hasPrefix("# ") {
                textStorage.addAttribute(.font, value: h1Font, range: lineRange)
                let markerRange = NSRange(location: lineStart, length: 2)
                textStorage.addAttribute(.foregroundColor, value: syntaxColor, range: markerRange)
            }

            // Bullet points
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                let markerRange = NSRange(location: lineStart, length: 2)
                textStorage.addAttribute(.foregroundColor, value: syntaxColor, range: markerRange)
            }

            // Numbered lists (e.g. "1. ", "12. ")
            if let match = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                let markerLength = line.distance(from: line.startIndex, to: match.upperBound)
                let markerRange = NSRange(location: lineStart, length: markerLength)
                textStorage.addAttribute(.foregroundColor, value: syntaxColor, range: markerRange)
            }

            // Inline formatting within this line
            let nsLine = line as NSString

            // Bold **text**
            applyInlinePattern(
                in: textStorage,
                text: nsLine,
                lineOffset: lineStart,
                pattern: "\\*\\*(.+?)\\*\\*",
                contentFont: boldFont,
                markerColor: syntaxColor
            )

            // Italic *text* (not **)
            applyInlinePattern(
                in: textStorage,
                text: nsLine,
                lineOffset: lineStart,
                pattern: "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)",
                contentFont: italicFont,
                markerColor: syntaxColor
            )

            // Inline code `text`
            applyInlinePattern(
                in: textStorage,
                text: nsLine,
                lineOffset: lineStart,
                pattern: "`([^`]+)`",
                contentFont: codeFont,
                markerColor: syntaxColor
            )

            lineStart += lineLength + 1 // +1 for newline
        }

        textStorage.endEditing()
    }

    private static func applyInlinePattern(
        in textStorage: NSTextStorage,
        text: NSString,
        lineOffset: Int,
        pattern: String,
        contentFont: NSFont,
        markerColor: NSColor
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let lineRange = NSRange(location: 0, length: text.length)

        regex.enumerateMatches(in: text as String, range: lineRange) { match, _, _ in
            guard let match else { return }
            let fullRange = NSRange(location: lineOffset + match.range.location, length: match.range.length)

            // Apply font to the full match (including markers)
            textStorage.addAttribute(.font, value: contentFont, range: fullRange)

            // Color the markers (first and last characters of the match vs the content group)
            if match.numberOfRanges > 1 {
                let contentRange = match.range(at: 1)
                let markerStart = NSRange(
                    location: lineOffset + match.range.location,
                    length: contentRange.location - match.range.location
                )
                let markerEnd = NSRange(
                    location: lineOffset + contentRange.location + contentRange.length,
                    length: (match.range.location + match.range.length) - (contentRange.location + contentRange.length)
                )
                if markerStart.length > 0 {
                    textStorage.addAttribute(.foregroundColor, value: markerColor, range: markerStart)
                }
                if markerEnd.length > 0 {
                    textStorage.addAttribute(.foregroundColor, value: markerColor, range: markerEnd)
                }
            }
        }
    }

    private func applyMarkdownStyling(to textView: NSTextView) {
        Self.applyMarkdownStyling(to: textView, baseFontSize: baseFontSize)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: LiveMarkdownEditor
        var isUpdating = false
        weak var textView: MarkdownTextView?

        init(_ parent: LiveMarkdownEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView = notification.object as? NSTextView else { return }
            isUpdating = true
            parent.text = textView.string

            // Re-apply styling preserving cursor
            let selectedRanges = textView.selectedRanges
            parent.applyMarkdownStyling(to: textView)
            textView.selectedRanges = selectedRanges

            isUpdating = false
        }
    }
}

// MARK: - MarkdownTextView

final class MarkdownTextView: NSTextView {
    var maxContentWidth: CGFloat?
    private let minHorizontalInset: CGFloat = 16

    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
    }

    override func layout() {
        super.layout()
        updateContentInsets()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateContentInsets()
    }

    private func updateContentInsets() {
        guard let maxWidth = maxContentWidth else { return }
        let viewWidth = bounds.width
        let horizontalInset = max(minHorizontalInset, (viewWidth - maxWidth) / 2)
        let currentInset = textContainerInset
        if abs(currentInset.width - horizontalInset) > 1 {
            textContainerInset = NSSize(width: horizontalInset, height: currentInset.height)
        }
    }
}

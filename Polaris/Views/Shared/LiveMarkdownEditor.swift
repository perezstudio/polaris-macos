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
    let growsVertically: Bool
    let placeholder: String?
    let compactInsets: Bool

    init(text: Binding<String>, baseFontSize: CGFloat = 12, maxContentWidth: CGFloat? = nil, growsVertically: Bool = false, placeholder: String? = nil, compactInsets: Bool = false) {
        self._text = text
        self.baseFontSize = baseFontSize
        self.maxContentWidth = maxContentWidth
        self.growsVertically = growsVertically
        self.placeholder = placeholder
        self.compactInsets = compactInsets
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = growsVertically ? GrowingScrollView() : NSScrollView()
        scrollView.hasVerticalScroller = !growsVertically
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
        textView.textContainerInset = compactInsets ? NSSize(width: 0, height: 4) : NSSize(width: 16, height: 32)
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]
        textView.maxContentWidth = maxContentWidth

        if growsVertically {
            textView.growsVertically = true
            context.coordinator.growsVertically = true
        }

        if let placeholder {
            textView.placeholderString = placeholder
        }

        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        scrollView.documentView = textView

        // Set initial text and apply styling
        textView.string = text
        applyMarkdownStyling(to: textView)

        if growsVertically {
            DispatchQueue.main.async {
                context.coordinator.updateScrollViewHeight(scrollView)
            }
        }

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
        let boldItalicFont: NSFont = {
            let descriptor = NSFont.systemFont(ofSize: scaled, weight: .semibold).fontDescriptor.withSymbolicTraits(.italic)
            return NSFont(descriptor: descriptor, size: scaled) ?? NSFont.systemFont(ofSize: scaled, weight: .semibold)
        }()
        let codeFont = NSFont.monospacedSystemFont(ofSize: scaled - 1, weight: .regular)
        let h1Font = NSFont.systemFont(ofSize: scaled + 4, weight: .bold)
        let h2Font = NSFont.systemFont(ofSize: scaled + 2, weight: .bold)
        let h3Font = NSFont.systemFont(ofSize: scaled + 1, weight: .semibold)
        let h4Font = NSFont.systemFont(ofSize: scaled, weight: .semibold)
        let h5Font = NSFont.systemFont(ofSize: scaled - 1, weight: .semibold)
        let h6Font = NSFont.systemFont(ofSize: scaled - 1, weight: .medium)
        let textColor = NSColor.labelColor
        let syntaxColor = NSColor.tertiaryLabelColor
        let codeBlockBgColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.1)
        let blockquoteColor = NSColor.secondaryLabelColor
        let highlightBgColor = NSColor.systemYellow.withAlphaComponent(0.3)
        let linkColor = NSColor.linkColor

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

            // Horizontal rules: ---, ***, ___  (with optional spaces)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.count >= 3 {
                let allDashes = trimmed.allSatisfy({ $0 == "-" || $0 == " " }) && trimmed.contains("-") && trimmed.filter({ $0 == "-" }).count >= 3
                let allStars = trimmed.allSatisfy({ $0 == "*" || $0 == " " }) && trimmed.contains("*") && trimmed.filter({ $0 == "*" }).count >= 3
                let allUnders = trimmed.allSatisfy({ $0 == "_" || $0 == " " }) && trimmed.contains("_") && trimmed.filter({ $0 == "_" }).count >= 3
                if allDashes || allStars || allUnders {
                    textStorage.addAttribute(.foregroundColor, value: syntaxColor, range: lineRange)
                    textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: lineRange)
                    lineStart += lineLength + 1
                    continue
                }
            }

            // Headers
            if line.hasPrefix("###### ") {
                textStorage.addAttribute(.font, value: h6Font, range: lineRange)
                let markerRange = NSRange(location: lineStart, length: 7)
                textStorage.addAttribute(.foregroundColor, value: syntaxColor, range: markerRange)
            } else if line.hasPrefix("##### ") {
                textStorage.addAttribute(.font, value: h5Font, range: lineRange)
                let markerRange = NSRange(location: lineStart, length: 6)
                textStorage.addAttribute(.foregroundColor, value: syntaxColor, range: markerRange)
            } else if line.hasPrefix("#### ") {
                textStorage.addAttribute(.font, value: h4Font, range: lineRange)
                let markerRange = NSRange(location: lineStart, length: 5)
                textStorage.addAttribute(.foregroundColor, value: syntaxColor, range: markerRange)
            } else if line.hasPrefix("### ") {
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

            // Blockquotes
            if line.hasPrefix("> ") || line == ">" {
                let markerLen = line.hasPrefix("> ") ? 2 : 1
                let markerRange = NSRange(location: lineStart, length: markerLen)
                textStorage.addAttribute(.foregroundColor, value: syntaxColor, range: markerRange)
                // Style the content in blockquote color
                if lineLength > markerLen {
                    let contentRange = NSRange(location: lineStart + markerLen, length: lineLength - markerLen)
                    textStorage.addAttribute(.foregroundColor, value: blockquoteColor, range: contentRange)
                }
            }

            // Task lists: - [ ] and - [x] / - [X]
            if line.hasPrefix("- [ ] ") || line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
                let markerRange = NSRange(location: lineStart, length: 6)
                textStorage.addAttribute(.foregroundColor, value: syntaxColor, range: markerRange)
            }
            // Bullet points
            else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
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

            // Bold+Italic ***text*** (must come before bold/italic)
            applyInlinePattern(
                in: textStorage,
                text: nsLine,
                lineOffset: lineStart,
                pattern: "\\*\\*\\*(.+?)\\*\\*\\*",
                contentFont: boldItalicFont,
                markerColor: syntaxColor
            )

            // Bold+Italic ___text___
            applyInlinePattern(
                in: textStorage,
                text: nsLine,
                lineOffset: lineStart,
                pattern: "___(.+?)___",
                contentFont: boldItalicFont,
                markerColor: syntaxColor
            )

            // Bold **text** (not inside ***)
            applyInlinePattern(
                in: textStorage,
                text: nsLine,
                lineOffset: lineStart,
                pattern: "(?<!\\*)\\*\\*(?!\\*)(.+?)(?<!\\*)\\*\\*(?!\\*)",
                contentFont: boldFont,
                markerColor: syntaxColor
            )

            // Bold __text__ (not inside ___)
            applyInlinePattern(
                in: textStorage,
                text: nsLine,
                lineOffset: lineStart,
                pattern: "(?<!_)__(?!_)(.+?)(?<!_)__(?!_)",
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

            // Italic _text_ (not __)
            applyInlinePattern(
                in: textStorage,
                text: nsLine,
                lineOffset: lineStart,
                pattern: "(?<!_)_(?!_)(.+?)(?<!_)_(?!_)",
                contentFont: italicFont,
                markerColor: syntaxColor
            )

            // Strikethrough ~~text~~
            applyInlineStrikethrough(
                in: textStorage,
                text: nsLine,
                lineOffset: lineStart,
                markerColor: syntaxColor
            )

            // Highlight ==text==
            applyInlineHighlight(
                in: textStorage,
                text: nsLine,
                lineOffset: lineStart,
                markerColor: syntaxColor,
                highlightColor: highlightBgColor
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

            // Links [text](url)
            applyInlineLink(
                in: textStorage,
                text: nsLine,
                lineOffset: lineStart,
                linkColor: linkColor,
                markerColor: syntaxColor
            )

            // Images ![alt](url)
            applyInlineImage(
                in: textStorage,
                text: nsLine,
                lineOffset: lineStart,
                markerColor: syntaxColor,
                linkColor: linkColor
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

    private static func applyInlineStrikethrough(
        in textStorage: NSTextStorage,
        text: NSString,
        lineOffset: Int,
        markerColor: NSColor
    ) {
        guard let regex = try? NSRegularExpression(pattern: "~~(.+?)~~") else { return }
        let lineRange = NSRange(location: 0, length: text.length)

        regex.enumerateMatches(in: text as String, range: lineRange) { match, _, _ in
            guard let match, match.numberOfRanges > 1 else { return }
            let contentRange = match.range(at: 1)
            let fullRange = NSRange(location: lineOffset + match.range.location, length: match.range.length)
            let adjustedContent = NSRange(location: lineOffset + contentRange.location, length: contentRange.length)

            // Strikethrough on the content
            textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: adjustedContent)

            // Dim the ~~ markers
            let markerStart = NSRange(location: lineOffset + match.range.location, length: 2)
            let markerEnd = NSRange(location: lineOffset + contentRange.location + contentRange.length, length: 2)
            textStorage.addAttribute(.foregroundColor, value: markerColor, range: markerStart)
            textStorage.addAttribute(.foregroundColor, value: markerColor, range: markerEnd)
        }
    }

    private static func applyInlineHighlight(
        in textStorage: NSTextStorage,
        text: NSString,
        lineOffset: Int,
        markerColor: NSColor,
        highlightColor: NSColor
    ) {
        guard let regex = try? NSRegularExpression(pattern: "==(.+?)==") else { return }
        let lineRange = NSRange(location: 0, length: text.length)

        regex.enumerateMatches(in: text as String, range: lineRange) { match, _, _ in
            guard let match, match.numberOfRanges > 1 else { return }
            let contentRange = match.range(at: 1)
            let adjustedContent = NSRange(location: lineOffset + contentRange.location, length: contentRange.length)

            textStorage.addAttribute(.backgroundColor, value: highlightColor, range: adjustedContent)

            // Dim the == markers
            let markerStart = NSRange(location: lineOffset + match.range.location, length: 2)
            let markerEnd = NSRange(location: lineOffset + contentRange.location + contentRange.length, length: 2)
            textStorage.addAttribute(.foregroundColor, value: markerColor, range: markerStart)
            textStorage.addAttribute(.foregroundColor, value: markerColor, range: markerEnd)
        }
    }

    private static func applyInlineLink(
        in textStorage: NSTextStorage,
        text: NSString,
        lineOffset: Int,
        linkColor: NSColor,
        markerColor: NSColor
    ) {
        // Matches [text](url) but not ![text](url)
        guard let regex = try? NSRegularExpression(pattern: "(?<!!)\\[([^\\]]+)\\]\\(([^)]+)\\)") else { return }
        let lineRange = NSRange(location: 0, length: text.length)

        regex.enumerateMatches(in: text as String, range: lineRange) { match, _, _ in
            guard let match, match.numberOfRanges > 2 else { return }
            let linkTextRange = match.range(at: 1)
            let urlRange = match.range(at: 2)

            // Style link text with link color and underline
            let adjustedLinkText = NSRange(location: lineOffset + linkTextRange.location, length: linkTextRange.length)
            textStorage.addAttribute(.foregroundColor, value: linkColor, range: adjustedLinkText)
            textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: adjustedLinkText)

            // Dim the brackets and parentheses
            let openBracket = NSRange(location: lineOffset + match.range.location, length: 1)
            let closeBracket = NSRange(location: lineOffset + linkTextRange.location + linkTextRange.length, length: 1)
            let openParen = NSRange(location: lineOffset + urlRange.location - 1, length: 1)
            let closeParen = NSRange(location: lineOffset + urlRange.location + urlRange.length, length: 1)
            let urlAdjusted = NSRange(location: lineOffset + urlRange.location, length: urlRange.length)

            for range in [openBracket, closeBracket, openParen, closeParen, urlAdjusted] {
                textStorage.addAttribute(.foregroundColor, value: markerColor, range: range)
            }
        }
    }

    private static func applyInlineImage(
        in textStorage: NSTextStorage,
        text: NSString,
        lineOffset: Int,
        markerColor: NSColor,
        linkColor: NSColor
    ) {
        guard let regex = try? NSRegularExpression(pattern: "!\\[([^\\]]*)\\]\\(([^)]+)\\)") else { return }
        let lineRange = NSRange(location: 0, length: text.length)

        regex.enumerateMatches(in: text as String, range: lineRange) { match, _, _ in
            guard let match, match.numberOfRanges > 2 else { return }
            let altRange = match.range(at: 1)
            let urlRange = match.range(at: 2)
            let fullRange = NSRange(location: lineOffset + match.range.location, length: match.range.length)

            // Dim the whole syntax
            textStorage.addAttribute(.foregroundColor, value: markerColor, range: fullRange)

            // Highlight alt text
            if altRange.length > 0 {
                let adjustedAlt = NSRange(location: lineOffset + altRange.location, length: altRange.length)
                textStorage.addAttribute(.foregroundColor, value: linkColor, range: adjustedAlt)
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
        var growsVertically = false
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

            if growsVertically, let scrollView = textView.enclosingScrollView {
                updateScrollViewHeight(scrollView)
            }

            isUpdating = false
        }

        func updateScrollViewHeight(_ scrollView: NSScrollView) {
            scrollView.invalidateIntrinsicContentSize()
        }
    }
}

// MARK: - GrowingScrollView

final class GrowingScrollView: NSScrollView {
    override var intrinsicContentSize: NSSize {
        guard let textView = documentView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return super.intrinsicContentSize
        }
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let inset = textView.textContainerInset
        let height = max(40, usedRect.height + inset.height * 2)
        let width = bounds.width > 0 ? bounds.width : 200
        return NSSize(width: width, height: height)
    }
}

// MARK: - MarkdownTextView

final class MarkdownTextView: NSTextView {
    var maxContentWidth: CGFloat?
    var growsVertically: Bool = false
    var placeholderString: String?
    private let minHorizontalInset: CGFloat = 16

    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
        if growsVertically {
            enclosingScrollView?.invalidateIntrinsicContentSize()
        }
        needsDisplay = true // redraw placeholder
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        needsDisplay = true
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        needsDisplay = true
        return result
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if string.isEmpty, let placeholder = placeholderString {
            let inset = textContainerInset
            let containerOrigin = NSPoint(
                x: inset.width + (textContainer?.lineFragmentPadding ?? 5),
                y: inset.height
            )
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: font?.pointSize ?? 13),
                .foregroundColor: NSColor.placeholderTextColor
            ]
            (placeholder as NSString).draw(at: containerOrigin, withAttributes: attrs)
        }
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

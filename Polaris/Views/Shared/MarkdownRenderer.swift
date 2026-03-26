//
//  MarkdownRenderer.swift
//  Polaris
//
//  Renders Markdown text as NSAttributedString for display.
//

import AppKit

final class MarkdownRenderer {

    static func cached(_ markdown: String) -> NSAttributedString {
        return MarkdownRenderer().render(markdown)
    }

    // MARK: - Fonts

    private let bodyFont: NSFont
    private let boldFont: NSFont
    private let italicFont: NSFont
    private let boldItalicFont: NSFont
    private let codeFont: NSFont
    private let h1Font: NSFont
    private let h2Font: NSFont
    private let h3Font: NSFont
    private let h4Font: NSFont
    private let h5Font: NSFont
    private let h6Font: NSFont

    init(baseFontSize: CGFloat = 14) {
        let scaled = AppSettings.shared.scaledSize(baseFontSize)
        bodyFont = .systemFont(ofSize: scaled)
        boldFont = .systemFont(ofSize: scaled, weight: .semibold)
        italicFont = {
            let descriptor = NSFont.systemFont(ofSize: scaled).fontDescriptor.withSymbolicTraits(.italic)
            return NSFont(descriptor: descriptor, size: scaled) ?? .systemFont(ofSize: scaled)
        }()
        boldItalicFont = {
            let descriptor = NSFont.systemFont(ofSize: scaled, weight: .semibold).fontDescriptor.withSymbolicTraits(.italic)
            return NSFont(descriptor: descriptor, size: scaled) ?? .systemFont(ofSize: scaled, weight: .semibold)
        }()
        codeFont = .monospacedSystemFont(ofSize: scaled - 1, weight: .regular)
        h1Font = .systemFont(ofSize: scaled + 4, weight: .bold)
        h2Font = .systemFont(ofSize: scaled + 2, weight: .bold)
        h3Font = .systemFont(ofSize: scaled + 1, weight: .semibold)
        h4Font = .systemFont(ofSize: scaled, weight: .semibold)
        h5Font = .systemFont(ofSize: scaled - 1, weight: .semibold)
        h6Font = .systemFont(ofSize: scaled - 1, weight: .medium)
    }

    // MARK: - Colors

    private let textColor: NSColor = .labelColor
    private let codeColor: NSColor = .systemPink
    private let codeBlockBackground: NSColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.3)
    private let linkColor: NSColor = .linkColor
    private let blockquoteColor: NSColor = .secondaryLabelColor
    private let blockquoteBarColor: NSColor = NSColor.separatorColor
    private let highlightColor: NSColor = NSColor.systemYellow.withAlphaComponent(0.3)

    // MARK: - Render

    func render(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let lines = markdown.components(separatedBy: "\n")
        var inCodeBlock = false
        var codeBlockContent = ""
        var codeBlockLanguage = ""

        for (index, line) in lines.enumerated() {
            if line.hasPrefix("```") {
                if inCodeBlock {
                    inCodeBlock = false
                    result.append(renderCodeBlock(codeBlockContent, language: codeBlockLanguage))
                    codeBlockContent = ""
                    codeBlockLanguage = ""
                } else {
                    inCodeBlock = true
                    codeBlockLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
                continue
            }

            if inCodeBlock {
                if !codeBlockContent.isEmpty {
                    codeBlockContent += "\n"
                }
                codeBlockContent += line
                continue
            }

            let renderedLine = renderLine(line)
            result.append(renderedLine)

            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
        }

        if inCodeBlock && !codeBlockContent.isEmpty {
            result.append(renderCodeBlock(codeBlockContent, language: codeBlockLanguage))
        }

        return result
    }

    // MARK: - Line Rendering

    private func renderLine(_ line: String) -> NSAttributedString {
        // Horizontal rules
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.count >= 3 {
            let allDashes = trimmed.allSatisfy({ $0 == "-" || $0 == " " }) && trimmed.contains("-") && trimmed.filter({ $0 == "-" }).count >= 3
            let allStars = trimmed.allSatisfy({ $0 == "*" || $0 == " " }) && trimmed.contains("*") && trimmed.filter({ $0 == "*" }).count >= 3
            let allUnders = trimmed.allSatisfy({ $0 == "_" || $0 == " " }) && trimmed.contains("_") && trimmed.filter({ $0 == "_" }).count >= 3
            if allDashes || allStars || allUnders {
                return renderHorizontalRule()
            }
        }

        // Headers
        if line.hasPrefix("###### ") {
            return renderHeader(String(line.dropFirst(7)), level: 6)
        } else if line.hasPrefix("##### ") {
            return renderHeader(String(line.dropFirst(6)), level: 5)
        } else if line.hasPrefix("#### ") {
            return renderHeader(String(line.dropFirst(5)), level: 4)
        } else if line.hasPrefix("### ") {
            return renderHeader(String(line.dropFirst(4)), level: 3)
        } else if line.hasPrefix("## ") {
            return renderHeader(String(line.dropFirst(3)), level: 2)
        } else if line.hasPrefix("# ") {
            return renderHeader(String(line.dropFirst(2)), level: 1)
        }

        // Blockquotes
        if line.hasPrefix("> ") {
            return renderBlockquote(String(line.dropFirst(2)))
        } else if line == ">" {
            return renderBlockquote("")
        }

        // Task lists
        if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
            return renderTaskItem(String(line.dropFirst(6)), checked: true)
        } else if line.hasPrefix("- [ ] ") {
            return renderTaskItem(String(line.dropFirst(6)), checked: false)
        }

        // Bullet points
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") || line.hasPrefix("• ") {
            return renderBulletPoint(String(line.dropFirst(2)))
        }

        // Numbered lists
        if let match = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
            let content = String(line[match.upperBound...])
            let number = String(line[..<match.upperBound])
            return renderNumberedItem(content, prefix: number)
        }

        // Tables — detect by leading pipe
        // (Tables are multi-line, handled separately if needed; single-line pipe rendering)
        if line.hasPrefix("|") && line.hasSuffix("|") {
            return renderTableRow(line)
        }

        return renderInlineFormatting(line)
    }

    private func renderHeader(_ text: String, level: Int) -> NSAttributedString {
        let font: NSFont
        switch level {
        case 1: font = h1Font
        case 2: font = h2Font
        case 3: font = h3Font
        case 4: font = h4Font
        case 5: font = h5Font
        default: font = h6Font
        }

        let result = NSMutableAttributedString()
        // Render inline formatting within headers
        let content = renderInlineFormatting(text, baseFont: font)
        result.append(content)
        // Override the font for the whole header (inline formatting already applied specific styles)
        result.addAttribute(.font, value: font, range: NSRange(location: 0, length: result.length))
        return result
    }

    private func renderBlockquote(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let bar = NSAttributedString(string: "  ┃ ", attributes: [
            .font: bodyFont,
            .foregroundColor: blockquoteBarColor
        ])
        result.append(bar)

        let content = renderInlineFormatting(text)
        let mutableContent = NSMutableAttributedString(attributedString: content)
        mutableContent.addAttribute(.foregroundColor, value: blockquoteColor, range: NSRange(location: 0, length: mutableContent.length))
        result.append(mutableContent)
        return result
    }

    private func renderTaskItem(_ text: String, checked: Bool) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let checkbox = checked ? "  ☑ " : "  ☐ "
        result.append(NSAttributedString(string: checkbox, attributes: [
            .font: bodyFont,
            .foregroundColor: checked ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor
        ]))

        let content = renderInlineFormatting(text)
        if checked {
            let mutableContent = NSMutableAttributedString(attributedString: content)
            mutableContent.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: mutableContent.length))
            mutableContent.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: NSRange(location: 0, length: mutableContent.length))
            result.append(mutableContent)
        } else {
            result.append(content)
        }
        return result
    }

    private func renderBulletPoint(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: "  • ", attributes: [
            .font: bodyFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]))
        result.append(renderInlineFormatting(text))
        return result
    }

    private func renderNumberedItem(_ text: String, prefix: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: "  \(prefix)", attributes: [
            .font: bodyFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]))
        result.append(renderInlineFormatting(text))
        return result
    }

    private func renderHorizontalRule() -> NSAttributedString {
        let rule = NSMutableAttributedString(string: "───────────────────────────────", attributes: [
            .font: NSFont.systemFont(ofSize: 6),
            .foregroundColor: NSColor.separatorColor
        ])
        return rule
    }

    private func renderTableRow(_ line: String) -> NSAttributedString {
        // Check if this is a separator row (e.g. |---|---|)
        let stripped = line.trimmingCharacters(in: .whitespaces)
        let isSeparator = stripped.allSatisfy { $0 == "|" || $0 == "-" || $0 == ":" || $0 == " " }
            && stripped.contains("-")

        if isSeparator {
            return NSAttributedString(string: "", attributes: [
                .font: bodyFont,
                .foregroundColor: NSColor.separatorColor
            ])
        }

        // Parse cells
        let cells = line.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let result = NSMutableAttributedString()
        for (i, cell) in cells.enumerated() {
            if i > 0 {
                result.append(NSAttributedString(string: "  │  ", attributes: [
                    .font: bodyFont,
                    .foregroundColor: NSColor.separatorColor
                ]))
            }
            result.append(renderInlineFormatting(cell))
        }
        return result
    }

    private func renderCodeBlock(_ code: String, language: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: "\n"))

        let codeAttrs: [NSAttributedString.Key: Any] = [
            .font: codeFont,
            .foregroundColor: textColor,
            .backgroundColor: codeBlockBackground
        ]

        let codeString = NSMutableAttributedString(string: code, attributes: codeAttrs)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = 8
        paragraphStyle.headIndent = 8
        paragraphStyle.tailIndent = -8
        codeString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: codeString.length))

        result.append(codeString)
        result.append(NSAttributedString(string: "\n"))
        return result
    }

    // MARK: - Inline Formatting

    private func renderInlineFormatting(_ text: String, baseFont: NSFont? = nil) -> NSAttributedString {
        let font = baseFont ?? bodyFont
        let result = NSMutableAttributedString()
        let plainAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]

        var current = text.startIndex
        let end = text.endIndex
        var plainStart = current

        func flushPlain() {
            if plainStart < current {
                result.append(NSAttributedString(string: String(text[plainStart..<current]), attributes: plainAttrs))
            }
        }

        while current < end {
            // Inline code `text`
            if text[current] == "`" {
                if let closeIndex = text[text.index(after: current)...].firstIndex(of: "`") {
                    flushPlain()
                    let codeContent = String(text[text.index(after: current)..<closeIndex])
                    result.append(NSAttributedString(string: codeContent, attributes: [
                        .font: codeFont,
                        .foregroundColor: codeColor
                    ]))
                    current = text.index(after: closeIndex)
                    plainStart = current
                    continue
                }
            }

            // Highlight ==text==
            if current < text.index(before: end) {
                let twoChars = String(text[current...text.index(after: current)])
                if twoChars == "==" {
                    let searchStart = text.index(current, offsetBy: 2)
                    if searchStart < end, let closeRange = text[searchStart...].range(of: "==") {
                        flushPlain()
                        let content = String(text[searchStart..<closeRange.lowerBound])
                        result.append(NSAttributedString(string: content, attributes: [
                            .font: font,
                            .foregroundColor: textColor,
                            .backgroundColor: highlightColor
                        ]))
                        current = closeRange.upperBound
                        plainStart = current
                        continue
                    }
                }
            }

            // Strikethrough ~~text~~
            if current < text.index(before: end) {
                let twoChars = String(text[current...text.index(after: current)])
                if twoChars == "~~" {
                    let searchStart = text.index(current, offsetBy: 2)
                    if searchStart < end, let closeRange = text[searchStart...].range(of: "~~") {
                        flushPlain()
                        let content = String(text[searchStart..<closeRange.lowerBound])
                        result.append(NSAttributedString(string: content, attributes: [
                            .font: font,
                            .foregroundColor: textColor,
                            .strikethroughStyle: NSUnderlineStyle.single.rawValue
                        ]))
                        current = closeRange.upperBound
                        plainStart = current
                        continue
                    }
                }
            }

            // Bold+Italic ***text*** or ___text___
            if text.index(current, offsetBy: 2, limitedBy: end) != nil {
                let threeEnd = text.index(current, offsetBy: 3, limitedBy: end)
                if let threeEnd, threeEnd <= end {
                    let threeChars = String(text[current..<threeEnd])
                    if threeChars == "***" || threeChars == "___" {
                        let searchStart = threeEnd
                        if searchStart < end, let closeRange = text[searchStart...].range(of: threeChars) {
                            flushPlain()
                            let content = String(text[searchStart..<closeRange.lowerBound])
                            result.append(NSAttributedString(string: content, attributes: [
                                .font: boldItalicFont,
                                .foregroundColor: textColor
                            ]))
                            current = closeRange.upperBound
                            plainStart = current
                            continue
                        }
                    }
                }
            }

            // Bold **text** or __text__
            if current < text.index(before: end) {
                let twoChars = String(text[current...text.index(after: current)])
                if twoChars == "**" || twoChars == "__" {
                    if let closeRange = text[text.index(current, offsetBy: 2)...].range(of: twoChars) {
                        flushPlain()
                        let boldContent = String(text[text.index(current, offsetBy: 2)..<closeRange.lowerBound])
                        result.append(NSAttributedString(string: boldContent, attributes: [
                            .font: boldFont,
                            .foregroundColor: textColor
                        ]))
                        current = closeRange.upperBound
                        plainStart = current
                        continue
                    }
                }
            }

            // Italic *text* or _text_
            if text[current] == "*" || text[current] == "_" {
                let marker = text[current]
                let nextIndex = text.index(after: current)
                if nextIndex < end && text[nextIndex] != marker {
                    if let closeIndex = text[nextIndex...].firstIndex(of: marker) {
                        let afterClose = text.index(after: closeIndex)
                        if afterClose >= end || text[afterClose] != marker {
                            flushPlain()
                            let italicContent = String(text[nextIndex..<closeIndex])
                            result.append(NSAttributedString(string: italicContent, attributes: [
                                .font: italicFont,
                                .foregroundColor: textColor
                            ]))
                            current = text.index(after: closeIndex)
                            plainStart = current
                            continue
                        }
                    }
                }
            }

            // Images ![alt](url) — must check before links
            if text[current] == "!" {
                let nextIndex = text.index(after: current)
                if nextIndex < end && text[nextIndex] == "[" {
                    if let closeBracket = text[text.index(after: nextIndex)...].firstIndex(of: "]") {
                        let afterBracket = text.index(after: closeBracket)
                        if afterBracket < end && text[afterBracket] == "(" {
                            if let closeParen = text[text.index(after: afterBracket)...].firstIndex(of: ")") {
                                flushPlain()
                                let altText = String(text[text.index(after: nextIndex)..<closeBracket])
                                let display = altText.isEmpty ? "🖼 image" : "🖼 \(altText)"
                                result.append(NSAttributedString(string: display, attributes: [
                                    .font: font,
                                    .foregroundColor: NSColor.secondaryLabelColor
                                ]))
                                current = text.index(after: closeParen)
                                plainStart = current
                                continue
                            }
                        }
                    }
                }
            }

            // Links [text](url)
            if text[current] == "[" {
                if let closeBracket = text[text.index(after: current)...].firstIndex(of: "]") {
                    let afterBracket = text.index(after: closeBracket)
                    if afterBracket < end && text[afterBracket] == "(" {
                        if let closeParen = text[text.index(after: afterBracket)...].firstIndex(of: ")") {
                            flushPlain()
                            let linkText = String(text[text.index(after: current)..<closeBracket])
                            let linkURL = String(text[text.index(after: afterBracket)..<closeParen])
                            var attrs: [NSAttributedString.Key: Any] = [
                                .font: font,
                                .foregroundColor: linkColor,
                                .underlineStyle: NSUnderlineStyle.single.rawValue
                            ]
                            if let url = URL(string: linkURL) {
                                attrs[.link] = url
                            }
                            result.append(NSAttributedString(string: linkText, attributes: attrs))
                            current = text.index(after: closeParen)
                            plainStart = current
                            continue
                        }
                    }
                }
            }

            current = text.index(after: current)
        }

        flushPlain()
        return result
    }
}

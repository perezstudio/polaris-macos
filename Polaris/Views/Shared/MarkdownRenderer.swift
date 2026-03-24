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
    private let codeFont: NSFont
    private let headingFont: NSFont
    private let subheadingFont: NSFont

    init(baseFontSize: CGFloat = 14) {
        let scaled = AppSettings.shared.scaledSize(baseFontSize)
        bodyFont = .systemFont(ofSize: scaled)
        boldFont = .systemFont(ofSize: scaled, weight: .semibold)
        italicFont = .systemFont(ofSize: scaled, weight: .regular)
        codeFont = .monospacedSystemFont(ofSize: scaled - 1, weight: .regular)
        headingFont = .systemFont(ofSize: scaled + 2, weight: .bold)
        subheadingFont = .systemFont(ofSize: scaled + 1, weight: .semibold)
    }

    // MARK: - Colors

    private let textColor: NSColor = .labelColor
    private let codeColor: NSColor = .systemPink
    private let codeBlockBackground: NSColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.3)
    private let linkColor: NSColor = .linkColor

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
        if line.hasPrefix("### ") {
            return renderHeader(String(line.dropFirst(4)), level: 3)
        } else if line.hasPrefix("## ") {
            return renderHeader(String(line.dropFirst(3)), level: 2)
        } else if line.hasPrefix("# ") {
            return renderHeader(String(line.dropFirst(2)), level: 1)
        }

        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
            return renderBulletPoint(String(line.dropFirst(2)))
        }

        if let match = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
            let content = String(line[match.upperBound...])
            let number = String(line[..<match.upperBound])
            return renderNumberedItem(content, prefix: number)
        }

        return renderInlineFormatting(line)
    }

    private func renderHeader(_ text: String, level: Int) -> NSAttributedString {
        let font: NSFont
        switch level {
        case 1: font = headingFont
        case 2: font = subheadingFont
        default: font = boldFont
        }

        return NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: textColor
        ])
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

    private func renderInlineFormatting(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let plainAttrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
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

            if text[current] == "*" || text[current] == "_" {
                let marker = text[current]
                let nextIndex = text.index(after: current)
                if nextIndex < end && text[nextIndex] != marker {
                    if let closeIndex = text[nextIndex...].firstIndex(of: marker) {
                        let afterClose = text.index(after: closeIndex)
                        if afterClose >= end || text[afterClose] != marker {
                            flushPlain()
                            let italicContent = String(text[nextIndex..<closeIndex])
                            let italicDescriptor = bodyFont.fontDescriptor.withSymbolicTraits(.italic)
                            let font = NSFont(descriptor: italicDescriptor, size: bodyFont.pointSize) ?? bodyFont
                            result.append(NSAttributedString(string: italicContent, attributes: [
                                .font: font,
                                .foregroundColor: textColor
                            ]))
                            current = text.index(after: closeIndex)
                            plainStart = current
                            continue
                        }
                    }
                }
            }

            if text[current] == "[" {
                if let closeBracket = text[text.index(after: current)...].firstIndex(of: "]") {
                    let afterBracket = text.index(after: closeBracket)
                    if afterBracket < end && text[afterBracket] == "(" {
                        if let closeParen = text[text.index(after: afterBracket)...].firstIndex(of: ")") {
                            flushPlain()
                            let linkText = String(text[text.index(after: current)..<closeBracket])
                            let linkURL = String(text[text.index(after: afterBracket)..<closeParen])
                            var attrs: [NSAttributedString.Key: Any] = [
                                .font: bodyFont,
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

import Foundation
import SwiftSoup

/// A DLsite description (`descriptionHtml`) flattened into text runs and
/// images, in document order.
public enum WorkDescription {
    public enum Block: Sendable, Equatable {
        case heading(String)
        case paragraph(String)
    }

    public enum Item: Sendable, Equatable {
        /// Consecutive headings and paragraphs, rendered as one selectable text.
        case text([Block])
        case image(url: String)
    }

    public static func parse(_ html: String) throws -> [Item] {
        var items: [Item] = []
        var blocks: [Block] = []
        var paragraph = ""

        func flushParagraph() {
            let cleaned = paragraph
                .replacing(/\n[ \t]+/, with: "\n")
                .replacing(/[ \t]+\n/, with: "\n")
                .replacing(/\n{3,}/, with: "\n\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            paragraph = ""
            if !cleaned.isEmpty { blocks.append(.paragraph(cleaned)) }
        }
        func flushText() {
            if !blocks.isEmpty { items.append(.text(blocks)) }
            blocks = []
        }
        func walk(_ node: Node) throws {
            if let text = node as? TextNode {
                paragraph += text.getWholeText()
                return
            }
            guard let element = node as? Element else { return }
            switch element.tagName() {
            case "br":
                paragraph += "\n"
            case "h1", "h2", "h3", "h4", "h5":
                flushParagraph()
                let text = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { blocks.append(.heading(text)) }
            case "img":
                flushParagraph()
                var src = try element.attr("src")
                if src.isEmpty { src = try element.attr("data-src") }
                guard !src.isEmpty else { return }
                if src.hasPrefix("//") { src = "https:" + src }
                flushText()
                items.append(.image(url: src))
            case "p", "div":
                flushParagraph()
                for child in element.getChildNodes() { try walk(child) }
                flushParagraph()
            case "script", "style":
                return
            default:
                for child in element.getChildNodes() { try walk(child) }
            }
        }

        let body = try SwiftSoup.parseBodyFragment(html.normalizingNewlines).body()!
        for node in body.getChildNodes() { try walk(node) }
        flushParagraph()
        flushText()
        return items
    }

    /// Image URLs in the order `descriptionImageLocalPaths` was saved.
    public static func imageURLs(_ items: [Item]) -> [String] {
        items.compactMap { if case .image(let url) = $0 { url } else { nil } }
    }
}

extension String {
    /// HTML5 input preprocessing turns CRLF and lone CR into LF before
    /// parsing; SwiftSoup skips that step.
    var normalizingNewlines: String {
        replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }
}

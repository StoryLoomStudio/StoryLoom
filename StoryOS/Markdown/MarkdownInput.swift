//
//  MarkdownInput.swift
//  StoryLoom
//
//  Adapted from SwiftMarkdownEngine's list handler (Apache 2.0) — see
//  Markdown/NOTICE.md.
//
//  What a list does when you press Return.
//
//  Every editor an author has ever used continues the list for them, and stops
//  when they press Return on an empty item. Without it a list is a thing you type
//  the markers of by hand, which is to say it is not a list, it is punctuation.
//
//  Deliberately *not* taken from upstream: auto-closing brackets, `->` becoming
//  `→`, and wiki-link completion. All three are good in a note-taking app and
//  wrong in a manuscript — a novelist typing "(she said)" or an em-dash does not
//  want the editor negotiating with them. Smart quotes and dashes already come
//  from AppKit, where the author can switch them off.
//

import AppKit
import Foundation

nonisolated enum MarkdownInput {

    /// `- `, `* `, `+ `, `1. `, `1) `, each with an optional `[ ]` task box.
    /// Group 1 is the whole prefix, group 2 the ordered number when there is one.
    private static let listItem = try! NSRegularExpression(
        pattern: #"^\s*((?:(\d+)[.)]|[-*+])(?:\s+\[[ xX]\])?\s+)"#
    )
    /// `>` runs, with up to three spaces of indent. Group 1 the indent, group 2
    /// the markers.
    private static let blockquote = try! NSRegularExpression(
        pattern: #"^( {0,3})(>+(?:[ \t]+>+)*)[ \t]*"#
    )
    private static let leadingWhitespace = try! NSRegularExpression(pattern: #"^\s*"#)

    /// How deep a list item sits, counting a tab or two spaces as one level.
    private static func indentLevel(of whitespace: String) -> Int {
        whitespace.filter { $0 == "\t" }.count + whitespace.filter { $0 == " " }.count / 2
    }

    private static let maximumNesting = 8

    /// What the editor should do about `replacement` at `range`.
    ///
    /// Returning `nil` means "nothing special — let AppKit insert it", which is
    /// the answer for almost every keystroke and is checked for first.
    static func edit(for replacement: String, at range: NSRange, in text: NSString) -> TextEdit? {
        guard replacement == "\n" || replacement == "\t" else { return nil }
        let caret = min(range.location, text.length)
        let line = text.lineRange(for: NSRange(location: caret, length: 0))
        let lineText = text.substring(with: line)
        let full = NSRange(location: 0, length: (lineText as NSString).length)

        if replacement == "\t" {
            return indent(line: line, lineText: lineText, full: full, caret: caret)
        }
        if let quote = continuation(ofQuote: lineText, full: full, line: line, range: range) {
            return quote
        }
        return continuation(ofList: lineText, full: full, line: line, range: range)
    }

    /// Tab at a list item indents the item rather than inserting a tab mid-line.
    private static func indent(line: NSRange, lineText: String, full: NSRange, caret: Int) -> TextEdit? {
        guard let match = listItem.firstMatch(in: lineText, range: full) else { return nil }
        _ = match
        if let ws = leadingWhitespace.firstMatch(in: lineText, range: full) {
            let whitespace = (lineText as NSString).substring(with: ws.range)
            guard indentLevel(of: whitespace) < maximumNesting else {
                return TextEdit(range: NSRange(location: caret, length: 0), replacement: "",
                                selection: NSRange(location: caret, length: 0))
            }
        }
        return TextEdit(
            range: NSRange(location: line.location, length: 0),
            replacement: "\t",
            selection: NSRange(location: caret + 1, length: 0)
        )
    }

    /// `> foo` + Return → a new quoted line. Return on an empty `>` leaves the quote.
    private static func continuation(ofQuote lineText: String, full: NSRange, line: NSRange, range: NSRange) -> TextEdit? {
        guard let match = blockquote.firstMatch(in: lineText, range: full) else { return nil }
        let ns = lineText as NSString
        let indent = ns.substring(with: match.range(at: 1))
        let markers = ns.substring(with: match.range(at: 2))
        let prefixLength = match.range.length
        let body = ns.substring(from: min(prefixLength, ns.length))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if body.isEmpty {
            return exiting(line: line, prefixLength: prefixLength, text: ns)
        }
        return TextEdit(
            range: range,
            replacement: "\n" + indent + markers + " ",
            selection: NSRange(location: range.location + 1 + (indent + markers + " ").utf16.count, length: 0)
        )
    }

    /// `- foo` + Return → `- `. `1. foo` → `2. `. An empty item leaves the list.
    private static func continuation(ofList lineText: String, full: NSRange, line: NSRange, range: NSRange) -> TextEdit? {
        guard let match = listItem.firstMatch(in: lineText, range: full) else { return nil }
        let ns = lineText as NSString
        let prefixLength = match.range.location + match.range.length
        let body = ns.substring(from: min(prefixLength, ns.length))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if body.isEmpty {
            return exiting(line: line, prefixLength: prefixLength, text: ns)
        }

        var whitespace = ""
        if let ws = leadingWhitespace.firstMatch(in: lineText, range: full) {
            whitespace = ns.substring(with: ws.range)
        }
        let marker = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
        let box = marker.range(of: #"\[[ xX]\]"#, options: .regularExpression) != nil ? "[ ] " : ""

        let next: String
        if match.range(at: 2).location != NSNotFound,
           let number = Int(ns.substring(with: match.range(at: 2))) {
            // A continued ordered list counts on; renumbering the rest is the
            // author's business, and Markdown does not care.
            next = "\(number + 1). " + box
        } else {
            next = String(marker.prefix(1)) + " " + box
        }
        let insertion = "\n" + whitespace + next
        return TextEdit(
            range: range,
            replacement: insertion,
            selection: NSRange(location: range.location + insertion.utf16.count, length: 0)
        )
    }

    /// Return on an empty item removes the marker instead of making another one.
    private static func exiting(line: NSRange, prefixLength: Int, text: NSString) -> TextEdit {
        let endsWithNewline = line.length > 0
            && text.length >= line.length
            && (text.substring(with: NSRange(location: line.length - 1, length: 1)) == "\n")
        let body = endsWithNewline ? line.length - 1 : line.length
        let removal = min(prefixLength, max(0, body))
        return TextEdit(
            range: NSRange(location: line.location, length: removal),
            replacement: "",
            selection: NSRange(location: line.location, length: 0)
        )
    }
}

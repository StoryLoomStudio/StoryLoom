//
//  Presentation.swift
//  StoryLoom
//
//  Appearance the Markdown cannot spell.
//
//  Bold, italic, strikethrough, headings, lists and a marked passage are all
//  *text* — they live in the `.md` file as `**`, `#`, `- `, `==`, and any editor
//  in the world can read them back. Underline, alignment, a choice between four
//  highlighter colours, and a font or size applied to one sentence are not text.
//  CommonMark has no syntax for any of them.
//
//  They could have been written into the prose as inline HTML. They are not,
//  deliberately: the manuscript files are read by the prose-generation pipeline,
//  and `<mark class="amber">` in the middle of a paragraph is noise the author
//  never typed and tokens the model pays for on every call. So the prose stays
//  clean and the appearance lives beside it, in the project package.
//
//  The cost of that choice is drift — a span that no longer knows which words it
//  belonged to. Two things hold it off:
//
//  1. **Within a session there is no drift at all.** Spans are maintained by the
//     same arithmetic `NSTextStorage` uses on its own attributes: every edit
//     shifts, grows, or splits them exactly as it happens. Nothing is re-matched
//     while the author is typing.
//  2. **Across sessions**, each span carries a `TextAnchor` — the same
//     quote-and-context machinery that keeps comments attached — so it can find
//     its words again even if the file was edited elsewhere. When it genuinely
//     cannot, it is dropped rather than guessed at, because a highlight that
//     silently slides onto the wrong sentence is worse than one that is gone.
//

import AppKit
import SwiftUI

// MARK: - Vocabulary

nonisolated enum TextAlignmentChoice: String, Codable, CaseIterable, Identifiable, Sendable {
    case natural, centre, right, justified

    nonisolated var id: String { rawValue }

    var title: String {
        switch self {
        case .natural: "Align Left"
        case .centre: "Centre"
        case .right: "Align Right"
        case .justified: "Justify"
        }
    }

    var glyph: Glyph {
        switch self {
        case .natural: .alignStart
        case .centre: .alignCentre
        case .right: .alignEnd
        case .justified: .alignJustify
        }
    }

    var nsAlignment: NSTextAlignment {
        switch self {
        case .natural: .natural
        case .centre: .center
        case .right: .right
        case .justified: .justified
        }
    }
}

/// Four, because a fifth is a decision the author has to make every time.
nonisolated enum HighlightColour: String, Codable, CaseIterable, Identifiable, Sendable {
    case amber, mint, sky, rose

    nonisolated var id: String { rawValue }

    var title: String {
        switch self {
        case .amber: "Amber"
        case .mint: "Mint"
        case .sky: "Sky"
        case .rose: "Rose"
        }
    }

    var swatch: Color {
        switch self {
        case .amber: Color(hex: 0xF2C14E)
        case .mint: Color(hex: 0x63C7A6)
        case .sky: Color(hex: 0x6FA8DC)
        case .rose: Color(hex: 0xE58FA8)
        }
    }

    /// Weak enough to read straight through, which is the whole job.
    func wash(for appearance: ColorScheme) -> NSColor {
        let base: NSColor
        switch self {
        case .amber: base = NSColor(hex: 0xF2C14E)
        case .mint: base = NSColor(hex: 0x63C7A6)
        case .sky: base = NSColor(hex: 0x6FA8DC)
        case .rose: base = NSColor(hex: 0xE58FA8)
        }
        return base.withAlphaComponent(appearance == .dark ? 0.30 : 0.38)
    }
}

// MARK: - Spans

/// A run of characters carrying appearance. `NSRange` is stored as two integers
/// because `NSRange` is not `Codable` and inventing a wrapper for it would only
/// hide that from the file.
nonisolated struct PresentationRun: Codable, Equatable, Sendable, Identifiable {
    var id = UUID()
    var location: Int
    var length: Int
    var anchor: TextAnchor
    var underline = false
    var highlight: HighlightColour?
    var fontName: String?
    var fontSize: Double?

    var range: NSRange {
        get { NSRange(location: location, length: length) }
        set { location = newValue.location; length = newValue.length }
    }

    /// Whether this run still says anything. An empty one is dropped.
    var isEmpty: Bool {
        length <= 0 || (!underline && highlight == nil && fontName == nil && fontSize == nil)
    }
}

/// Alignment belongs to whole paragraphs, so it is kept apart from the character
/// runs rather than pretending to be one.
nonisolated struct PresentationBlock: Codable, Equatable, Sendable, Identifiable {
    var id = UUID()
    var location: Int
    var length: Int
    var anchor: TextAnchor
    var alignment: TextAlignmentChoice

    var range: NSRange {
        get { NSRange(location: location, length: length) }
        set { location = newValue.location; length = newValue.length }
    }
}

/// Everything one document's prose is wearing.
nonisolated struct PresentationLayer: Codable, Equatable, Sendable {
    var runs: [PresentationRun] = []
    var blocks: [PresentationBlock] = []

    var isEmpty: Bool { runs.isEmpty && blocks.isEmpty }

    // MARK: Applying

    /// Set an attribute over `range`, replacing whatever the overlapping runs said
    /// about *that* attribute and leaving what they said about the others.
    mutating func setRun(_ range: NSRange, in text: String, _ change: (inout PresentationRun) -> Void) {
        guard range.length > 0 else { return }
        var carved: [PresentationRun] = []

        for run in runs {
            let overlap = NSIntersectionRange(run.range, range)
            guard overlap.length > 0 else { carved.append(run); continue }
            // Keep the parts of the old run that fall outside the new range.
            if run.range.location < range.location {
                var head = run
                head.id = UUID()
                head.range = NSRange(location: run.range.location, length: range.location - run.range.location)
                head.anchor = TextAnchor.make(in: text, range: head.range)
                carved.append(head)
            }
            if NSMaxRange(run.range) > NSMaxRange(range) {
                var tail = run
                tail.id = UUID()
                tail.range = NSRange(location: NSMaxRange(range), length: NSMaxRange(run.range) - NSMaxRange(range))
                tail.anchor = TextAnchor.make(in: text, range: tail.range)
                carved.append(tail)
            }
        }

        // The attributes already covering the range are inherited, so setting a
        // colour does not erase an underline underneath it.
        var fresh = runs.first { NSIntersectionRange($0.range, range).length > 0 }
            ?? PresentationRun(location: range.location, length: range.length,
                               anchor: TextAnchor.make(in: text, range: range))
        fresh.id = UUID()
        fresh.range = range
        fresh.anchor = TextAnchor.make(in: text, range: range)
        change(&fresh)

        carved.append(fresh)
        runs = carved.filter { !$0.isEmpty }.sorted { $0.location < $1.location }
    }

    mutating func setAlignment(_ alignment: TextAlignmentChoice?, over range: NSRange, in text: String) {
        let paragraphs = (text as NSString).paragraphRange(for: range)
        blocks.removeAll { NSIntersectionRange($0.range, paragraphs).length > 0 }
        guard let alignment, alignment != .natural else { return }
        blocks.append(PresentationBlock(
            location: paragraphs.location,
            length: paragraphs.length,
            anchor: TextAnchor.make(in: text, range: paragraphs),
            alignment: alignment
        ))
        blocks.sort { $0.location < $1.location }
    }

    /// What is in force at `range`, so the toolbar can light its buttons.
    func attributes(at range: NSRange) -> (underline: Bool, highlight: HighlightColour?, fontName: String?, fontSize: Double?) {
        let probe = range.length > 0 ? range : NSRange(location: max(0, range.location - 1), length: 1)
        guard let run = runs.first(where: { NSIntersectionRange($0.range, probe).length > 0 }) else {
            return (false, nil, nil, nil)
        }
        return (run.underline, run.highlight, run.fontName, run.fontSize)
    }

    func alignment(at range: NSRange) -> TextAlignmentChoice {
        blocks.first { NSIntersectionRange($0.range, range).length > 0 || NSLocationInRange(range.location, $0.range) }?
            .alignment ?? .natural
    }

    // MARK: Staying attached

    /// Move every span through an edit, exactly as an attributed string moves its
    /// own attributes. This is why there is no drift while the author is typing:
    /// nothing is searched for, it is arithmetic on a known edit.
    mutating func adjust(editedRange: NSRange, delta: Int) {
        let changeStart = editedRange.location
        let oldLength = editedRange.length - delta

        func shift(_ range: NSRange) -> NSRange? {
            var location = range.location
            var length = range.length
            let end = location + length
            let oldEnd = changeStart + oldLength

            if location >= oldEnd {
                location += delta                       // wholly after: slide
            } else if end <= changeStart {
                // wholly before: untouched
            } else {
                // The edit lands inside. Grow or shrink around it, and let a span
                // whose text was entirely replaced die rather than smear.
                if location >= changeStart { location = max(changeStart, location + delta) }
                let newEnd = end >= oldEnd ? end + delta : max(changeStart, min(end, changeStart + editedRange.length))
                length = newEnd - location
            }
            guard length > 0, location >= 0 else { return nil }
            return NSRange(location: location, length: length)
        }

        runs = runs.compactMap { run in
            guard let moved = shift(run.range) else { return nil }
            var copy = run
            copy.range = moved
            return copy
        }
        blocks = blocks.compactMap { block in
            guard let moved = shift(block.range) else { return nil }
            var copy = block
            copy.range = moved
            return copy
        }
    }

    /// Re-find every span in `text` after loading it from disk, where the offsets
    /// may be stale because the file was edited elsewhere. Spans whose words are
    /// gone are dropped.
    mutating func reanchor(in text: String) {
        let length = (text as NSString).length
        runs = runs.compactMap { run in
            var copy = run
            if run.range.location + run.range.length <= length,
               (text as NSString).substring(with: run.range) == run.anchor.quote {
                return copy                              // offsets still true
            }
            guard let found = run.anchor.resolve(in: text) else { return nil }
            copy.range = found
            return copy
        }
        blocks = blocks.compactMap { block in
            var copy = block
            if block.range.location + block.range.length <= length,
               (text as NSString).substring(with: block.range) == block.anchor.quote {
                return copy
            }
            guard let found = block.anchor.resolve(in: text) else { return nil }
            copy.range = found
            return copy
        }
    }
}

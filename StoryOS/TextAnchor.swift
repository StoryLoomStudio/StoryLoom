//
//  TextAnchor.swift
//  StoryLoom
//
//  Resilient text anchors. 10-Editor requires annotations that "survive edits
//  through resilient text anchors" and that orphaned anchors be "surfaced for
//  repair" rather than silently dropped or silently moved.
//
//  The strategy is the well-tested quote/context pair: remember the exact text
//  that was anchored plus a little of what surrounded it, and remember where it
//  used to be. On resolve, prefer an unambiguous exact match; disambiguate
//  duplicates by context and last-known position; and refuse to guess when the
//  text is gone. Refusing is the point — a comment that quietly slides onto the
//  wrong sentence is worse than one that admits it is lost.
//

import Foundation

nonisolated struct TextAnchor: Codable, Hashable, Sendable {
    /// The exact text the author anchored to.
    var quote: String
    /// Up to `contextLength` characters immediately before the quote.
    var prefix: String
    /// Up to `contextLength` characters immediately after the quote.
    var suffix: String
    /// The UTF-16 offset the quote occupied when the anchor was made. Used only
    /// to break ties between otherwise equally good candidates.
    var offsetHint: Int

    private static let contextLength = 32

    nonisolated init(quote: String, prefix: String, suffix: String, offsetHint: Int) {
        self.quote = quote
        self.prefix = prefix
        self.suffix = suffix
        self.offsetHint = offsetHint
    }

    /// Captures an anchor for `range` within `text`.
    nonisolated static func make(in text: String, range: NSRange) -> TextAnchor {
        let ns = text as NSString
        let safe = range.clamped(to: ns.length)

        let prefixStart = max(0, safe.location - contextLength)
        let prefixRange = NSRange(location: prefixStart, length: safe.location - prefixStart)

        let suffixStart = safe.location + safe.length
        let suffixLength = min(contextLength, ns.length - suffixStart)
        let suffixRange = NSRange(location: suffixStart, length: max(0, suffixLength))

        return TextAnchor(
            quote: ns.substring(with: safe),
            prefix: ns.substring(with: prefixRange),
            suffix: ns.substring(with: suffixRange),
            offsetHint: safe.location
        )
    }

    /// Finds where this anchor now lives, or `nil` if the quoted text is gone.
    nonisolated func resolve(in text: String) -> NSRange? {
        guard !quote.isEmpty else { return nil }
        let ns = text as NSString

        var candidates: [NSRange] = []
        var searchStart = 0
        while searchStart < ns.length {
            let remaining = NSRange(location: searchStart, length: ns.length - searchStart)
            let found = ns.range(of: quote, options: [.literal], range: remaining)
            guard found.location != NSNotFound else { break }
            candidates.append(found)
            searchStart = found.location + max(1, found.length)
        }

        if candidates.isEmpty {
            return resolveIgnoringWhitespace(in: text)
        }
        if candidates.count == 1 {
            return candidates[0]
        }
        return candidates.max { score(for: $0, in: ns) < score(for: $1, in: ns) }
    }

    /// Whether the anchor still finds its text. Orphans are shown for repair.
    nonisolated func isOrphaned(in text: String) -> Bool {
        resolve(in: text) == nil
    }

    /// A single-line rendering of the quote for lists and inspectors.
    nonisolated var excerpt: String {
        let collapsed = quote
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed.count > 90 ? String(collapsed.prefix(90)) + "…" : collapsed
    }

    // MARK: - Scoring

    /// Higher is better. Context agreement dominates; position only breaks ties.
    private nonisolated func score(for candidate: NSRange, in ns: NSString) -> Double {
        let beforeStart = max(0, candidate.location - Self.contextLength)
        let before = ns.substring(with: NSRange(location: beforeStart, length: candidate.location - beforeStart))

        let afterStart = candidate.location + candidate.length
        let afterLength = min(Self.contextLength, ns.length - afterStart)
        let after = ns.substring(with: NSRange(location: afterStart, length: max(0, afterLength)))

        let prefixScore = Double(commonSuffixLength(prefix, before))
        let suffixScore = Double(commonPrefixLength(suffix, after))

        // A candidate 400 characters from where the anchor used to sit is worth
        // less than one that barely moved, but never more than real context.
        let drift = Double(abs(candidate.location - offsetHint))
        let proximity = 1.0 / (1.0 + drift / 400.0)

        return (prefixScore + suffixScore) + proximity
    }

    /// Last-resort match that tolerates reflowed whitespace, which is by far the
    /// most common benign edit around an anchored phrase. It walks Characters
    /// rather than UTF-16 units so that graphemes stay intact while the map back
    /// to AppKit offsets stays exact.
    private nonisolated func resolveIgnoringWhitespace(in text: String) -> NSRange? {
        let needle = TextAnchor.collapseWhitespace(quote)
        guard needle.count >= 8 else { return nil }

        var collapsed = ""
        var utf16Offsets: [Int] = []   // one entry per Character in `collapsed`
        var offset = 0
        var lastWasSpace = false

        for character in text {
            if character.isWhitespace {
                if !lastWasSpace, !collapsed.isEmpty {
                    collapsed.append(" ")
                    utf16Offsets.append(offset)
                }
                lastWasSpace = true
            } else {
                collapsed.append(character)
                utf16Offsets.append(offset)
                lastWasSpace = false
            }
            offset += character.utf16.count
        }

        guard let match = collapsed.range(of: needle) else { return nil }
        let first = collapsed.distance(from: collapsed.startIndex, to: match.lowerBound)
        let last = collapsed.distance(from: collapsed.startIndex, to: match.upperBound) - 1
        guard first >= 0, last >= first, last < utf16Offsets.count else { return nil }

        // `collapseWhitespace` never produces a leading or trailing space, so the
        // final matched Character is always real text and its width is its own.
        let lastCharacter = collapsed[collapsed.index(collapsed.startIndex, offsetBy: last)]
        let start = utf16Offsets[first]
        let end = utf16Offsets[last] + lastCharacter.utf16.count
        return NSRange(location: start, length: end - start)
    }

    private nonisolated static func collapseWhitespace(_ value: String) -> String {
        value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private nonisolated func commonSuffixLength(_ lhs: String, _ rhs: String) -> Int {
        var count = 0
        var left = lhs.endIndex
        var right = rhs.endIndex
        while left > lhs.startIndex, right > rhs.startIndex {
            left = lhs.index(before: left)
            right = rhs.index(before: right)
            guard lhs[left] == rhs[right] else { break }
            count += 1
        }
        return count
    }

    private nonisolated func commonPrefixLength(_ lhs: String, _ rhs: String) -> Int {
        var count = 0
        var left = lhs.startIndex
        var right = rhs.startIndex
        while left < lhs.endIndex, right < rhs.endIndex {
            guard lhs[left] == rhs[right] else { break }
            count += 1
            left = lhs.index(after: left)
            right = rhs.index(after: right)
        }
        return count
    }
}

// MARK: - Anchored comments

/// An author annotation bound to a passage. Comments are canonical metadata but
/// never appear in an export unless an editorial profile asks for them (16-Export).
nonisolated struct StoryComment: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var documentID: UUID
    var anchor: TextAnchor
    var body: String
    var createdAt = Date.stamp
    var resolvedAt: Date?

    var isResolved: Bool { resolvedAt != nil }

    nonisolated init(
        id: UUID = UUID(),
        documentID: UUID,
        anchor: TextAnchor,
        body: String = "",
        createdAt: Date = .stamp,
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.documentID = documentID
        self.anchor = anchor
        self.body = body
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
    }
}

// MARK: - NSRange helpers

extension NSRange {
    nonisolated func clamped(to length: Int) -> NSRange {
        let start = max(0, min(location, length))
        let end = max(start, min(location + self.length, length))
        return NSRange(location: start, length: end - start)
    }
}

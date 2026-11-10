//
//  StoryBrain.swift
//  StoryLoom
//
//  Deterministic, explainable story understanding. This starts with evidence
//  retrieval rather than probabilistic claims: every result is derived from a
//  visible name or alias in canonical manuscript text, and every result can
//  point at the exact characters that produced it (01-Manifesto, "Make state
//  inspectable").
//
//  It does not infer facts, motives, or intent. When it does not know, it says
//  nothing rather than something plausible.
//

import Foundation

nonisolated struct Mention: Hashable, Sendable {
    let entityID: UUID
    let documentID: UUID
    let range: NSRange
    /// The name or alias that actually matched, so the evidence can say which.
    let term: String
}

/// A rebuildable index of where the author's records appear in their prose.
/// Nothing here is canonical; deleting it costs nothing but a recomputation.
nonisolated struct StoryIndex: Sendable {
    private(set) var mentions: [Mention] = []
    private var byEntity: [UUID: [Mention]] = [:]
    private var byDocument: [UUID: [Mention]] = [:]

    nonisolated init() {}

    nonisolated init(project: StoryProject) {
        var all: [Mention] = []
        for document in project.documents where !document.text.isEmpty {
            all.append(contentsOf: StoryBrain.mentions(in: document, entities: project.story.entities))
        }
        mentions = all
        byEntity = Dictionary(grouping: all, by: \.entityID)
        byDocument = Dictionary(grouping: all, by: \.documentID)
    }

    func mentions(of entityID: UUID) -> [Mention] { byEntity[entityID] ?? [] }
    func mentions(in documentID: UUID) -> [Mention] { byDocument[documentID] ?? [] }

    func documentIDs(mentioning entityID: UUID) -> [UUID] {
        var seen = Set<UUID>()
        return mentions(of: entityID).compactMap { seen.insert($0.documentID).inserted ? $0.documentID : nil }
    }

    func entityIDs(mentionedIn documentID: UUID) -> [UUID] {
        var seen = Set<UUID>()
        return mentions(in: documentID).compactMap { seen.insert($0.entityID).inserted ? $0.entityID : nil }
    }

    func isMentionedAnywhere(_ entityID: UUID) -> Bool {
        !(byEntity[entityID] ?? []).isEmpty
    }
}

nonisolated enum StoryBrain {

    /// Every place `entity` is named in `document`, by any of its terms.
    static func mentions(of entity: StoryEntity, in document: StoryDocument) -> [Mention] {
        guard !document.text.isEmpty else { return [] }
        let text = document.text as NSString
        var found: [Mention] = []

        for term in entity.searchTerms {
            var searchStart = 0
            while searchStart < text.length {
                let remaining = NSRange(location: searchStart, length: text.length - searchStart)
                let range = text.range(
                    of: term,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: remaining
                )
                guard range.location != NSNotFound else { break }
                if isWholeWord(range, in: text) {
                    found.append(Mention(entityID: entity.id, documentID: document.id, range: range, term: term))
                }
                searchStart = range.location + max(1, range.length)
            }
        }

        // A longer alias and a shorter one can both match the same characters
        // ("the ledger" and "ledger"); keep the leftmost-longest and drop the rest.
        return dedupe(found)
    }

    /// Every entity named anywhere in `document`, with overlaps resolved across
    /// records rather than within each one.
    ///
    /// This is the method the index uses, and the distinction matters. "The
    /// keeper's ledger" is an object; "the keeper" is a character's alias. Matched
    /// one entity at a time, both hit the same characters, and every appearance of
    /// the ledger would quietly be counted as an appearance of the keeper —
    /// enough to make a character StoryLoom has never actually seen on the page look
    /// like they were written. The longest name at a given position wins, because
    /// the most specific name is the one the author meant.
    static func mentions(in document: StoryDocument, entities: [StoryEntity]) -> [Mention] {
        dedupe(entities.flatMap { mentions(of: $0, in: document) })
    }

    static func entitiesMentioned(in document: StoryDocument, entities: [StoryEntity]) -> [StoryEntity] {
        entities.filter { !mentions(of: $0, in: document).isEmpty }
    }

    static func documentsMentioning(_ entity: StoryEntity, in documents: [StoryDocument]) -> [StoryDocument] {
        documents.filter { !mentions(of: entity, in: $0).isEmpty }
    }

    /// A quotable line of context around a hit, plus where the hit sits inside it.
    static func excerpt(around range: NSRange, in text: String, padding: Int = 48) -> (text: String, highlight: Range<String.Index>?) {
        let ns = text as NSString
        let safe = range.clamped(to: ns.length)
        guard safe.length > 0 else { return (String(text.prefix(120)), nil) }

        let start = max(0, safe.location - padding)
        let end = min(ns.length, safe.location + safe.length + padding * 2)
        let window = NSRange(location: start, length: end - start)

        var snippet = ns.substring(with: window).replacingOccurrences(of: "\n", with: " ")
        let leading = start > 0 ? "…" : ""
        let trailing = end < ns.length ? "…" : ""

        let hitOffsetInWindow = safe.location - start
        let hitText = ns.substring(with: safe)
        snippet = leading + snippet + trailing

        // Locate the hit inside the assembled snippet rather than trusting offsets
        // across the ellipsis and newline substitutions.
        let searchStart = snippet.index(snippet.startIndex, offsetBy: min(leading.count + max(0, hitOffsetInWindow - 4), snippet.count))
        let highlight = snippet.range(of: hitText, range: searchStart..<snippet.endIndex)
            ?? snippet.range(of: hitText)

        return (snippet, highlight)
    }

    // MARK: - Matching

    /// Names match on word boundaries so that "Ash" does not light up inside
    /// "ashamed". Diacritics and case are ignored; word shape is not.
    private static func isWholeWord(_ range: NSRange, in text: NSString) -> Bool {
        let before: unichar? = range.location > 0 ? text.character(at: range.location - 1) : nil
        let afterIndex = range.location + range.length
        let after: unichar? = afterIndex < text.length ? text.character(at: afterIndex) : nil
        return isBoundary(before) && isBoundary(after)
    }

    private static func isBoundary(_ character: unichar?) -> Bool {
        guard let character, let scalar = Unicode.Scalar(character) else { return true }
        // A letter or digit means the name is buried inside a longer word: "Ash"
        // in "ashamed", "Mara" in "Maras". Not a mention.
        if CharacterSet.alphanumerics.contains(scalar) { return false }
        // Everything else ends the word — including an apostrophe, which is how a
        // possessive stays a mention. Prose names characters possessively
        // constantly ("Mara's hand"), and a brain that could not see those would
        // under-count almost every character in the book.
        return true
    }

    /// Leftmost-longest: overlapping hits collapse to the most specific one.
    ///
    /// The entity id is the last tiebreaker. It is arbitrary, but it must be
    /// *decided*: two records answering to the same name at the same position have
    /// no true winner, and an unstable sort would let the index — and so the
    /// findings, and so the author's dismissals — shuffle between launches. The
    /// collision itself is reported separately, which is the real answer.
    private static func dedupe(_ mentions: [Mention]) -> [Mention] {
        let sorted = mentions.sorted {
            if $0.range.location != $1.range.location { return $0.range.location < $1.range.location }
            if $0.range.length != $1.range.length { return $0.range.length > $1.range.length }
            return $0.entityID.uuidString < $1.entityID.uuidString
        }
        var kept: [Mention] = []
        for mention in sorted {
            let overlaps = kept.contains { NSIntersectionRange($0.range, mention.range).length > 0 }
            if !overlaps { kept.append(mention) }
        }
        return kept
    }
}

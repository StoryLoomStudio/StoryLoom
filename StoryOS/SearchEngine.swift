//
//  SearchEngine.swift
//  StoryLoom
//
//  Search as orientation (13-Search): it must answer both "where did I write
//  this?" and "what does the story establish?". Results carry a terse reason for
//  their rank, because an opaque ranking is a ranking the author cannot correct.
//
//  Structural filters are optional and discoverable — `pov:mara status:draft
//  thread:lands "the tide turns"` — and plain words always work without them.
//

import Foundation
import SwiftUI

// MARK: - Query

nonisolated struct SearchQuery: Equatable, Sendable {
    var words: [String] = []
    var phrases: [String] = []
    var filters: [SearchFilter] = []

    var isEmpty: Bool { words.isEmpty && phrases.isEmpty && filters.isEmpty }

    /// Everything the author typed that should be highlighted in a result.
    var highlightable: [String] { phrases + words }

    /// Parses `pov:mara thread:lands "the tide turns" ledger` without ever refusing
    /// input: anything that is not a recognised filter is simply a word.
    nonisolated static func parse(_ raw: String) -> SearchQuery {
        var query = SearchQuery()
        var scanner = Substring(raw)

        while !scanner.isEmpty {
            scanner = scanner.drop(while: \.isWhitespace)
            guard !scanner.isEmpty else { break }

            if scanner.first == "\"" {
                scanner = scanner.dropFirst()
                let phrase = scanner.prefix { $0 != "\"" }
                scanner = scanner.dropFirst(phrase.count)
                if !scanner.isEmpty { scanner = scanner.dropFirst() }  // closing quote
                let value = phrase.trimmingCharacters(in: .whitespaces)
                if !value.isEmpty { query.phrases.append(value) }
                continue
            }

            let token = scanner.prefix { !$0.isWhitespace }
            scanner = scanner.dropFirst(token.count)
            guard !token.isEmpty else { continue }

            if let filter = SearchFilter(token: String(token)) {
                query.filters.append(filter)
            } else {
                query.words.append(String(token))
            }
        }
        return query
    }
}

nonisolated enum SearchFilter: Equatable, Hashable, Sendable {
    case pov(String)
    case status(DocumentStatus)
    case chapter(String)
    /// Scenes that touch a thread at all, or in one particular way. `thread:open`
    /// is the query an author runs before starting a chapter.
    case thread(ThreadRole?)
    case kind(EntityKind)
    /// `in:dialogue` — match only inside quotation marks.
    ///
    /// This is the one search a novelist runs that prose search cannot answer.
    /// "Did anyone ever actually *say* the ledger was hers, or have I only ever
    /// narrated it?" is a question about speech, and a body search answers it
    /// wrongly by finding the narration every time.
    case dialogue

    nonisolated init?(token: String) {
        guard let separator = token.firstIndex(of: ":"), separator > token.startIndex else { return nil }
        let key = token[..<separator].lowercased()
        let value = String(token[token.index(after: separator)...])
        guard !value.isEmpty else { return nil }

        switch key {
        case "pov": self = .pov(value.lowercased())
        case "chapter": self = .chapter(value.lowercased())
        case "thread":
            if value.lowercased() == "any" { self = .thread(nil) }
            else if let role = ThreadRole(rawValue: value.lowercased()) { self = .thread(role) }
            else { return nil }
        case "status":
            guard let status = DocumentStatus(rawValue: value.lowercased()) else { return nil }
            self = .status(status)
        case "kind", "type":
            guard let kind = EntityKind(rawValue: value.lowercased()) else { return nil }
            self = .kind(kind)
        case "in":
            guard value.lowercased() == "dialogue" || value.lowercased() == "speech" else { return nil }
            self = .dialogue
        default: return nil
        }
    }

    var label: String {
        switch self {
        case .pov(let value): "pov: \(value)"
        case .status(let value): "status: \(value.title)"
        case .chapter(let value): "chapter: \(value)"
        case .thread(let role): role.map { "thread: \($0.title.lowercased())" } ?? "touches a thread"
        case .kind(let value): "kind: \(value.title)"
        case .dialogue: "in dialogue"
        }
    }

    /// Filters that describe a manuscript document rather than a story record.
    var appliesToDocuments: Bool {
        switch self {
        case .pov, .status, .chapter, .thread, .dialogue: true
        case .kind: false
        }
    }
}

// MARK: - Results

nonisolated enum SearchDestination: Hashable, Sendable {
    case document(UUID, NSRange?)
    case thread(UUID)
    case entity(UUID)
    case relationship(UUID)
    case event(UUID)
    case note(UUID)
    case snapshot(UUID)

    /// The thing itself, without the position inside it.
    ///
    /// Two destinations can point at one scene and differ only by which line
    /// matched, so identity for "have I already offered this?" has to be the
    /// subject rather than the whole value.
    var subjectID: UUID {
        switch self {
        case .document(let id, _): id
        case .thread(let id): id
        case .entity(let id): id
        case .relationship(let id): id
        case .event(let id): id
        case .note(let id): id
        case .snapshot(let id): id
        }
    }
}

nonisolated struct SearchHit: Identifiable, Sendable {
    let id: String
    let title: String
    let category: String
    let snippet: String
    /// Ranges within `snippet` that matched, for emphasis in the result row.
    let highlights: [Range<String.Index>]
    let icon: IconSource
    let tint: Color
    let destination: SearchDestination
    let score: Double
    /// Why this ranked where it did. An unexplained ranking cannot be corrected.
    let reason: String
}

// MARK: - Engine

nonisolated enum SearchEngine {

    static func search(
        _ raw: String,
        in project: StoryProject,
        history: [ProjectSnapshotRecord] = [],
        limit: Int = 60
    ) -> [SearchHit] {
        let query = SearchQuery.parse(raw)
        guard !query.isEmpty else { return [] }

        var hits: [SearchHit] = []
        hits += documentHits(query, project)
        hits += threadHits(query, project)
        hits += entityHits(query, project)
        hits += relationshipHits(query, project)
        hits += eventHits(query, project)
        hits += noteHits(query, project)
        hits += snapshotHits(query, history)

        return Array(hits.sorted { $0.score > $1.score }.prefix(limit))
    }

    // MARK: Threads

    /// A thread's *answer* is searchable, and that is deliberate: the author needs
    /// to find "the one where the ledger turns out to be a list of the drowned"
    /// without remembering how they phrased the question. Nothing here can escape
    /// the project — search results are not an export surface.
    private static func threadHits(_ query: SearchQuery, _ project: StoryProject) -> [SearchHit] {
        guard !query.filters.contains(where: \.appliesToDocuments) else { return [] }

        return project.story.threads.compactMap { thread in
            var score = 0.0
            var reasons: [String] = []

            if let questionScore = fieldScore(text: thread.displayQuestion, query: query, weight: 48) {
                score += questionScore
                reasons.append("question")
            }
            if let answerScore = fieldScore(text: thread.answer, query: query, weight: 20) {
                score += answerScore
                reasons.append("answer")
            }

            guard score > 0 else { return nil }
            let snippet = thread.answer.isEmpty ? "No answer written yet." : thread.answer

            return SearchHit(
                id: "thread-\(thread.id.uuidString)",
                title: thread.displayQuestion,
                category: thread.kind.title,
                snippet: snippet,
                highlights: highlightRanges(in: snippet, query: query),
                icon: thread.kind.icon,
                tint: thread.kind.tint,
                destination: .thread(thread.id),
                score: score,
                reason: reasons.joined(separator: " · ")
            )
        }
    }

    // MARK: Documents

    private static func documentHits(_ query: SearchQuery, _ project: StoryProject) -> [SearchHit] {
        project.documents.compactMap { document in
            for filter in query.filters where filter.appliesToDocuments {
                guard matches(filter, document) else { return nil }
            }
            // A bare filter query ("status:draft") is a valid, useful search.
            if query.words.isEmpty, query.phrases.isEmpty {
                guard query.filters.contains(where: \.appliesToDocuments) else { return nil }
                return SearchHit(
                    id: "document-\(document.id.uuidString)",
                    title: document.displayTitle,
                    category: document.chapterTitle,
                    snippet: document.isEmpty ? "No prose yet." : String(document.text.prefix(160)),
                    highlights: [],
                    icon: .system(document.kind.symbolName),
                    tint: document.kind.tint,
                    destination: .document(document.id, nil),
                    score: 30,
                    reason: query.filters.map(\.label).joined(separator: " · ")
                )
            }

            var score = 0.0
            var reasons: [String] = []

            if let titleScore = fieldScore(text: document.displayTitle, query: query, weight: 46) {
                score += titleScore
                reasons.append("title")
            }
            if let chapterScore = fieldScore(text: document.chapterTitle, query: query, weight: 14) {
                score += chapterScore
                reasons.append("chapter")
            }
            if let intentionScore = fieldScore(text: document.intention, query: query, weight: 12) {
                score += intentionScore
                reasons.append("intention")
            }
            // The craft fields are private and searchable, which is the whole point
            // of writing them down: "which scene was the one where she stops lying
            // to herself" is a question about the turn, not about the prose.
            let craft = [document.turn, document.withheld, document.residue]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !craft.isEmpty, let craftScore = fieldScore(text: craft, query: query, weight: 12) {
                score += craftScore
                reasons.append("scene notes")
            }

            var bodyRange: NSRange?
            if let body = bodyMatch(document.text, query: query) {
                score += body.score
                bodyRange = body.range
                reasons.append(body.count == 1 ? "1 mention" : "\(body.count) mentions")
            }

            guard score > 0 else { return nil }
            let excerpt = bodyRange.map { StoryBrain.excerpt(around: $0, in: document.text) }
            let snippet = excerpt?.text ?? (document.intention.isEmpty ? String(document.text.prefix(160)) : document.intention)

            return SearchHit(
                id: "document-\(document.id.uuidString)",
                title: document.displayTitle,
                category: document.chapterTitle,
                snippet: snippet,
                highlights: highlightRanges(in: snippet, query: query),
                icon: .system(document.kind.symbolName),
                tint: document.kind.tint,
                destination: .document(document.id, bodyRange),
                score: score,
                reason: reasons.joined(separator: " · ")
            )
        }
    }

    private static func matches(_ filter: SearchFilter, _ document: StoryDocument) -> Bool {
        switch filter {
        case .pov(let value): document.pov.lowercased().contains(value)
        case .status(let value): document.status == value
        case .chapter(let value): document.chapterTitle.lowercased().contains(value)
        case .thread(let role): role.map { !document.threadIDs(for: $0).isEmpty } ?? document.touchesAnyThread
        case .kind: true
        // Scope, not a predicate: it narrows where the words are looked for
        // rather than deciding whether this document is eligible. Handled in
        // `bodyMatch`; every document stays in play until the words fail.
        case .dialogue: true
        }
    }

    // MARK: Story records

    private static func entityHits(_ query: SearchQuery, _ project: StoryProject) -> [SearchHit] {
        var hasKindFilter = false
        for filter in query.filters {
            // A document-shaped filter ("status:draft") means the author is asking
            // about scenes, so story records should stay out of the way entirely.
            if filter.appliesToDocuments { return [] }
            if case .kind = filter { hasKindFilter = true }
        }

        return project.story.entities.compactMap { entity in
            for filter in query.filters {
                if case .kind(let kind) = filter, entity.kind != kind { return nil }
            }
            if query.words.isEmpty, query.phrases.isEmpty {
                guard hasKindFilter else { return nil }
                return hit(for: entity, score: 30, reason: "kind")
            }

            var score = 0.0
            var reasons: [String] = []

            if let nameScore = fieldScore(text: entity.displayName, query: query, weight: 58) {
                score += nameScore
                reasons.append("name")
            }
            if !entity.aliases.isEmpty, let aliasScore = fieldScore(text: entity.aliases.joined(separator: " "), query: query, weight: 44) {
                score += aliasScore
                reasons.append("alias")
            }
            if let summaryScore = fieldScore(text: entity.summary, query: query, weight: 14) {
                score += summaryScore
                reasons.append("summary")
            }
            if let roleScore = fieldScore(text: entity.role, query: query, weight: 10) {
                score += roleScore
                reasons.append("role")
            }

            guard score > 0 else { return nil }
            return hit(for: entity, score: score, reason: reasons.joined(separator: " · "), query: query)
        }
    }

    private static func hit(for entity: StoryEntity, score: Double, reason: String, query: SearchQuery? = nil) -> SearchHit {
        let snippet = entity.summary.isEmpty ? entity.kind.title : entity.summary
        return SearchHit(
            id: "entity-\(entity.id.uuidString)",
            title: entity.displayName,
            category: entity.kind.title,
            snippet: snippet,
            highlights: query.map { highlightRanges(in: snippet, query: $0) } ?? [],
            icon: .system(entity.kind.symbolName),
            tint: entity.kind.tint,
            destination: .entity(entity.id),
            score: score,
            reason: reason
        )
    }

    private static func relationshipHits(_ query: SearchQuery, _ project: StoryProject) -> [SearchHit] {
        guard !query.words.isEmpty || !query.phrases.isEmpty else { return [] }

        return project.story.relationships.compactMap { relationship in
            let source = project.entity(relationship.sourceEntityID)?.displayName ?? "Unknown"
            let target = project.entity(relationship.targetEntityID)?.displayName ?? "Unknown"
            let connector = relationship.label.isEmpty ? relationship.kind.title.lowercased() : relationship.label
            let sentence = "\(source) \(connector) \(target)"

            var score = 0.0
            if let value = fieldScore(text: sentence, query: query, weight: 34) { score += value }
            if let value = fieldScore(text: relationship.summary, query: query, weight: 12) { score += value }
            guard score > 0 else { return nil }

            return SearchHit(
                id: "relationship-\(relationship.id.uuidString)",
                title: sentence,
                category: relationship.kind.title,
                snippet: relationship.summary.isEmpty ? "Author-confirmed relationship." : relationship.summary,
                highlights: highlightRanges(in: relationship.summary, query: query),
                icon: .system(relationship.kind.symbolName),
                tint: .secondary,
                destination: .relationship(relationship.id),
                score: score,
                reason: "relationship"
            )
        }
    }

    private static func eventHits(_ query: SearchQuery, _ project: StoryProject) -> [SearchHit] {
        guard !query.words.isEmpty || !query.phrases.isEmpty else { return [] }

        return project.story.events.compactMap { event in
            var score = 0.0
            var reasons: [String] = []
            if let value = fieldScore(text: event.displayTitle, query: query, weight: 44) {
                score += value
                reasons.append("title")
            }
            if let value = fieldScore(text: event.chronologyLabel, query: query, weight: 16) {
                score += value
                reasons.append("chronology")
            }
            if let value = fieldScore(text: event.summary, query: query, weight: 12) {
                score += value
                reasons.append("summary")
            }
            guard score > 0 else { return nil }

            let snippet = event.summary.isEmpty ? event.chronologyLabel : event.summary
            return SearchHit(
                id: "event-\(event.id.uuidString)",
                title: event.displayTitle,
                category: event.chronologyLabel.isEmpty ? "Event" : event.chronologyLabel,
                snippet: snippet,
                highlights: highlightRanges(in: snippet, query: query),
                icon: .system("calendar"),
                tint: event.certainty.tint,
                destination: .event(event.id),
                score: score,
                reason: reasons.joined(separator: " · ")
            )
        }
    }

    private static func noteHits(_ query: SearchQuery, _ project: StoryProject) -> [SearchHit] {
        guard !query.words.isEmpty || !query.phrases.isEmpty else { return [] }

        return project.story.notes.compactMap { note in
            var score = 0.0
            if let value = fieldScore(text: note.displayTitle, query: query, weight: 40) { score += value }

            var bodyRange: NSRange?
            if let body = bodyMatch(note.body, query: query) {
                score += body.score
                bodyRange = body.range
            }
            guard score > 0 else { return nil }

            let snippet = bodyRange.map { StoryBrain.excerpt(around: $0, in: note.body).text } ?? String(note.body.prefix(140))
            return SearchHit(
                id: "note-\(note.id.uuidString)",
                title: note.displayTitle,
                category: "Note",
                snippet: snippet,
                highlights: highlightRanges(in: snippet, query: query),
                icon: .system("note.text"),
                tint: .orange,
                destination: .note(note.id),
                score: score,
                reason: "note"
            )
        }
    }

    private static func snapshotHits(_ query: SearchQuery, _ history: [ProjectSnapshotRecord]) -> [SearchHit] {
        guard !query.words.isEmpty else { return [] }

        return history.compactMap { snapshot in
            guard let value = fieldScore(text: snapshot.reason, query: query, weight: 18) else { return nil }
            return SearchHit(
                id: "snapshot-\(snapshot.id.uuidString)",
                title: snapshot.reason,
                category: "History",
                snippet: "\(snapshot.wordCount.formatted()) words · \(snapshot.documentCount) documents",
                highlights: [],
                icon: .system("clock.arrow.circlepath"),
                tint: .secondary,
                destination: .snapshot(snapshot.id),
                score: value,
                reason: "save point"
            )
        }
    }

    // MARK: Scoring

    /// Every term must appear somewhere for a field to count, so that a two-word
    /// query does not rank a document that only contains the commoner word.
    private static func fieldScore(text: String, query: SearchQuery, weight: Double) -> Double? {
        guard !text.isEmpty else { return nil }
        var total = 0.0

        for phrase in query.phrases {
            guard text.localizedCaseInsensitiveContains(phrase) else { return nil }
            total += weight * 1.35
        }
        for word in query.words {
            guard text.localizedCaseInsensitiveContains(word) else { return nil }
            total += weight
            if text.localizedCaseInsensitiveCompare(word) == .orderedSame {
                total += weight * 0.9   // an exact title is almost always the intent
            } else if text.lowercased().hasPrefix(word.lowercased()) {
                total += weight * 0.25
            }
        }
        return total > 0 ? total : nil
    }

    private static func bodyMatch(_ text: String, query: SearchQuery) -> (score: Double, count: Int, range: NSRange)? {
        guard !text.isEmpty else { return nil }
        let ns = text as NSString
        var first: NSRange?
        var count = 0
        var score = 0.0

        // `in:dialogue` searches the spoken parts only. Ranges are still reported
        // against the whole document, so the result opens the scene at the line
        // and the caret lands inside the speech rather than at the top.
        let spans = query.filters.contains(.dialogue) ? dialogueSpans(in: ns) : [NSRange(location: 0, length: ns.length)]
        guard !spans.isEmpty else { return nil }

        for needle in query.highlightable {
            var occurrences = 0
            for span in spans {
                var searchStart = span.location
                let end = span.location + span.length
                while searchStart < end {
                    let remaining = NSRange(location: searchStart, length: end - searchStart)
                    let found = ns.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive], range: remaining)
                    guard found.location != NSNotFound else { break }
                    occurrences += 1
                    if first == nil { first = found }
                    searchStart = found.location + max(1, found.length)
                    if occurrences > 40 { break }   // frequency stops informing rank quickly
                }
                if occurrences > 40 { break }
            }
            guard occurrences > 0 else { return nil }
            count += occurrences
            score += 10 + min(Double(occurrences), 6) * 2.5
        }

        guard let range = first else { return nil }
        return (score, count, range)
    }

    /// The quoted runs in a document.
    ///
    /// Straight and curly quotes both, because a manuscript contains both — the
    /// author types one and the editor smartens it, and half a book is usually
    /// mid-conversion. A run that never closes is ignored rather than swallowing
    /// the rest of the chapter.
    private static let dialoguePattern = try? NSRegularExpression(
        pattern: "[\u{201C}\"][^\u{201C}\u{201D}\"]{0,600}?[\u{201D}\"]"
    )

    private static func dialogueSpans(in text: NSString) -> [NSRange] {
        guard let dialoguePattern else { return [] }
        return dialoguePattern
            .matches(in: text as String, range: NSRange(location: 0, length: text.length))
            .map(\.range)
    }

    private static func highlightRanges(in snippet: String, query: SearchQuery) -> [Range<String.Index>] {
        guard !snippet.isEmpty else { return [] }
        var ranges: [Range<String.Index>] = []

        for needle in query.highlightable {
            var cursor = snippet.startIndex
            while cursor < snippet.endIndex,
                  let found = snippet.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive], range: cursor..<snippet.endIndex) {
                ranges.append(found)
                cursor = found.upperBound
                if ranges.count > 24 { return ranges }
            }
        }
        return ranges.sorted { $0.lowerBound < $1.lowerBound }
    }
}

// MARK: - Fuzzy matching

/// Subsequence matching for the command palette: "gtb" should find "Go to Story
/// Brain". Ranking rewards matches at word starts, because that is how people
/// abbreviate.
nonisolated enum Fuzzy {
    static func score(_ candidate: String, query: String) -> Double? {
        guard !query.isEmpty else { return 0 }
        let haystack = Array(candidate.lowercased())
        let needle = Array(query.lowercased().filter { !$0.isWhitespace })
        guard !needle.isEmpty, needle.count <= haystack.count else { return nil }

        var score = 0.0
        var haystackIndex = 0
        var previousMatch = -1

        for character in needle {
            var matched = false
            while haystackIndex < haystack.count {
                defer { haystackIndex += 1 }
                guard haystack[haystackIndex] == character else { continue }

                let atStart = haystackIndex == 0
                let afterSeparator = haystackIndex > 0 && !haystack[haystackIndex - 1].isLetter && !haystack[haystackIndex - 1].isNumber
                if atStart || afterSeparator {
                    score += 8            // matched the start of a word
                } else if previousMatch == haystackIndex - 1 {
                    score += 5            // contiguous run
                } else {
                    score += 1
                }
                previousMatch = haystackIndex
                matched = true
                break
            }
            guard matched else { return nil }
        }

        // Prefer the tighter of two candidates that both match.
        return score - Double(haystack.count) * 0.05
    }
}

//
//  StoryModel.swift
//  StoryLoom
//
//  The canonical project and document types. Per 04-Data-Model, every canonical
//  object carries an immutable opaque UUID, the Markdown body is the authority
//  for prose, and front matter is the authority for author-declared metadata —
//  including front matter this version of StoryLoom does not understand.
//

import SwiftUI

// MARK: - Project

nonisolated struct StoryProject: Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var documents: [StoryDocument]
    var story: StoryMetadata
    var archivedDocuments: [StoryDocument]

    nonisolated init(
        id: UUID = UUID(),
        title: String,
        documents: [StoryDocument],
        story: StoryMetadata = .init(),
        archivedDocuments: [StoryDocument] = []
    ) {
        self.id = id
        self.title = title
        self.documents = documents
        self.story = story
        self.archivedDocuments = archivedDocuments
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, documents, story, archivedDocuments
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        documents = try container.decode([StoryDocument].self, forKey: .documents)
        story = try container.decodeIfPresent(StoryMetadata.self, forKey: .story) ?? .init()
        archivedDocuments = try container.decodeIfPresent([StoryDocument].self, forKey: .archivedDocuments) ?? []
    }

    var scenes: [StoryDocument] { documents.filter { $0.kind == .scene } }

    var totalWordCount: Int {
        documents.reduce(0) { $0 + $1.wordCount }
    }

    /// Chapters in manuscript order. Contiguity is deliberate: a manually
    /// reordered manuscript must never be silently reshuffled because two
    /// chapters happen to share a title.
    var chapters: [Chapter] {
        documents.reduce(into: []) { groups, document in
            let title = document.chapterTitle
            if let last = groups.last, last.title == title {
                groups[groups.count - 1] = Chapter(
                    id: last.id,
                    title: title,
                    documents: last.documents + [document]
                )
            } else {
                groups.append(Chapter(id: document.id, title: title, documents: [document]))
            }
        }
    }

    /// True once any scene claims a volume. Until then the outline has two
    /// tiers, not three, and says nothing about a level the book does not use.
    var usesVolumes: Bool {
        documents.contains { !$0.volumeTitle.isEmpty }
    }

    /// The manuscript as Volume → Chapter → Scene.
    ///
    /// Grouped by contiguity at both levels, for the same reason chapters are:
    /// the array *is* the running order, and a book where "Part Two" appears,
    /// gives way to an interlude, and then resumes is a book, not a mistake to
    /// be tidied. Sorting by title would silently reorder the manuscript.
    var volumes: [Volume] {
        chapters.reduce(into: []) { groups, chapter in
            let title = chapter.documents.first?.volumeTitle ?? ""
            if let last = groups.last, last.title == title {
                groups[groups.count - 1] = Volume(
                    id: last.id,
                    title: title,
                    chapters: last.chapters + [chapter]
                )
            } else {
                groups.append(Volume(id: chapter.id, title: title, chapters: [chapter]))
            }
        }
    }

    func document(_ id: StoryDocument.ID) -> StoryDocument? {
        documents.first { $0.id == id } ?? archivedDocuments.first { $0.id == id }
    }

    func entity(_ id: StoryEntity.ID) -> StoryEntity? {
        story.entities.first { $0.id == id }
    }

    func thread(_ id: StoryThread.ID) -> StoryThread? {
        story.threads.first { $0.id == id }
    }

    /// Every scene that touches `threadID`, in the order the reader meets them.
    func scenes(touching threadID: StoryThread.ID) -> [StoryDocument] {
        documents.filter { $0.kind == .scene && !$0.roles(for: threadID).isEmpty }
    }

    nonisolated struct Chapter: Identifiable, Hashable, Sendable {
        let id: UUID
        let title: String
        let documents: [StoryDocument]

        var wordCount: Int { documents.reduce(0) { $0 + $1.wordCount } }
    }

    /// A part, a book-within-a-book — whatever the author calls the tier above
    /// chapters. Derived, never stored: the only durable fact is the `volume`
    /// string on each scene, so there is no separate list of volumes to fall out
    /// of step with the manuscript.
    nonisolated struct Volume: Identifiable, Hashable, Sendable {
        let id: UUID
        let title: String
        let chapters: [Chapter]

        var documents: [StoryDocument] { chapters.flatMap(\.documents) }
        var wordCount: Int { chapters.reduce(0) { $0 + $1.wordCount } }
    }
}

// MARK: - Document

/// A scene, and the four questions a scene has to be able to answer.
///
/// The fields below are not a metadata schema. They are the interrogation a
/// developmental editor puts a scene through, and a scene that cannot survive it
/// is a scene that will be cut in revision — three hundred thousand words later,
/// after it has been polished twice. `intention`, `turn`, `withheld` and `residue`
/// are all optional, all private, and all cheaper to answer now than to discover
/// later.
///
/// What is *not* here matters as much. There are no free-text tags: an uncurated
/// bag of strings is the first thing to rot in a long project, and by volume three
/// it is a folksonomy nobody remembers the rules of. What tags were reached for —
/// "which scenes carry the promise?" — is a real question, and it is answered
/// properly by [StoryThread] instead.
nonisolated struct StoryDocument: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var title: String
    /// The part of the book this belongs to, above the chapter.
    ///
    /// Empty is the normal case and means "this book does not have volumes" —
    /// most novels do not, and an outline that forces one is an outline that
    /// makes every writer invent a name for a level they are not using. The
    /// navigator only draws the volume tier when at least one scene names one.
    var volume: String = ""
    var chapter: String
    var kind: DocumentKind
    var text: String

    // MARK: The four questions

    /// Why does this scene exist? The author's private note about what it must
    /// accomplish. A prompt to themselves, never a required field (11-UX).
    var intention: String
    /// What changes? The turn. If nothing is different on the last line than it was
    /// on the first, the scene is a place the story visited, not a scene.
    var turn: String = ""
    /// What must not be revealed here? The most easily lost piece of craft in a long
    /// book: the author remembers what a scene must say, and forgets what it must
    /// not — and a mystery is spent the moment it is spent early.
    var withheld: String = ""
    /// What emotional state should remain? What the reader carries into the next
    /// scene. This is the thing the next scene is standing on.
    var residue: String = ""

    // MARK: Threads

    /// The questions this scene puts into the reader's head, moves along, and
    /// finally answers. Author-declared, never guessed.
    var opensThreadIDs: [UUID] = []
    var advancesThreadIDs: [UUID] = []
    var landsThreadIDs: [UUID] = []

    // MARK: Craft state

    var status: DocumentStatus = .draft
    /// Point-of-view character, recorded as the author writes it. StoryLoom links
    /// it to an entity by name when one matches, and shrugs when none does.
    var pov: String = ""
    var location: String = ""
    var targetWordCount: Int = 500
    /// Front matter this version of StoryLoom does not understand, preserved
    /// verbatim so an external editor's fields survive a StoryLoom save
    /// (05-Project-Format, "Readers must preserve unknown fields").
    var preservedFrontMatter: [String] = []

    nonisolated init(
        id: UUID = UUID(),
        title: String,
        volume: String = "",
        chapter: String,
        kind: DocumentKind,
        text: String,
        intention: String = "",
        turn: String = "",
        withheld: String = "",
        residue: String = "",
        opensThreadIDs: [UUID] = [],
        advancesThreadIDs: [UUID] = [],
        landsThreadIDs: [UUID] = [],
        status: DocumentStatus = .draft,
        pov: String = "",
        location: String = "",
        targetWordCount: Int = 500,
        preservedFrontMatter: [String] = []
    ) {
        self.id = id
        self.title = title
        self.volume = volume
        self.chapter = chapter
        self.kind = kind
        self.text = text
        self.intention = intention
        self.turn = turn
        self.withheld = withheld
        self.residue = residue
        self.opensThreadIDs = opensThreadIDs
        self.advancesThreadIDs = advancesThreadIDs
        self.landsThreadIDs = landsThreadIDs
        self.status = status
        self.pov = pov
        self.location = location
        self.targetWordCount = targetWordCount
        self.preservedFrontMatter = preservedFrontMatter
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, volume, chapter, kind, text
        case intention, turn, withheld, residue
        case opensThreadIDs, advancesThreadIDs, landsThreadIDs
        case status, pov, location, targetWordCount, preservedFrontMatter
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        volume = try container.decodeIfPresent(String.self, forKey: .volume) ?? ""
        chapter = try container.decode(String.self, forKey: .chapter)
        kind = try container.decode(DocumentKind.self, forKey: .kind)
        text = try container.decode(String.self, forKey: .text)
        intention = try container.decodeIfPresent(String.self, forKey: .intention) ?? ""
        turn = try container.decodeIfPresent(String.self, forKey: .turn) ?? ""
        withheld = try container.decodeIfPresent(String.self, forKey: .withheld) ?? ""
        residue = try container.decodeIfPresent(String.self, forKey: .residue) ?? ""
        opensThreadIDs = try container.decodeIfPresent([UUID].self, forKey: .opensThreadIDs) ?? []
        advancesThreadIDs = try container.decodeIfPresent([UUID].self, forKey: .advancesThreadIDs) ?? []
        landsThreadIDs = try container.decodeIfPresent([UUID].self, forKey: .landsThreadIDs) ?? []
        status = try container.decodeIfPresent(DocumentStatus.self, forKey: .status) ?? .draft
        pov = try container.decodeIfPresent(String.self, forKey: .pov) ?? ""
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        targetWordCount = try container.decodeIfPresent(Int.self, forKey: .targetWordCount) ?? 500
        preservedFrontMatter = try container.decodeIfPresent([String].self, forKey: .preservedFrontMatter) ?? []
    }

    var chapterTitle: String {
        let trimmed = chapter.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unassigned" : trimmed
    }

    /// Empty when this scene is not in a volume — distinct from `chapterTitle`,
    /// which invents "Unassigned" because a scene must sit somewhere in the
    /// outline. A book with no volumes should show no volume tier at all rather
    /// than a row called "Unassigned" wrapped around the whole manuscript.
    var volumeTitle: String {
        volume.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled \(kind.title)" : trimmed
    }

    var wordCount: Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Thread links

    func roles(for threadID: UUID) -> [ThreadRole] {
        var roles: [ThreadRole] = []
        if opensThreadIDs.contains(threadID) { roles.append(.opens) }
        if advancesThreadIDs.contains(threadID) { roles.append(.advances) }
        if landsThreadIDs.contains(threadID) { roles.append(.lands) }
        return roles
    }

    func threadIDs(for role: ThreadRole) -> [UUID] {
        switch role {
        case .opens: opensThreadIDs
        case .advances: advancesThreadIDs
        case .lands: landsThreadIDs
        }
    }

    /// A scene can only hold one role per thread. Asking a scene to both open and
    /// advance the same question is asking it to be two scenes.
    mutating func setRole(_ role: ThreadRole?, forThread threadID: UUID) {
        opensThreadIDs.removeAll { $0 == threadID }
        advancesThreadIDs.removeAll { $0 == threadID }
        landsThreadIDs.removeAll { $0 == threadID }
        switch role {
        case .opens: opensThreadIDs.append(threadID)
        case .advances: advancesThreadIDs.append(threadID)
        case .lands: landsThreadIDs.append(threadID)
        case nil: break
        }
    }

    var touchesAnyThread: Bool {
        !opensThreadIDs.isEmpty || !advancesThreadIDs.isEmpty || !landsThreadIDs.isEmpty
    }
}

nonisolated enum DocumentKind: String, Codable, CaseIterable, Hashable, Sendable {
    case scene
    case note

    var title: String { rawValue.capitalized }

    var glyph: Glyph {
        switch self {
        case .scene: .alignStart
        case .note: .note
        }
    }

    var icon: IconSource { .glyph(glyph) }

    var tint: Color {
        switch self {
        case .scene: .accentColor
        case .note: .orange
        }
    }
}

/// The life of a scene. This is a writing state, not a score: no percentage, no
/// completion metric, no badge (01-Manifesto, 12-UI).
nonisolated enum DocumentStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case outline
    case draft
    case revised
    case done

    var title: String {
        switch self {
        case .outline: "Outline"
        case .draft: "Draft"
        case .revised: "Revised"
        case .done: "Done"
        }
    }

    var tint: Color {
        switch self {
        case .outline: .secondary
        case .draft: Palette.caution
        case .revised: Palette.question
        case .done: Palette.confirmed
        }
    }

    /// Outline and draft read as "in motion"; a hollow dot says so without a badge.
    var isFilled: Bool {
        switch self {
        case .outline: false
        case .draft, .revised, .done: true
        }
    }
}

// MARK: - Timestamps

/// How StoryLoom writes and reads a moment in time.
///
/// Timestamps are ISO-8601 with milliseconds. Whole seconds would read more
/// prettily, but two save points made in the same second would then be
/// indistinguishable and History would list them in whatever order the file system
/// happened to return — so a millisecond is the smallest unit that still gives the
/// author's history a true order. Reading accepts whole seconds too, because a
/// person editing the file by hand will write whole seconds and should not be
/// punished for it (05-Project-Format).
nonisolated enum Timestamp {
    private static let writer: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let reader: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    nonisolated static func string(from date: Date) -> String { writer.string(from: date) }

    nonisolated static func date(from string: String) -> Date? {
        writer.date(from: string) ?? reader.date(from: string)
    }

    /// Applied to every encoder that touches a canonical file, so the policy lives
    /// in one place rather than being remembered at four call sites.
    nonisolated static func apply(to encoder: JSONEncoder) {
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(string(from: date))
        }
    }

    nonisolated static func apply(to decoder: JSONDecoder) {
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            guard let value = date(from: raw) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "Not an ISO-8601 date: \(raw)")
                )
            }
            return value
        }
    }
}

extension Date {
    /// A timestamp at the precision the project format can actually keep.
    ///
    /// A plain `Date()` carries sub-microsecond precision no file here can hold, so
    /// a project saved and reloaded would not equal the one still in memory — and
    /// equality is what undo, save points and external-change detection are all
    /// built on. Born at the format's precision, a timestamp survives the round
    /// trip unchanged.
    nonisolated static var stamp: Date {
        Date(timeIntervalSince1970: (Date().timeIntervalSince1970 * 1_000).rounded() / 1_000)
    }
}

//
//  StoryMetadata.swift
//  StoryLoom
//
//  Canonical, author-confirmed story records. Everything in this file is truth
//  the author asserted, not truth the system inferred. Derived material —
//  mentions, evidence, continuity findings, search indexes — is rebuildable and
//  deliberately lives elsewhere (04-Data-Model, "Identity and invariants").
//

import SwiftUI

nonisolated struct StoryMetadata: Codable, Equatable, Sendable {
    /// The questions the reader is carrying. First in the file because they are
    /// first in the book.
    var threads: [StoryThread] = []
    var entities: [StoryEntity] = []
    var relationships: [StoryRelationship] = []
    var events: [StoryEvent] = []
    var notes: [StoryNote] = []
    var comments: [StoryComment] = []
    /// What the author decided about each continuity finding. The finding itself
    /// is derived and disposable; the author's judgement about it is canonical.
    /// This is the system "learning only the disposition" (11-UX).
    var dispositions: [String: FindingDisposition] = [:]
    var projectWordTarget: Int = 50000
    /// What has been thrown away but not yet given up on. See `TrashedItem`.
    var trash: [TrashedItem] = []

    nonisolated init(
        threads: [StoryThread] = [],
        entities: [StoryEntity] = [],
        relationships: [StoryRelationship] = [],
        events: [StoryEvent] = [],
        notes: [StoryNote] = [],
        comments: [StoryComment] = [],
        dispositions: [String: FindingDisposition] = [:],
        projectWordTarget: Int = 50000,
        trash: [TrashedItem] = []
    ) {
        self.threads = threads
        self.entities = entities
        self.relationships = relationships
        self.events = events
        self.notes = notes
        self.comments = comments
        self.dispositions = dispositions
        self.projectWordTarget = projectWordTarget
        self.trash = trash
    }

    nonisolated enum CodingKeys: String, CodingKey {
        case threads, entities, relationships, events, notes, comments, dispositions, projectWordTarget, trash
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        threads = try container.decodeIfPresent([StoryThread].self, forKey: .threads) ?? []
        entities = try container.decodeIfPresent([StoryEntity].self, forKey: .entities) ?? []
        relationships = try container.decodeIfPresent([StoryRelationship].self, forKey: .relationships) ?? []
        events = try container.decodeIfPresent([StoryEvent].self, forKey: .events) ?? []
        notes = try container.decodeIfPresent([StoryNote].self, forKey: .notes) ?? []
        comments = try container.decodeIfPresent([StoryComment].self, forKey: .comments) ?? []
        dispositions = try container.decodeIfPresent([String: FindingDisposition].self, forKey: .dispositions) ?? [:]
        projectWordTarget = try container.decodeIfPresent(Int.self, forKey: .projectWordTarget) ?? 50000
        trash = try container.decodeIfPresent([TrashedItem].self, forKey: .trash) ?? []
    }

    func thread(_ id: StoryThread.ID) -> StoryThread? {
        threads.first { $0.id == id }
    }

    func entity(named name: String) -> StoryEntity? {
        let needle = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return nil }
        return entities.first { entity in
            ([entity.name] + entity.aliases).contains { $0.caseInsensitiveCompare(needle) == .orderedSame }
        }
    }

    func comments(for documentID: UUID) -> [StoryComment] {
        comments.filter { $0.documentID == documentID }
    }
}

// MARK: - Entities

nonisolated struct StoryEntity: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var kind: EntityKind
    var summary: String
    var aliases: [String]
    /// Author-recorded, never inferred and never validated against a list
    /// (14-Character-System, "pronouns as author-recorded").
    var pronouns: String = ""
    /// A free-text role: "protagonist", "the one who lies", whatever is useful.
    var role: String = ""
    var linkedDocumentIDs: [UUID] = []

    nonisolated init(
        id: UUID = UUID(),
        name: String,
        kind: EntityKind,
        summary: String = "",
        aliases: [String] = [],
        pronouns: String = "",
        role: String = "",
        linkedDocumentIDs: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.summary = summary
        self.aliases = aliases
        self.pronouns = pronouns
        self.role = role
        self.linkedDocumentIDs = linkedDocumentIDs
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, kind, summary, aliases, pronouns, role, linkedDocumentIDs
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        kind = try container.decode(EntityKind.self, forKey: .kind)
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
        pronouns = try container.decodeIfPresent(String.self, forKey: .pronouns) ?? ""
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? ""
        linkedDocumentIDs = try container.decodeIfPresent([UUID].self, forKey: .linkedDocumentIDs) ?? []
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled \(kind.title)" : trimmed
    }

    /// Every name this entity answers to, used for evidence matching.
    var searchTerms: [String] {
        ([name] + aliases)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

nonisolated enum EntityKind: String, CaseIterable, Codable, Hashable, Sendable {
    case character
    case location
    case object
    case organization
    case theme
    case symbol

    var title: String { rawValue.capitalized }

    var plural: String {
        switch self {
        case .character: "Characters"
        case .location: "Locations"
        case .object: "Objects"
        case .organization: "Organizations"
        case .theme: "Themes"
        case .symbol: "Symbols"
        }
    }

    var glyph: Glyph {
        switch self {
        case .character: .character
        case .location: .location
        case .object: .object
        case .organization: .organization
        case .theme: .themeMotif
        case .symbol: .symbolMotif
        }
    }

    var icon: IconSource { .glyph(glyph) }

    var tint: Color {
        switch self {
        case .character: .indigo
        case .location: .teal
        case .object: .orange
        case .organization: .purple
        case .theme: .pink
        case .symbol: .mint
        }
    }
}

// MARK: - Relationships

nonisolated struct StoryRelationship: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var sourceEntityID: UUID
    var targetEntityID: UUID
    var kind: RelationshipKind
    var label: String
    var summary: String

    nonisolated init(
        id: UUID = UUID(),
        sourceEntityID: UUID,
        targetEntityID: UUID,
        kind: RelationshipKind,
        label: String = "",
        summary: String = ""
    ) {
        self.id = id
        self.sourceEntityID = sourceEntityID
        self.targetEntityID = targetEntityID
        self.kind = kind
        self.label = label
        self.summary = summary
    }

    func involves(_ entityID: UUID) -> Bool {
        sourceEntityID == entityID || targetEntityID == entityID
    }

    func other(than entityID: UUID) -> UUID {
        sourceEntityID == entityID ? targetEntityID : sourceEntityID
    }
}

nonisolated enum RelationshipKind: String, CaseIterable, Codable, Hashable, Sendable {
    case knows
    case family
    case loves
    case opposes
    case owes
    case conceals
    case belongsTo
    case locatedIn
    case custom

    var title: String {
        switch self {
        case .knows: "Knows"
        case .family: "Family"
        case .loves: "Loves"
        case .opposes: "Opposes"
        case .owes: "Owes"
        case .conceals: "Conceals From"
        case .belongsTo: "Belongs To"
        case .locatedIn: "Located In"
        case .custom: "Custom"
        }
    }

    var glyph: Glyph {
        switch self {
        case .knows: .family
        case .family: .family
        case .loves: .loves
        case .opposes: .opposes
        case .owes: .relationshipEdge
        case .conceals: .conceals
        case .belongsTo: .link
        case .locatedIn: .location
        case .custom: .unspecified
        }
    }
}

// MARK: - Events

nonisolated struct StoryEvent: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var title: String
    /// How the author refers to when this happened: "Night 1, before high tide".
    /// A fictional world owes no one a calendar (15-Timeline).
    var chronologyLabel: String
    /// How sure the author is of the placement. Unknown is first-class.
    var certainty: EventCertainty = .stated
    /// The scene in which the reader encounters this event, which is a different
    /// question from when the event occurs.
    var narrativeDocumentID: UUID?
    var participantIDs: [UUID] = []
    var summary: String = ""

    nonisolated init(
        id: UUID = UUID(),
        title: String,
        chronologyLabel: String = "",
        certainty: EventCertainty = .stated,
        narrativeDocumentID: UUID? = nil,
        participantIDs: [UUID] = [],
        summary: String = ""
    ) {
        self.id = id
        self.title = title
        self.chronologyLabel = chronologyLabel
        self.certainty = certainty
        self.narrativeDocumentID = narrativeDocumentID
        self.participantIDs = participantIDs
        self.summary = summary
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, chronologyLabel, certainty, narrativeDocumentID, participantIDs, summary
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        chronologyLabel = try container.decodeIfPresent(String.self, forKey: .chronologyLabel) ?? ""
        certainty = try container.decodeIfPresent(EventCertainty.self, forKey: .certainty) ?? .stated
        narrativeDocumentID = try container.decodeIfPresent(UUID.self, forKey: .narrativeDocumentID)
        participantIDs = try container.decodeIfPresent([UUID].self, forKey: .participantIDs) ?? []
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Event" : trimmed
    }
}

/// "Uncertainty is data" (01-Manifesto). An event the author has not placed is
/// modelled as unplaced, not given an invented position.
nonisolated enum EventCertainty: String, CaseIterable, Codable, Hashable, Sendable {
    case stated
    case approximate
    case disputed
    case unplaced

    var title: String {
        switch self {
        case .stated: "Stated"
        case .approximate: "Approximate"
        case .disputed: "Disputed"
        case .unplaced: "Unplaced"
        }
    }

    var detail: String {
        switch self {
        case .stated: "The author has placed this event."
        case .approximate: "Roughly placed; the order matters more than the moment."
        case .disputed: "Sources inside the story disagree about this."
        case .unplaced: "Position unknown. StoryLoom will not invent one."
        }
    }

    var glyph: Glyph {
        switch self {
        case .stated: .circleDot
        case .approximate: .unsaved
        case .disputed: .mystery
        case .unplaced: .circleOff
        }
    }

    var tint: Color {
        switch self {
        case .stated: .accentColor
        case .approximate: Palette.question
        case .disputed: Palette.caution
        case .unplaced: .secondary
        }
    }
}

// MARK: - Notes

nonisolated struct StoryNote: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var title: String
    var body: String
    var updatedAt = Date.stamp

    nonisolated init(id: UUID = UUID(), title: String, body: String = "", updatedAt: Date = .stamp) {
        self.id = id
        self.title = title
        self.body = body
        self.updatedAt = updatedAt
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Note" : trimmed
    }
}

// MARK: - Finding dispositions

/// What the author decided about a continuity finding. Dismissing is not the
/// same as declaring the tension deliberate, and StoryLoom keeps the difference:
/// a dismissed finding may return, an intentional one is left alone.
nonisolated enum FindingDisposition: String, Codable, CaseIterable, Hashable, Sendable {
    case dismissed
    case intentional

    var title: String {
        switch self {
        case .dismissed: "Dismissed"
        case .intentional: "Intentional"
        }
    }

    var symbolName: String {
        switch self {
        case .dismissed: "xmark.circle"
        case .intentional: "checkmark.seal"
        }
    }

    var tint: Color {
        switch self {
        case .dismissed: .secondary
        case .intentional: Palette.intentional
        }
    }
}

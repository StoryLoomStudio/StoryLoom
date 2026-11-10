// Mirrors of the v1 on-disk JSON, field for field.
//
// The app's own types cannot be imported here (they live in the app target and
// import SwiftUI), so these re-state their Codable shape. The app's test target
// compiles this file too, and `V1FixtureCompatibilityTests` loads a generated
// project with the real `LocalProjectRepository` and checks it writes the same
// bytes back — so a drift between these mirrors and the app fails a test.
//
// Optional properties are optional here for the same reason as there: a nil one
// is omitted from the JSON, not written as null.

import Foundation

nonisolated struct V1Document: Codable, Equatable {
    var id: UUID
    var title: String
    var volume: String
    var chapter: String
    var kind: String
    var text: String
    var intention: String
    var turn: String
    var withheld: String
    var residue: String
    var opensThreadIDs: [UUID]
    var advancesThreadIDs: [UUID]
    var landsThreadIDs: [UUID]
    var status: String
    var pov: String
    var location: String
    var targetWordCount: Int
    var preservedFrontMatter: [String]

    var wordCount: Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}

nonisolated struct V1BinderItem: Codable, Equatable {
    var id: UUID
    var kind: String
    var group: String
    var name: String
    var children: [V1BinderItem]
}

nonisolated struct V1Thread: Codable, Equatable {
    var id: UUID
    var question: String
    var kind: String
    var answer: String
    var isAbandoned: Bool
}

nonisolated struct V1Entity: Codable, Equatable {
    var id: UUID
    var name: String
    var kind: String
    var summary: String
    var aliases: [String]
    var pronouns: String
    var role: String
    var linkedDocumentIDs: [UUID]
}

nonisolated struct V1Relationship: Codable, Equatable {
    var id: UUID
    var sourceEntityID: UUID
    var targetEntityID: UUID
    var kind: String
    var label: String
    var summary: String
}

nonisolated struct V1Event: Codable, Equatable {
    var id: UUID
    var title: String
    var chronologyLabel: String
    var certainty: String
    var narrativeDocumentID: UUID?
    var participantIDs: [UUID]
    var summary: String
}

nonisolated struct V1Note: Codable, Equatable {
    var id: UUID
    var title: String
    var body: String
    var updatedAt: Date
}

nonisolated struct V1Anchor: Codable, Equatable {
    var quote: String
    var prefix: String
    var suffix: String
    var offsetHint: Int

    /// The app's `TextAnchor.make`: up to 32 UTF-16 units of context each side.
    static func make(in text: String, range: NSRange) -> V1Anchor {
        let ns = text as NSString
        let prefixStart = max(0, range.location - 32)
        let suffixStart = range.location + range.length
        let suffixLength = max(0, min(32, ns.length - suffixStart))
        return V1Anchor(
            quote: ns.substring(with: range),
            prefix: ns.substring(with: NSRange(location: prefixStart, length: range.location - prefixStart)),
            suffix: ns.substring(with: NSRange(location: suffixStart, length: suffixLength)),
            offsetHint: range.location
        )
    }
}

nonisolated struct V1Comment: Codable, Equatable {
    var id: UUID
    var documentID: UUID
    var anchor: V1Anchor
    var body: String
    var createdAt: Date
    var resolvedAt: Date?
}

nonisolated struct V1Run: Codable, Equatable {
    var id: UUID
    var location: Int
    var length: Int
    var anchor: V1Anchor
    var underline: Bool
    var highlight: String?
    var fontName: String?
    var fontSize: Double?
}

nonisolated struct V1Block: Codable, Equatable {
    var id: UUID
    var location: Int
    var length: Int
    var anchor: V1Anchor
    var alignment: String
}

nonisolated struct V1Layer: Codable, Equatable {
    var runs: [V1Run]
    var blocks: [V1Block]
}

/// `TrashedPayload` as Swift synthesizes it: `{"document":{"_0":{…}}}`, and for
/// the two-value case `{"group":{"_0":{…},"_1":[…]}}`.
nonisolated enum V1Payload: Codable, Equatable {
    case document(V1Document)
    case group(V1BinderItem, [V1Document])
    case entity(V1Entity)
    case note(V1Note)

    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(_ string: String) { stringValue = string }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    func encode(to encoder: Encoder) throws {
        var outer = encoder.container(keyedBy: Key.self)
        switch self {
        case .document(let value):
            var inner = outer.nestedContainer(keyedBy: Key.self, forKey: Key("document"))
            try inner.encode(value, forKey: Key("_0"))
        case .group(let item, let documents):
            var inner = outer.nestedContainer(keyedBy: Key.self, forKey: Key("group"))
            try inner.encode(item, forKey: Key("_0"))
            try inner.encode(documents, forKey: Key("_1"))
        case .entity(let value):
            var inner = outer.nestedContainer(keyedBy: Key.self, forKey: Key("entity"))
            try inner.encode(value, forKey: Key("_0"))
        case .note(let value):
            var inner = outer.nestedContainer(keyedBy: Key.self, forKey: Key("note"))
            try inner.encode(value, forKey: Key("_0"))
        }
    }

    init(from decoder: Decoder) throws {
        let outer = try decoder.container(keyedBy: Key.self)
        if outer.contains(Key("document")) {
            let inner = try outer.nestedContainer(keyedBy: Key.self, forKey: Key("document"))
            self = .document(try inner.decode(V1Document.self, forKey: Key("_0")))
        } else if outer.contains(Key("group")) {
            let inner = try outer.nestedContainer(keyedBy: Key.self, forKey: Key("group"))
            self = .group(try inner.decode(V1BinderItem.self, forKey: Key("_0")),
                          try inner.decode([V1Document].self, forKey: Key("_1")))
        } else if outer.contains(Key("entity")) {
            let inner = try outer.nestedContainer(keyedBy: Key.self, forKey: Key("entity"))
            self = .entity(try inner.decode(V1Entity.self, forKey: Key("_0")))
        } else {
            let inner = try outer.nestedContainer(keyedBy: Key.self, forKey: Key("note"))
            self = .note(try inner.decode(V1Note.self, forKey: Key("_0")))
        }
    }
}

nonisolated struct V1Trashed: Codable, Equatable {
    var id: UUID
    var deletedAt: Date
    var payload: V1Payload
}

nonisolated struct V1Metadata: Codable, Equatable {
    var threads: [V1Thread]
    var entities: [V1Entity]
    var relationships: [V1Relationship]
    var events: [V1Event]
    var notes: [V1Note]
    var comments: [V1Comment]
    var dispositions: [String: String]
    var projectWordTarget: Int
    var trash: [V1Trashed]
}

nonisolated struct V1Project: Codable, Equatable {
    var id: UUID
    var title: String
    var documents: [V1Document]
    var story: V1Metadata
    var archivedDocuments: [V1Document]
    var binder: [V1BinderItem]
}

/// `story/presentation.json`.
nonisolated struct V1PresentationStore: Codable, Equatable {
    struct Entry: Codable, Equatable {
        var documentID: UUID
        var layer: V1Layer
    }

    var formatVersion: Int
    var entries: [Entry]
}

/// `story/binder.json` at format 2: directory path → group kind.
nonisolated struct V1GroupIndex: Codable, Equatable {
    var formatVersion: Int
    var groups: [String: String]
}

/// One file in `history/snapshots/`. `presentation` is a `[UUID: PresentationLayer]`
/// in the app, which Swift encodes as a flat `[key, value, key, value…]` array
/// (the key is not a String). The order of that array is whatever the
/// dictionary yields, so the app's own files are not byte-stable; this writes
/// the entries sorted by id.
nonisolated struct V1Snapshot: Encodable {
    var id: UUID
    var createdAt: Date
    var reason: String
    var projectTitle: String
    var wordCount: Int
    var documentCount: Int
    var project: V1Project
    var presentation: [UUID: V1Layer]

    private enum CodingKeys: String, CodingKey {
        case id, createdAt, reason, projectTitle, wordCount, documentCount, project, presentation
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(reason, forKey: .reason)
        try c.encode(projectTitle, forKey: .projectTitle)
        try c.encode(wordCount, forKey: .wordCount)
        try c.encode(documentCount, forKey: .documentCount)
        try c.encode(project, forKey: .project)
        var flat = c.nestedUnkeyedContainer(forKey: .presentation)
        for key in presentation.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
            try flat.encode(key)
            try flat.encode(presentation[key]!)
        }
    }
}

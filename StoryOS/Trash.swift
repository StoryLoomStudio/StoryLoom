//
//  Trash.swift
//  StoryLoom
//
//  Where deleted things wait.
//
//  Everything in this application used to delete outright. That is defensible for
//  a note and indefensible for a thread the author spent a year pulling through
//  four hundred pages — and the difference is invisible at the moment of the
//  click, which is exactly when the author is least able to judge it. A novelist
//  deleting a character at one in the morning is not making a considered
//  decision about the shape of the book.
//
//  So deletion became a move rather than an erasure. Nothing here is a new
//  concept for the author to learn: it is the Trash they already have on the
//  desktop, and it behaves the way that one does — things go in, they stay
//  legible, they come back where they were, and nothing leaves until somebody
//  says so.
//
//  A deleted scene keeps its prose. That is the whole reason this exists: the
//  words are the only thing in the project that cannot be rebuilt.
//
//  Snapshots are deliberately not trashable. They are already the undo history;
//  an undo history with its own undo history is a hall of mirrors, and a snapshot
//  is cheap to make again.
//

import Foundation
import SwiftUI

/// One thing thrown away, with enough of itself intact to be put back.
///
/// The whole value is kept, not a reference to it. A tombstone holding an ID
/// would need the original to survive somewhere to be restorable, which is the
/// thing being deleted — and it would rot silently the first time the format
/// changed underneath it.
nonisolated struct TrashedItem: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var deletedAt: Date
    var payload: TrashedPayload

    nonisolated init(id: UUID = UUID(), deletedAt: Date = .now, payload: TrashedPayload) {
        self.id = id
        self.deletedAt = deletedAt
        self.payload = payload
    }

    /// What it was called, so the row reads as the thing itself.
    var title: String {
        switch payload {
        case .document(let value): value.displayTitle
        case .thread(let value): value.question.isEmpty ? "Untitled thread" : value.question
        case .entity(let value): value.displayName
        case .relationship(let value): value.summary.isEmpty ? "Relationship" : value.summary
        case .event(let value): value.displayTitle
        case .note(let value): value.displayTitle
        }
    }

    /// Which room it will go back to.
    var category: String {
        switch payload {
        case .document(let value): value.chapterTitle
        case .thread: "Thread"
        case .entity: "Story"
        case .relationship: "Relationship"
        case .event: "Timeline"
        case .note: "Note"
        }
    }

    var icon: IconSource {
        switch payload {
        case .document(let value): value.kind.icon
        case .thread(let value): value.kind.icon
        case .entity(let value): value.kind.icon
        case .relationship: .glyph(.relationshipEdge)
        case .event: .glyph(.calendar)
        case .note: .glyph(.note)
        }
    }

    var tint: Color {
        switch payload {
        case .document(let value): value.kind.tint
        case .thread(let value): value.kind.tint
        case .entity(let value): value.kind.tint
        case .relationship: .secondary
        case .event: .secondary
        case .note: .orange
        }
    }
}

/// The deleted value itself.
///
/// An enum with associated values rather than a bag of optionals: it is not
/// possible to construct one of these that is two things at once, or none.
nonisolated enum TrashedPayload: Codable, Equatable, Sendable {
    case document(StoryDocument)
    case thread(StoryThread)
    case entity(StoryEntity)
    case relationship(StoryRelationship)
    case event(StoryEvent)
    case note(StoryNote)
}

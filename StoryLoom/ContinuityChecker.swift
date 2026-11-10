//
//  ContinuityChecker.swift
//  StoryLoom
//
//  Continuity findings, computed deterministically from author-confirmed records
//  and canonical prose. No inference, no model, no confidence theatre.
//
//  Every finding here obeys the manifesto: it is an invitation to inspect, not a
//  command to repair. It cites its evidence, it can be dismissed, and it can be
//  declared deliberate — because a novel is allowed to contain contradiction on
//  purpose, and a tool that cannot hear "I meant that" is a tool you turn off.
//
//  Findings are derived and disposable. The author's judgement about them is not:
//  dispositions live in canonical metadata and survive an index rebuild.
//

import Foundation
import SwiftUI

// MARK: - Finding

nonisolated struct StoryFinding: Identifiable, Hashable, Sendable {
    /// Deterministic, so that dismissing a finding today still dismisses the same
    /// finding after the index is thrown away and rebuilt tomorrow.
    let id: String
    let kind: FindingKind
    let title: String
    let detail: String
    var evidence: [FindingEvidence] = []
    var target: FindingTarget?

    var severity: FindingSeverity { kind.severity }
}

nonisolated enum FindingSeverity: Int, Comparable, Sendable {
    case question
    case caution
    case conflict

    static func < (lhs: FindingSeverity, rhs: FindingSeverity) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .question: "Question"
        case .caution: "Caution"
        case .conflict: "Conflict"
        }
    }

    var tint: Color {
        switch self {
        case .question: Palette.question
        case .caution: Palette.caution
        case .conflict: Palette.conflict
        }
    }

    var symbolName: String {
        switch self {
        case .question: "questionmark.circle"
        case .caution: "exclamationmark.triangle"
        case .conflict: "exclamationmark.octagon"
        }
    }
}

nonisolated enum FindingKind: String, CaseIterable, Sendable {
    case payoffBeforePromise
    case threadGoingQuiet
    case threadNeverOpened
    case threadNeverLanded
    case promisePaidInstantly
    case aliasCollision
    case unwrittenRecord
    case eventWithoutScene
    case participantNotNamed
    case chronologyInversion
    case orphanedComment
    case emptyScene
    case unknownPointOfView

    var severity: FindingSeverity {
        switch self {
        case .payoffBeforePromise: .conflict
        case .aliasCollision, .orphanedComment, .threadGoingQuiet: .caution
        case .threadNeverOpened, .threadNeverLanded, .promisePaidInstantly,
             .unwrittenRecord, .eventWithoutScene, .participantNotNamed,
             .chronologyInversion, .emptyScene, .unknownPointOfView: .question
        }
    }

    var groupTitle: String {
        switch self {
        case .payoffBeforePromise: "Answered before it was asked"
        case .threadGoingQuiet: "Threads going quiet"
        case .threadNeverOpened: "Questions the reader was never asked"
        case .threadNeverLanded: "Still owed to the reader"
        case .promisePaidInstantly: "Promises paid on the spot"
        case .aliasCollision: "Ambiguous names"
        case .unwrittenRecord: "Records not yet written"
        case .eventWithoutScene: "Events with no scene"
        case .participantNotNamed: "Participants not named"
        case .chronologyInversion: "Chronology and manuscript disagree"
        case .orphanedComment: "Comments that lost their anchor"
        case .emptyScene: "Scenes with an intention but no prose"
        case .unknownPointOfView: "Point of view without a record"
        }
    }
}

nonisolated struct FindingEvidence: Hashable, Sendable {
    var documentID: UUID?
    var documentTitle: String
    var excerpt: String
    /// Where in the document the evidence sits, so "Open" lands on the words.
    var range: NSRange?
}

nonisolated enum FindingTarget: Hashable, Sendable {
    case document(UUID, NSRange?)
    case thread(UUID)
    case entity(UUID)
    case event(UUID)
    case comment(UUID)
}

// MARK: - Checker

nonisolated enum ContinuityChecker {

    /// All findings, worst first, with the author's dispositions already applied.
    static func findings(for project: StoryProject, index: StoryIndex, arcs: [ThreadArc]) -> [StoryFinding] {
        var results: [StoryFinding] = []
        results += threadFindings(project, arcs)
        results += aliasCollisions(project)
        results += unwrittenRecords(project, index)
        results += eventsWithoutScenes(project)
        results += participantsNotNamed(project, index)
        results += chronologyInversions(project)
        results += orphanedComments(project)
        results += emptyScenes(project)
        results += unknownPointsOfView(project)

        return results.sorted {
            $0.severity == $1.severity ? $0.title < $1.title : $0.severity > $1.severity
        }
    }

    // MARK: Threads

    /// The questions a long book loses track of. Nothing here is a rule about
    /// craft — a thread may go quiet for four hundred pages on purpose — but the
    /// author should be the one deciding that, and at one million words they will
    /// not remember they have a decision to make unless something says so.
    private static func threadFindings(_ project: StoryProject, _ arcs: [ThreadArc]) -> [StoryFinding] {
        var results: [StoryFinding] = []
        let scenes = project.documents.filter { $0.kind == .scene }

        for arc in arcs {
            let thread = arc.thread
            let question = thread.displayQuestion

            // The payoff is read before the promise. This is the one thread failure
            // that is almost never intentional: the reader is handed an answer to a
            // question they have not been asked, and it lands as nothing at all.
            if let landed = arc.landedAt, let opened = arc.openedAt, landed < opened {
                let payoff = scenes.indices.contains(landed) ? scenes[landed].displayTitle : "a scene"
                let promise = scenes.indices.contains(opened) ? scenes[opened].displayTitle : "a later scene"

                results.append(StoryFinding(
                    id: "payoff-before-promise:\(thread.id.uuidString)",
                    kind: .payoffBeforePromise,
                    title: "“\(question)” is answered before it is asked",
                    detail: "“\(payoff)” lands this thread, but “\(promise)” is where the reader first hears the question — and it comes later in the manuscript. The answer will arrive as an answer to nothing.",
                    evidence: [],
                    target: .thread(thread.id)
                ))
            }

            // Opened and landed in the same scene, with nothing in between. A
            // promise the reader holds for one scene was not a promise.
            if let opened = arc.openedAt, let landed = arc.landedAt, landed == opened, arc.beats.count <= 2 {
                let scene = scenes.indices.contains(opened) ? scenes[opened].displayTitle : "one scene"

                results.append(StoryFinding(
                    id: "promise-paid-instantly:\(thread.id.uuidString)",
                    kind: .promisePaidInstantly,
                    title: "“\(question)” opens and closes in “\(scene)”",
                    detail: "The reader never carries this one anywhere. That is fine for a beat inside a scene — but if it was meant to pull them through the book, it needs somewhere to live in between.",
                    evidence: [],
                    target: .thread(thread.id)
                ))
            }

            // Going quiet. The count is stated, so the author can disagree with it
            // in one glance instead of trusting it.
            if arc.state == .cooling {
                results.append(StoryFinding(
                    id: "thread-going-quiet:\(thread.id.uuidString)",
                    kind: .threadGoingQuiet,
                    title: "Nothing has touched “\(question)” in \(arc.scenesSinceProgress) scenes",
                    detail: "\(arc.wordsSinceProgress.formatted()) words have gone by since anything advanced this. A slow burn looks exactly like this and so does a forgotten one — mark it intentional and StoryLoom will stop counting.",
                    evidence: [],
                    target: .thread(thread.id)
                ))
            }

            // Written but never asked: every scene advances it, none opens it.
            if arc.openedAt == nil, !arc.beats.isEmpty, !thread.isAbandoned {
                results.append(StoryFinding(
                    id: "thread-never-opened:\(thread.id.uuidString)",
                    kind: .threadNeverOpened,
                    title: "“\(question)” is advanced but never asked",
                    detail: "\(arc.beats.count) scene\(arc.beats.count == 1 ? "" : "s") move this thread along, but no scene opens it. The reader is watching the story answer a question they were never given.",
                    evidence: [],
                    target: .thread(thread.id)
                ))
            }
        }

        // What the reader is still owed, said once rather than thread by thread.
        // Seventeen separate rows saying "unresolved" is not seventeen problems —
        // it is one fact about where the book currently stops.
        let owed = arcs.filter { $0.isOwed && $0.openedAt != nil }
        if !owed.isEmpty {
            let questions = owed.prefix(4).map { "“\($0.thread.displayQuestion)”" }
            let remainder = owed.count - questions.count

            results.append(StoryFinding(
                id: "threads-never-landed:\(owed.map(\.thread.id.uuidString).sorted().joined(separator: ":"))",
                kind: .threadNeverLanded,
                title: owed.count == 1
                    ? "One thread is still open"
                    : "\(owed.count) threads are still open",
                detail: remainder > 0
                    ? "\(questions.joined(separator: ", ")) and \(remainder) more have no scene that lands them. If the manuscript is finished, so are these — mark them intentional or give them a payoff."
                    : "\(questions.joined(separator: ", ")) have no scene that lands them. That is exactly what an unfinished book looks like; it is only a problem when it is a finished one.",
                evidence: [],
                target: owed.first.map { .thread($0.thread.id) }
            ))
        }

        return results
    }

    // MARK: Ambiguous names

    /// Two records answering to the same name is a real problem: every piece of
    /// evidence for one is evidence for the other, and neither can be trusted.
    private static func aliasCollisions(_ project: StoryProject) -> [StoryFinding] {
        var byTerm: [String: [StoryEntity]] = [:]
        for entity in project.story.entities {
            for term in entity.searchTerms {
                byTerm[term.lowercased(), default: []].append(entity)
            }
        }

        return byTerm.compactMap { term, entities in
            let distinct = Dictionary(grouping: entities, by: \.id).values.compactMap(\.first)
            guard distinct.count > 1 else { return nil }
            let names = distinct.map(\.displayName).sorted()
            let ids = distinct.map(\.id.uuidString).sorted().joined(separator: ":")

            return StoryFinding(
                id: "alias-collision:\(term):\(ids)",
                kind: .aliasCollision,
                title: "“\(term)” refers to \(names.count) records",
                detail: "\(names.joined(separator: " and ")) share this name or alias. Evidence for one is evidence for the other, so StoryLoom cannot tell their mentions apart.",
                evidence: [],
                target: distinct.first.map { .entity($0.id) }
            )
        }
    }

    // MARK: Records not yet written

    private static func unwrittenRecords(_ project: StoryProject, _ index: StoryIndex) -> [StoryFinding] {
        project.story.entities.compactMap { entity in
            guard !index.isMentionedAnywhere(entity.id) else { return nil }
            guard !entity.searchTerms.isEmpty else { return nil }

            return StoryFinding(
                id: "unwritten-record:\(entity.id.uuidString)",
                kind: .unwrittenRecord,
                title: "\(entity.displayName) has not appeared yet",
                detail: "This record exists but no scene names it. That is entirely normal while planning — mark it intentional to stop asking.",
                evidence: [],
                target: .entity(entity.id)
            )
        }
    }

    // MARK: Events

    private static func eventsWithoutScenes(_ project: StoryProject) -> [StoryFinding] {
        project.story.events.compactMap { event in
            guard event.narrativeDocumentID == nil else { return nil }

            return StoryFinding(
                id: "event-without-scene:\(event.id.uuidString)",
                kind: .eventWithoutScene,
                title: "“\(event.displayTitle)” has no scene",
                detail: "The reader never encounters this event directly. Backstory is supposed to look like this — mark it intentional if the reader is meant to infer it.",
                evidence: [],
                target: .event(event.id)
            )
        }
    }

    /// The author said someone is in this event; the scene never names them. Often
    /// that is a pronoun doing its job, which is why this is a question, not an error.
    private static func participantsNotNamed(_ project: StoryProject, _ index: StoryIndex) -> [StoryFinding] {
        var results: [StoryFinding] = []

        for event in project.story.events {
            guard let documentID = event.narrativeDocumentID,
                  let document = project.document(documentID) else { continue }
            let named = Set(index.entityIDs(mentionedIn: documentID))

            for participantID in event.participantIDs {
                guard let entity = project.entity(participantID), !named.contains(participantID) else { continue }

                results.append(StoryFinding(
                    id: "participant-not-named:\(event.id.uuidString):\(participantID.uuidString)",
                    kind: .participantNotNamed,
                    title: "\(entity.displayName) is not named in “\(document.displayTitle)”",
                    detail: "“\(event.displayTitle)” lists \(entity.displayName) as a participant, but the scene never uses that name or an alias. A pronoun may be doing the work.",
                    evidence: [
                        FindingEvidence(
                            documentID: document.id,
                            documentTitle: document.displayTitle,
                            excerpt: String(document.text.prefix(160)),
                            range: nil
                        )
                    ],
                    target: .event(event.id)
                ))
            }
        }
        return results
    }

    /// Chronology and manuscript order are different orders on purpose (15-Timeline).
    /// When they disagree, that is a flashback — or a mistake. Only the author knows.
    private static func chronologyInversions(_ project: StoryProject) -> [StoryFinding] {
        let placement = Dictionary(
            uniqueKeysWithValues: project.documents.enumerated().map { ($0.element.id, $0.offset) }
        )

        let placed = project.story.events.compactMap { event -> (StoryEvent, Int)? in
            guard let documentID = event.narrativeDocumentID, let position = placement[documentID] else { return nil }
            return (event, position)
        }

        var results: [StoryFinding] = []
        for (index, current) in placed.enumerated() {
            guard index + 1 < placed.count else { break }
            let next = placed[index + 1]
            guard current.1 > next.1 else { continue }

            let earlier = project.document(current.0.narrativeDocumentID!)?.displayTitle ?? "a later scene"
            let later = project.document(next.0.narrativeDocumentID!)?.displayTitle ?? "an earlier scene"

            results.append(StoryFinding(
                id: "chronology-inversion:\(current.0.id.uuidString):\(next.0.id.uuidString)",
                kind: .chronologyInversion,
                title: "“\(current.0.displayTitle)” happens first but is read second",
                detail: "It appears in “\(earlier)”, after “\(later)”, where the later event is told. That is exactly what a flashback looks like — mark it intentional if it is one.",
                evidence: [],
                target: .event(current.0.id)
            ))
        }
        return results
    }

    // MARK: Comments

    private static func orphanedComments(_ project: StoryProject) -> [StoryFinding] {
        project.story.comments.compactMap { comment in
            guard !comment.isResolved,
                  let document = project.document(comment.documentID) else { return nil }
            guard comment.anchor.isOrphaned(in: document.text) else { return nil }

            return StoryFinding(
                id: "orphaned-comment:\(comment.id.uuidString)",
                kind: .orphanedComment,
                title: "A comment lost the text it was attached to",
                detail: "The passage it quoted is no longer in “\(document.displayTitle)”. StoryLoom will not guess a new home for it.",
                evidence: [
                    FindingEvidence(
                        documentID: document.id,
                        documentTitle: document.displayTitle,
                        excerpt: comment.anchor.excerpt,
                        range: nil
                    )
                ],
                target: .comment(comment.id)
            )
        }
    }

    // MARK: Scenes

    /// An outline is supposed to be empty. A draft that says what it wants to do
    /// and then does not do it is worth a quiet word.
    private static func emptyScenes(_ project: StoryProject) -> [StoryFinding] {
        project.documents.compactMap { document in
            guard document.kind == .scene,
                  document.status != .outline,
                  document.isEmpty,
                  !document.intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return nil }

            return StoryFinding(
                id: "empty-scene:\(document.id.uuidString)",
                kind: .emptyScene,
                title: "“\(document.displayTitle)” is marked \(document.status.title) but has no prose",
                detail: "Its intention is written: “\(document.intention)”. Either the scene is waiting, or its status is.",
                evidence: [],
                target: .document(document.id, nil)
            )
        }
    }

    private static func unknownPointsOfView(_ project: StoryProject) -> [StoryFinding] {
        project.documents.compactMap { document in
            let pov = document.pov.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !pov.isEmpty, project.story.entity(named: pov) == nil else { return nil }

            return StoryFinding(
                id: "unknown-pov:\(document.id.uuidString):\(pov.lowercased())",
                kind: .unknownPointOfView,
                title: "“\(document.displayTitle)” is told by \(pov), who has no record",
                detail: "Creating a record for \(pov) would let StoryLoom link their appearances and relationships. It is optional; prose is never incomplete for lacking one.",
                evidence: [],
                target: .document(document.id, nil)
            )
        }
    }
}

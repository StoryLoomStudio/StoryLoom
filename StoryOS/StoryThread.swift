//
//  StoryThread.swift
//  StoryLoom
//
//  A thread is a question living in the reader's head.
//
//  This is the record the rest of the application is organised around, and it is
//  the one thing a folder of scenes cannot tell you. At scene 30 a novelist can
//  hold every open question in their head. At scene 300 they cannot, and the
//  failure is not that they forget the question — it is that they forget they
//  asked it. Volume four arrives and the promise made in volume one has quietly
//  gone cold, and no outline, corkboard, or tag ever said a word about it.
//
//  So: a thread is opened by a scene, advanced by scenes, and landed by a scene.
//  Promise, progress, payoff. The author declares those links; StoryLoom derives the
//  arc, in manuscript order, and can always point at the scene that made the claim.
//  Nothing here is inferred, and the answer to the question is private — it is the
//  one piece of the project most likely to end up in a reader's hands by accident.
//

import SwiftUI

// MARK: - Record

nonisolated struct StoryThread: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    /// Written as a question, always. "Why is Mara's name already in the ledger?"
    /// is a thread. "The ledger" is a noun, and a noun cannot be paid off.
    var question: String
    var kind: ThreadKind = .mystery
    /// What the reader is owed, and what they will get. Private: this is the single
    /// most spoiler-dense field in the project and it never crosses an export.
    var answer: String = ""
    /// The author has decided this question will not be answered. That is a legal
    /// ending — some questions are supposed to stay open — but it is a decision,
    /// and StoryLoom stops asking about it once it has been made.
    var isAbandoned: Bool = false

    nonisolated init(
        id: UUID = UUID(),
        question: String,
        kind: ThreadKind = .mystery,
        answer: String = "",
        isAbandoned: Bool = false
    ) {
        self.id = id
        self.question = question
        self.kind = kind
        self.answer = answer
        self.isAbandoned = isAbandoned
    }

    private enum CodingKeys: String, CodingKey {
        case id, question, kind, answer, isAbandoned
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        question = try container.decode(String.self, forKey: .question)
        kind = try container.decodeIfPresent(ThreadKind.self, forKey: .kind) ?? .mystery
        answer = try container.decodeIfPresent(String.self, forKey: .answer) ?? ""
        isAbandoned = try container.decodeIfPresent(Bool.self, forKey: .isAbandoned) ?? false
    }

    var displayQuestion: String {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled thread" : trimmed
    }
}

/// What kind of pull the thread exerts. These are the engines that keep a reader
/// turning pages, and they behave differently: a mystery can be sat on for four
/// hundred pages, a threat cannot.
///
/// The order is not alphabetical and is not arbitrary. The first four are the
/// *tension* engines — what the reader is anxious about — and they are the ones a
/// thread usually is. The next three are the *growth* engines, which move slowly
/// and land late. The last two are craft: a conflict and a theme are things the
/// author tracks about the book rather than things the reader is waiting for. A
/// picker that opens on Mystery and reaches Theme last matches how the list is
/// actually used.
nonisolated enum ThreadKind: String, CaseIterable, Codable, Hashable, Sendable {
    case mystery
    case promise
    case threat
    case goal
    case relationship
    case characterArc = "character-arc"
    case foreshadowing
    case conflict
    case theme

    /// `want` was this case's name while there were only four kinds. Projects
    /// written before the vocabulary widened still say so on disk, and a decode
    /// that threw on it would make an old project unopenable rather than merely
    /// out of date. An unrecognised kind — a file from some later version —
    /// becomes a Mystery, which is the one kind that asserts nothing about the
    /// story beyond "this is unresolved".
    nonisolated init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "want": self = .goal
        default: self = ThreadKind(rawValue: raw) ?? .mystery
        }
    }

    var title: String {
        switch self {
        case .mystery: "Mystery"
        case .promise: "Promise"
        case .threat: "Threat"
        case .goal: "Goal"
        case .relationship: "Relationship"
        case .characterArc: "Character Arc"
        case .foreshadowing: "Foreshadowing"
        case .conflict: "Conflict"
        case .theme: "Theme"
        }
    }

    /// The shape of the question, so the field can prompt in the author's language.
    var prompt: String {
        switch self {
        case .mystery: "What does the reader not know yet?"
        case .promise: "What has the story promised will happen?"
        case .threat: "What is coming for them?"
        case .goal: "What does someone need, and cannot have?"
        case .relationship: "What is unsettled between these two?"
        case .characterArc: "Who do they have to become?"
        case .foreshadowing: "What has been planted, and not yet paid?"
        case .conflict: "Who wants the opposite of what they want?"
        case .theme: "What is this book arguing about?"
        }
    }

    var glyph: Glyph {
        switch self {
        case .mystery: .mystery
        case .promise: .promise
        case .threat: .threat
        case .goal: .goal
        case .relationship: .relationship
        case .characterArc: .characterArc
        case .foreshadowing: .foreshadowing
        case .conflict: .conflict
        case .theme: .theme
        }
    }

    /// The same glyph in the form the general icon views take. Derived rather
    /// than listed twice, so the two can never disagree.
    var icon: IconSource { .glyph(glyph) }

    /// Hue carries the grouping described above: the tension kinds run warm
    /// through indigo, the growth kinds green, and craft sits cool and quiet so
    /// it never competes with a thread the reader is actually waiting on.
    var tint: Color {
        switch self {
        case .mystery: .indigo
        case .promise: .teal
        case .threat: .orange
        case .goal: .pink
        case .relationship: .red
        case .characterArc: .green
        case .foreshadowing: .purple
        case .conflict: .brown
        case .theme: .yellow
        }
    }
}

/// What a scene does to a thread. Three roles, and there are only three, because
/// a fourth would be a category the author has to think about instead of writing.
nonisolated enum ThreadRole: String, CaseIterable, Codable, Hashable, Sendable {
    case opens
    case advances
    case lands

    var title: String {
        switch self {
        case .opens: "Opens"
        case .advances: "Advances"
        case .lands: "Lands"
        }
    }

    /// The craft word, shown on the thread page where the arc is what matters.
    var arcTitle: String {
        switch self {
        case .opens: "Promise"
        case .advances: "Progress"
        case .lands: "Payoff"
        }
    }

    var symbolName: String {
        switch self {
        case .opens: "circle"
        case .advances: "arrow.forward"
        case .lands: "largecircle.fill.circle"
        }
    }
}

// MARK: - Derived arc

/// Where a thread stands right now. Derived, never stored: the scenes are the
/// truth, and this is only what they add up to.
nonisolated struct ThreadArc: Identifiable, Sendable {
    let thread: StoryThread
    /// Every scene that touches the thread, in manuscript order.
    let beats: [ThreadBeat]
    /// Manuscript positions, so "how long has this been quiet" is answerable.
    let openedAt: Int?
    let landedAt: Int?
    let lastTouchedAt: Int?
    /// Scenes with prose in them that the reader passes through after the last
    /// beat. Empty outlines do not count: nothing has gone cold in a scene that
    /// has not been written.
    let scenesSinceProgress: Int
    let wordsSinceProgress: Int

    nonisolated var id: UUID { thread.id }

    var state: ThreadState {
        if thread.isAbandoned { return .abandoned }
        if landedAt != nil { return .landed }
        if beats.isEmpty { return .unopened }
        return scenesSinceProgress >= ThreadArc.coolingAfter ? .cooling : .open
    }

    /// How many written scenes may pass before StoryLoom says something.
    ///
    /// There is no correct number here and StoryLoom does not pretend otherwise —
    /// it is a prompt, not a rule, and the copy says how it was counted so the
    /// author can disagree with it in one glance rather than trusting it.
    static let coolingAfter = 10

    /// A promise the reader is still holding.
    var isOwed: Bool {
        !thread.isAbandoned && landedAt == nil
    }
}

nonisolated struct ThreadBeat: Identifiable, Hashable, Sendable {
    let documentID: UUID
    let role: ThreadRole
    /// Position in the manuscript, which is the order the reader meets it in.
    let position: Int

    nonisolated var id: String { "\(documentID.uuidString):\(role.rawValue)" }
}

nonisolated enum ThreadState: String, CaseIterable, Sendable {
    case unopened
    case open
    case cooling
    case landed
    case abandoned

    var title: String {
        switch self {
        case .unopened: "Not yet asked"
        case .open: "Open"
        case .cooling: "Going quiet"
        case .landed: "Landed"
        case .abandoned: "Left open on purpose"
        }
    }

    var tint: Color {
        switch self {
        case .unopened: .secondary
        case .open: Palette.question
        case .cooling: Palette.caution
        case .landed: Palette.confirmed
        case .abandoned: Palette.intentional
        }
    }

    var symbolName: String {
        switch self {
        case .unopened: "circle.dotted"
        case .open: "circle"
        case .cooling: "clock.badge.exclamationmark"
        case .landed: "checkmark.circle.fill"
        case .abandoned: "checkmark.seal"
        }
    }

    /// Open questions come first: they are the ones the author still owes.
    var sortOrder: Int {
        switch self {
        case .cooling: 0
        case .open: 1
        case .unopened: 2
        case .landed: 3
        case .abandoned: 4
        }
    }
}

// MARK: - Derivation

nonisolated enum ThreadTracker {

    /// The arc of every thread, in manuscript order, with the story's questions
    /// first and its answers last.
    static func arcs(for project: StoryProject) -> [ThreadArc] {
        let scenes = project.documents.filter { $0.kind == .scene }
        let positions = Dictionary(uniqueKeysWithValues: scenes.enumerated().map { ($0.element.id, $0.offset) })

        return project.story.threads
            .map { arc(for: $0, scenes: scenes, positions: positions) }
            .sorted {
                if $0.state.sortOrder != $1.state.sortOrder { return $0.state.sortOrder < $1.state.sortOrder }
                if $0.scenesSinceProgress != $1.scenesSinceProgress { return $0.scenesSinceProgress > $1.scenesSinceProgress }
                return $0.thread.displayQuestion < $1.thread.displayQuestion
            }
    }

    static func arc(for thread: StoryThread, in project: StoryProject) -> ThreadArc {
        let scenes = project.documents.filter { $0.kind == .scene }
        let positions = Dictionary(uniqueKeysWithValues: scenes.enumerated().map { ($0.element.id, $0.offset) })
        return arc(for: thread, scenes: scenes, positions: positions)
    }

    private static func arc(
        for thread: StoryThread,
        scenes: [StoryDocument],
        positions: [UUID: Int]
    ) -> ThreadArc {
        var beats: [ThreadBeat] = []

        for scene in scenes {
            guard let position = positions[scene.id] else { continue }
            for role in scene.roles(for: thread.id) {
                beats.append(ThreadBeat(documentID: scene.id, role: role, position: position))
            }
        }

        // Manuscript order, and within one scene: opened, then advanced, then
        // landed — which is the only order those three can happen in.
        beats.sort {
            if $0.position != $1.position { return $0.position < $1.position }
            return roleOrder($0.role) < roleOrder($1.role)
        }

        let opened = beats.first { $0.role == .opens }?.position
        let landed = beats.first { $0.role == .lands }?.position
        let lastTouched = beats.last?.position

        // Only written scenes count as time passing. An author who has outlined the
        // next forty scenes has not let anything go cold.
        var scenesSince = 0
        var wordsSince = 0
        if landed == nil, let lastTouched {
            for scene in scenes.dropFirst(lastTouched + 1) where !scene.isEmpty {
                scenesSince += 1
                wordsSince += scene.wordCount
            }
        }

        return ThreadArc(
            thread: thread,
            beats: beats,
            openedAt: opened,
            landedAt: landed,
            lastTouchedAt: lastTouched,
            scenesSinceProgress: scenesSince,
            wordsSinceProgress: wordsSince
        )
    }

    private static func roleOrder(_ role: ThreadRole) -> Int {
        switch role {
        case .opens: 0
        case .advances: 1
        case .lands: 2
        }
    }
}

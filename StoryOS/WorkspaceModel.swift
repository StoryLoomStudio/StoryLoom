//
//  WorkspaceModel.swift
//  StoryLoom
//
//  The workspace: what is open, what is selected, what has been saved, and what
//  the story looks like from the outside. It owns canonical state and delegates
//  durability to LocalProjectRepository.
//
//  Two rules shape it. Typing is never blocked on anything — indexing, findings,
//  and search all run behind the author. And nothing derived is ever treated as
//  truth: the index and the findings can be thrown away at any moment without
//  losing a word or an author's decision.
//

import AppKit
import Combine
import SwiftUI

@MainActor
final class WorkspaceModel: ObservableObject {

    // MARK: Canonical state

    @Published private(set) var project: StoryProject
    @Published private(set) var projectURL: URL?
    @Published private(set) var persistence: PersistenceState = .unsaved

    // MARK: Selection

    @Published var library: LibraryItem = .manuscript
    @Published var selectedDocumentID: StoryDocument.ID?
    @Published var selectedThreadID: StoryThread.ID?
    @Published var selectedEntityID: StoryEntity.ID?
    @Published var selectedEventID: StoryEvent.ID?
    @Published var selectedNoteID: StoryNote.ID?
    @Published var selectedSnapshotID: ProjectSnapshotRecord.ID?
    @Published var selectedTrashID: TrashedItem.ID?

    // MARK: Editor surface

    @Published var editorSelection = EditorSelection()
    @Published var reveal: RevealRequest?
    @Published var editorCommand: EditorCommandRequest?
    /// Appearance that is not text, per document. Held beside the manuscript
    /// rather than inside it so the prose files stay clean Markdown — the
    /// generation pipeline reads those files, and markup it did not ask for is
    /// noise it pays for. See `Presentation.swift`.
    @Published var presentation: [UUID: PresentationLayer] = [:]

    var selectedPresentation: PresentationLayer {
        selectedDocumentID.flatMap { presentation[$0] } ?? PresentationLayer()
    }

    func updatePresentation(_ layer: PresentationLayer) {
        guard let id = selectedDocumentID else { return }
        if layer.isEmpty { presentation.removeValue(forKey: id) } else { presentation[id] = layer }
        scheduleAutosave()
    }
    @Published var isInspectorVisible = false
    @Published var isFocusMode = false

    // MARK: Derived (rebuildable, never authoritative)

    @Published private(set) var index = StoryIndex()
    @Published private(set) var findings: [StoryFinding] = []
    @Published private(set) var threadArcs: [ThreadArc] = []
    @Published private(set) var history: [ProjectSnapshotRecord] = []

    // MARK: Transient

    @Published var error: WorkspaceError?
    @Published var externalChange: ExternalChange?
    @Published var recoveryNotice: String?

    /// The window's undo manager, so structural edits land on the same stack as
    /// typing and ⌘Z means what the author expects it to mean.
    var undoManager: UndoManager?

    private let repository: LocalProjectRepository
    private let recents: RecentProjects
    private var autosave: Task<Void, Never>?
    private var reindex: Task<Void, Never>?
    private var securityScopedURL: URL?
    private var lastSnapshotAt: Date?
    private var fingerprint: String?
    private var sessionBaseline: Int

    init(
        project: StoryProject? = nil,
        repository: LocalProjectRepository = .init(),
        recents: RecentProjects
    ) {
        let opened = project ?? StoryProject(title: "", documents: [])
        self.project = opened
        self.repository = repository
        self.recents = recents
        self.hasProject = project != nil
        self.selectedDocumentID = opened.documents.first?.id
        self.sessionBaseline = opened.totalWordCount
        selectFirstRecords()
        rebuildDerived()
    }

    // MARK: - Opening

    /// Whether there is a book on screen at all.
    ///
    /// The application used to launch straight into a sample manuscript, which
    /// meant the first thing an author saw was somebody else's novel and the
    /// first thing they had to work out was how to get rid of it. It now opens on
    /// nothing, and says so.
    @Published private(set) var hasProject: Bool

    /// True while a remembered project is being read back at launch. The start
    /// screen waits for this rather than flashing up in front of a project that
    /// is about to appear anyway.
    @Published private(set) var isRestoring = false

    /// Reopen whatever was being worked on, if the author asked for that and the
    /// bookmark still resolves. Called once, at launch.
    func resumeLastSession(enabled: Bool) {
        guard !hasProject, !isRestoring else { return }
        guard enabled, let entry = recents.mostRecent, let url = recents.resolve(entry) else { return }
        isRestoring = true
        open(url)
    }

    // MARK: - Convenience accessors

    var selectedDocument: StoryDocument? {
        selectedDocumentID.flatMap { id in project.documents.first { $0.id == id } }
    }

    var selectedEntity: StoryEntity? {
        selectedEntityID.flatMap { id in project.story.entities.first { $0.id == id } }
    }

    var selectedEvent: StoryEvent? {
        selectedEventID.flatMap { id in project.story.events.first { $0.id == id } }
    }

    var selectedNote: StoryNote? {
        selectedNoteID.flatMap { id in project.story.notes.first { $0.id == id } }
    }

    var selectedSnapshot: ProjectSnapshotRecord? {
        selectedSnapshotID.flatMap { id in history.first { $0.id == id } }
    }

    /// Words written since the project was opened. Not a goal, not a streak, not
    /// a ring — just a number, for the author who wants one.
    var sessionWords: Int {
        max(0, project.totalWordCount - sessionBaseline)
    }

    var openFindings: [StoryFinding] {
        findings.filter { project.story.dispositions[$0.id] == nil }
    }

    var comments: [StoryComment] {
        guard let id = selectedDocumentID else { return [] }
        return project.story.comments
            .filter { $0.documentID == id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var mentionNames: [String] {
        project.story.entities.flatMap(\.searchTerms).sorted()
    }

    func entityName(_ id: StoryEntity.ID) -> String {
        project.entity(id)?.displayName ?? "Unknown record"
    }

    func documentTitle(_ id: StoryDocument.ID?) -> String? {
        id.flatMap { project.document($0)?.displayTitle }
    }

    func entitiesMentioned(in document: StoryDocument) -> [StoryEntity] {
        index.entityIDs(mentionedIn: document.id).compactMap { project.entity($0) }
    }

    func documentsMentioning(_ entity: StoryEntity) -> [StoryDocument] {
        index.documentIDs(mentioning: entity.id).compactMap { project.document($0) }
    }

    func disposition(of finding: StoryFinding) -> FindingDisposition? {
        project.story.dispositions[finding.id]
    }

    // MARK: - Manuscript editing

    /// Prose edits do not register undo: the text view already did, on the same
    /// undo manager, with far better granularity than a project snapshot.
    func updateText(_ text: String) {
        guard let id = selectedDocumentID,
              let position = project.documents.firstIndex(where: { $0.id == id }),
              project.documents[position].text != text else { return }
        project.documents[position].text = text
        scheduleAutosave()
        scheduleReindex()
    }

    func renameSelectedDocument(_ title: String) {
        editSelectedDocument("Rename Scene") { $0.title = title }
    }

    func updateChapter(_ chapter: String) {
        editSelectedDocument("Change Chapter") { $0.chapter = chapter }
    }

    func updateIntention(_ intention: String) {
        editSelectedDocument("Edit Intention") { $0.intention = intention }
    }

    func updateTurn(_ turn: String) {
        editSelectedDocument("Edit The Turn") { $0.turn = turn }
    }

    func updateWithheld(_ withheld: String) {
        editSelectedDocument("Edit What Is Withheld") { $0.withheld = withheld }
    }

    func updateResidue(_ residue: String) {
        editSelectedDocument("Edit What Remains") { $0.residue = residue }
    }

    func updateStatus(_ status: DocumentStatus) {
        editSelectedDocument("Change Status") { $0.status = status }
    }

    func updatePOV(_ pov: String) {
        editSelectedDocument("Change Point of View") { $0.pov = pov }
    }

    func updateLocation(_ location: String) {
        editSelectedDocument("Change Location") { $0.location = location }
    }

    func updateTargetWordCount(_ target: Int) {
        editSelectedDocument("Change Scene Word Target") { $0.targetWordCount = max(0, target) }
    }

    func updateProjectWordTarget(_ target: Int) {
        mutate("Change Project Word Target") { $0.story.projectWordTarget = max(0, target) }
    }

    func createScene(kind: DocumentKind = .scene) {
        let chapter = selectedDocument?.chapter ?? project.documents.last?.chapter ?? "Chapter One"
        let document = StoryDocument(
            title: kind == .scene ? "Untitled Scene" : "Untitled Note",
            chapter: chapter,
            kind: kind,
            text: "",
            status: .draft
        )
        mutate("New Scene") { project in
            if let id = self.selectedDocumentID,
               let position = project.documents.firstIndex(where: { $0.id == id }) {
                project.documents.insert(document, at: position + 1)
            } else {
                project.documents.append(document)
            }
        }
        library = .manuscript
        selectedDocumentID = document.id
    }

    func duplicate(_ document: StoryDocument) {
        var copy = document
        copy.id = UUID()
        copy.title = "\(document.displayTitle) Copy"
        mutate("Duplicate Scene") { project in
            let position = project.documents.firstIndex { $0.id == document.id }
            project.documents.insert(copy, at: (position ?? project.documents.count - 1) + 1)
        }
        selectedDocumentID = copy.id
    }

    func canMove(_ document: StoryDocument, by offset: Int) -> Bool {
        guard let position = project.documents.firstIndex(where: { $0.id == document.id }) else { return false }
        return project.documents.indices.contains(position + offset)
    }

    func move(_ document: StoryDocument, by offset: Int) {
        guard canMove(document, by: offset),
              let position = project.documents.firstIndex(where: { $0.id == document.id }) else { return }
        mutate("Move Scene") { project in
            project.documents.swapAt(position, position + offset)
        }
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        mutate("Reorder Scenes") { project in
            project.documents.move(fromOffsets: source, toOffset: destination)
        }
    }

    /// Archiving is reversible and keeps the prose. Deletion of authored words is
    /// not something this application does casually (01-Manifesto, "Prefer reversible action").
    func archive(_ document: StoryDocument) {
        guard let position = project.documents.firstIndex(where: { $0.id == document.id }) else { return }
        mutate("Archive Scene") { project in
            let archived = project.documents.remove(at: position)
            project.archivedDocuments.append(archived)
        }
        if selectedDocumentID == document.id {
            selectedDocumentID = project.documents.indices.contains(position)
                ? project.documents[position].id
                : project.documents.last?.id
        }
    }

    func restore(_ document: StoryDocument) {
        mutate("Restore Scene") { project in
            guard let position = project.archivedDocuments.firstIndex(where: { $0.id == document.id }) else { return }
            let restored = project.archivedDocuments.remove(at: position)
            project.documents.append(restored)
        }
        library = .manuscript
        selectedDocumentID = document.id
    }

    // MARK: - Editor commands

    /// Routed through the text view rather than applied to the model, so that the
    /// edit lands on the undo stack looking exactly like something the author typed.
    ///
    /// Deliberately not gated on a selection: with the caret inside a word, ⌘B
    /// means that word, and the editor works that out for itself.
    func toggleFormat(_ format: InlineFormat) {
        guard library == .manuscript, selectedDocumentID != nil else { return }
        editorCommand = EditorCommandRequest(command: .format(format))
    }

    func toggleBlockquote() {
        guard library == .manuscript, selectedDocument != nil else { return }
        editorCommand = EditorCommandRequest(command: .blockquote)
    }

    func insertSceneBreak() {
        guard library == .manuscript, selectedDocumentID != nil else { return }
        editorCommand = EditorCommandRequest(command: .sceneBreak)
    }

    /// Highlighting is emphasis by another name — `==like this==` — so it goes the
    /// same way emphasis does, and for the same reason: it has to survive the file.
    func toggleHighlight() {
        toggleFormat(.highlight)
    }

    func setHeading(_ level: Int) { send(.heading(level)) }
    func toggleList(ordered: Bool) { send(.list(ordered: ordered)) }
    func toggleUnderline() { send(.underline) }
    func setHighlightColour(_ colour: HighlightColour?) { send(.highlight(colour)) }
    func setAlignment(_ alignment: TextAlignmentChoice) { send(.alignment(alignment)) }
    func setFace(_ name: String?) { send(.face(name)) }
    func setFontSize(_ points: Double?) { send(.size(points)) }

    private func send(_ command: EditorCommand) {
        guard library == .manuscript, selectedDocumentID != nil else { return }
        editorCommand = EditorCommandRequest(command: command)
    }

    // MARK: - Threads

    var arcs: [ThreadArc] { threadArcs }

    var owedThreads: [ThreadArc] { threadArcs.filter(\.isOwed) }

    var selectedThread: StoryThread? {
        selectedThreadID.flatMap { id in project.story.threads.first { $0.id == id } }
    }

    func arc(for threadID: StoryThread.ID) -> ThreadArc? {
        threadArcs.first { $0.id == threadID }
    }

    func threadName(_ id: StoryThread.ID) -> String {
        project.thread(id)?.displayQuestion ?? "Deleted thread"
    }

    func createThread(kind: ThreadKind = .mystery, question: String = "") {
        let thread = StoryThread(question: question, kind: kind)
        mutate("New Thread") { $0.story.threads.append(thread) }
        library = .threads
        selectedThreadID = thread.id
        scheduleReindex()
    }

    /// A thread opened from the scene the author is standing in is opened *by* it.
    /// Doing it any other way means writing the question, then navigating back, then
    /// remembering which scene it was — three steps to record something they knew a
    /// second ago.
    func openThreadHere(kind: ThreadKind = .mystery) {
        guard let documentID = selectedDocumentID else {
            createThread(kind: kind)
            return
        }
        let thread = StoryThread(question: "", kind: kind)
        mutate("Open a Thread") { project in
            project.story.threads.append(thread)
            guard let position = project.documents.firstIndex(where: { $0.id == documentID }) else { return }
            project.documents[position].setRole(.opens, forThread: thread.id)
        }
        library = .threads
        selectedThreadID = thread.id
        scheduleReindex()
    }

    func updateThread(
        _ id: StoryThread.ID,
        question: String? = nil,
        kind: ThreadKind? = nil,
        answer: String? = nil
    ) {
        guard let position = project.story.threads.firstIndex(where: { $0.id == id }) else { return }
        if let question { project.story.threads[position].question = question }
        if let kind { project.story.threads[position].kind = kind }
        if let answer { project.story.threads[position].answer = answer }
        scheduleAutosave()
        scheduleReindex()
    }

    func setThreadAbandoned(_ id: StoryThread.ID, _ isAbandoned: Bool) {
        mutate(isAbandoned ? "Leave Thread Open" : "Reopen Thread") { project in
            guard let position = project.story.threads.firstIndex(where: { $0.id == id }) else { return }
            project.story.threads[position].isAbandoned = isAbandoned
        }
        scheduleReindex()
    }

    /// A scene's claim about a question: it opens it, moves it, ends it, or does
    /// none of those. Passing `nil` is how the author says "none of those."
    func setThreadRole(_ role: ThreadRole?, forThread threadID: StoryThread.ID, in documentID: StoryDocument.ID) {
        mutate(role?.title ?? "Unlink Thread") { project in
            guard let position = project.documents.firstIndex(where: { $0.id == documentID }) else { return }
            project.documents[position].setRole(role, forThread: threadID)
        }
        scheduleReindex()
    }

    func deleteThread(_ id: StoryThread.ID) {
        mutate("Delete Thread") { project in
            guard let position = project.story.threads.firstIndex(where: { $0.id == id }) else { return }
            let removed = project.story.threads.remove(at: position)
            // The scenes forget the thread, but the thread does not forget the
            // scenes: its own record of which beats it ran through travels into
            // the trash with it, so restoring puts the arc back rather than
            // handing the author an orphaned question.
            for position in project.documents.indices {
                project.documents[position].setRole(nil, forThread: id)
            }
            project.story.trash.insert(TrashedItem(payload: .thread(removed)), at: 0)
        }
        selectedThreadID = project.story.threads.first?.id
        scheduleReindex()
    }

    // MARK: - Comments

    func addComment(range: NSRange) {
        guard let document = selectedDocument, range.length > 0 else { return }
        let comment = StoryComment(
            documentID: document.id,
            anchor: TextAnchor.make(in: document.text, range: range)
        )
        mutate("Add Comment") { $0.story.comments.append(comment) }
        isInspectorVisible = true
    }

    func updateComment(_ id: StoryComment.ID, body: String) {
        guard let position = project.story.comments.firstIndex(where: { $0.id == id }),
              project.story.comments[position].body != body else { return }
        project.story.comments[position].body = body
        scheduleAutosave()
    }

    func resolveComment(_ id: StoryComment.ID) {
        mutate("Resolve Comment") { project in
            guard let position = project.story.comments.firstIndex(where: { $0.id == id }) else { return }
            project.story.comments[position].resolvedAt = .stamp
        }
        scheduleReindex()
    }

    func deleteComment(_ id: StoryComment.ID) {
        mutate("Delete Comment") { $0.story.comments.removeAll { $0.id == id } }
        scheduleReindex()
    }

    /// Jumps to the passage a comment is attached to, if it still exists.
    func reveal(_ comment: StoryComment) {
        guard let document = project.document(comment.documentID) else { return }
        library = .manuscript
        selectedDocumentID = document.id
        guard let range = comment.anchor.resolve(in: document.text) else { return }
        reveal = RevealRequest(range: range)
    }

    // MARK: - Story records

    func createEntity(kind: EntityKind = .character, name: String? = nil) {
        let entity = StoryEntity(name: name ?? "Untitled \(kind.title)", kind: kind)
        mutate("New \(kind.title)") { $0.story.entities.append(entity) }
        library = .story
        selectedEntityID = entity.id
        scheduleReindex()
    }

    func updateEntity(
        _ id: StoryEntity.ID,
        name: String? = nil,
        summary: String? = nil,
        kind: EntityKind? = nil,
        aliases: [String]? = nil,
        pronouns: String? = nil,
        role: String? = nil
    ) {
        guard let position = project.story.entities.firstIndex(where: { $0.id == id }) else { return }
        if let name { project.story.entities[position].name = name }
        if let summary { project.story.entities[position].summary = summary }
        if let kind { project.story.entities[position].kind = kind }
        if let aliases { project.story.entities[position].aliases = aliases }
        if let pronouns { project.story.entities[position].pronouns = pronouns }
        if let role { project.story.entities[position].role = role }
        scheduleAutosave()
        if name != nil || aliases != nil { scheduleReindex() }
    }

    func deleteEntity(_ id: StoryEntity.ID) {
        mutate("Delete Record") { project in
            guard let position = project.story.entities.firstIndex(where: { $0.id == id }) else { return }
            let removed = project.story.entities.remove(at: position)
            // A record's relationships go into the trash beside it as their own
            // items. They cannot be restored by themselves — putting an edge back
            // without its node would be worse than losing it — but keeping them
            // visible is the difference between "deleted a character" and
            // "quietly deleted nine other things too".
            let orphaned = project.story.relationships.filter { $0.involves(id) }
            project.story.relationships.removeAll { $0.involves(id) }
            for position in project.story.events.indices {
                project.story.events[position].participantIDs.removeAll { $0 == id }
            }
            project.story.trash.insert(TrashedItem(payload: .entity(removed)), at: 0)
            for relationship in orphaned {
                project.story.trash.insert(TrashedItem(payload: .relationship(relationship)), at: 1)
            }
        }
        selectedEntityID = project.story.entities.first?.id
        scheduleReindex()
    }

    func relationships(for entity: StoryEntity) -> [StoryRelationship] {
        project.story.relationships.filter { $0.involves(entity.id) }
    }

    func createRelationship(from source: StoryEntity, to target: StoryEntity) {
        let relationship = StoryRelationship(
            sourceEntityID: source.id,
            targetEntityID: target.id,
            kind: .knows
        )
        mutate("Add Relationship") { $0.story.relationships.append(relationship) }
    }

    func updateRelationship(_ id: StoryRelationship.ID, kind: RelationshipKind? = nil, label: String? = nil, summary: String? = nil) {
        guard let position = project.story.relationships.firstIndex(where: { $0.id == id }) else { return }
        if let kind { project.story.relationships[position].kind = kind }
        if let label { project.story.relationships[position].label = label }
        if let summary { project.story.relationships[position].summary = summary }
        scheduleAutosave()
    }

    func deleteRelationship(_ id: StoryRelationship.ID) {
        mutate("Delete Relationship") { project in
            guard let position = project.story.relationships.firstIndex(where: { $0.id == id }) else { return }
            let removed = project.story.relationships.remove(at: position)
            project.story.trash.insert(TrashedItem(payload: .relationship(removed)), at: 0)
        }
    }

    // MARK: - Timeline

    func createEvent() {
        let event = StoryEvent(title: "Untitled Event", certainty: .unplaced)
        mutate("New Event") { $0.story.events.append(event) }
        library = .timeline
        selectedEventID = event.id
    }

    func updateEvent(
        _ id: StoryEvent.ID,
        title: String? = nil,
        chronologyLabel: String? = nil,
        certainty: EventCertainty? = nil,
        summary: String? = nil,
        narrativeDocumentID: UUID?? = nil
    ) {
        guard let position = project.story.events.firstIndex(where: { $0.id == id }) else { return }
        if let title { project.story.events[position].title = title }
        if let chronologyLabel { project.story.events[position].chronologyLabel = chronologyLabel }
        if let certainty { project.story.events[position].certainty = certainty }
        if let summary { project.story.events[position].summary = summary }
        if let narrativeDocumentID { project.story.events[position].narrativeDocumentID = narrativeDocumentID }
        scheduleAutosave()
        scheduleReindex()
    }

    func toggleParticipant(_ entityID: UUID, in eventID: StoryEvent.ID) {
        mutate("Change Participants") { project in
            guard let position = project.story.events.firstIndex(where: { $0.id == eventID }) else { return }
            if let existing = project.story.events[position].participantIDs.firstIndex(of: entityID) {
                project.story.events[position].participantIDs.remove(at: existing)
            } else {
                project.story.events[position].participantIDs.append(entityID)
            }
        }
        scheduleReindex()
    }

    func moveEvent(_ id: StoryEvent.ID, by offset: Int) {
        guard let position = project.story.events.firstIndex(where: { $0.id == id }),
              project.story.events.indices.contains(position + offset) else { return }
        mutate("Reorder Timeline") { project in
            project.story.events.swapAt(position, position + offset)
        }
        scheduleReindex()
    }

    func deleteEvent(_ id: StoryEvent.ID) {
        mutate("Delete Event") { project in
            guard let position = project.story.events.firstIndex(where: { $0.id == id }) else { return }
            let removed = project.story.events.remove(at: position)
            project.story.trash.insert(TrashedItem(payload: .event(removed)), at: 0)
        }
        selectedEventID = project.story.events.first?.id
        scheduleReindex()
    }

    // MARK: - Notes

    func createNote() {
        let note = StoryNote(title: "Untitled Note")
        mutate("New Note") { $0.story.notes.append(note) }
        library = .notes
        selectedNoteID = note.id
    }

    func updateNote(_ id: StoryNote.ID, title: String? = nil, body: String? = nil) {
        guard let position = project.story.notes.firstIndex(where: { $0.id == id }) else { return }
        if let title { project.story.notes[position].title = title }
        if let body {
            project.story.notes[position].body = body
            project.story.notes[position].updatedAt = .stamp
        }
        scheduleAutosave()
    }

    func deleteNote(_ id: StoryNote.ID) {
        mutate("Delete Note") { project in
            guard let position = project.story.notes.firstIndex(where: { $0.id == id }) else { return }
            let removed = project.story.notes.remove(at: position)
            project.story.trash.insert(TrashedItem(payload: .note(removed)), at: 0)
        }
        selectedNoteID = project.story.notes.first?.id
    }

    // MARK: - Trash

    /// Puts one item back where it came from.
    ///
    /// Restoring appends rather than trying to reinstate the original position.
    /// An index recorded at deletion is stale the moment anything else moves, and
    /// silently dropping something into the wrong place in the timeline is worse
    /// than putting it honestly at the end where the author can see it.
    func restoreFromTrash(_ item: TrashedItem) {
        mutate("Put Back") { project in
            guard let position = project.story.trash.firstIndex(where: { $0.id == item.id }) else { return }
            let restored = project.story.trash.remove(at: position)
            switch restored.payload {
            case .thread(let value):
                project.story.threads.append(value)
            case .entity(let value):
                project.story.entities.append(value)
            case .relationship(let value):
                // Only meaningful if both ends survived. Otherwise it stays gone,
                // and stays in the trash, rather than becoming a dangling edge.
                let entities = Set(project.story.entities.map(\.id))
                guard entities.contains(value.sourceEntityID),
                      entities.contains(value.targetEntityID) else {
                    project.story.trash.insert(restored, at: position)
                    return
                }
                project.story.relationships.append(value)
            case .event(let value):
                project.story.events.append(value)
            case .note(let value):
                project.story.notes.append(value)
            }
        }
        scheduleReindex()
    }

    /// Removes one item for good.
    func purgeFromTrash(_ item: TrashedItem) {
        mutate("Delete Permanently") { $0.story.trash.removeAll { $0.id == item.id } }
    }

    func emptyTrash() {
        guard !project.story.trash.isEmpty else { return }
        mutate("Empty Trash") { $0.story.trash.removeAll() }
    }

    /// True when a relationship in the trash has lost an end and can no longer be
    /// put back. The row says so rather than offering a button that does nothing.
    func canRestore(_ item: TrashedItem) -> Bool {
        guard case .relationship(let value) = item.payload else { return true }
        let entities = Set(project.story.entities.map(\.id))
        return entities.contains(value.sourceEntityID) && entities.contains(value.targetEntityID)
    }

    // MARK: - Findings

    /// The author's decision is canonical; the finding is not. This is the only
    /// thing StoryLoom learns from a continuity question (11-UX).
    func dispose(_ finding: StoryFinding, as disposition: FindingDisposition?) {
        mutate(disposition == nil ? "Reopen Finding" : disposition!.title) { project in
            if let disposition {
                project.story.dispositions[finding.id] = disposition
            } else {
                project.story.dispositions.removeValue(forKey: finding.id)
            }
        }
    }

    func open(_ finding: StoryFinding) {
        switch finding.target {
        case .document(let id, let range):
            library = .manuscript
            selectedDocumentID = id
            if let range { reveal = RevealRequest(range: range) }
        case .thread(let id):
            library = .threads
            selectedThreadID = id
        case .entity(let id):
            library = .story
            selectedEntityID = id
        case .event(let id):
            library = .timeline
            selectedEventID = id
        case .comment(let id):
            guard let comment = project.story.comments.first(where: { $0.id == id }) else { return }
            library = .manuscript
            selectedDocumentID = comment.documentID
            isInspectorVisible = true
        case nil:
            break
        }
    }

    // MARK: - Navigation

    func navigate(to destination: SearchDestination) {
        switch destination {
        case .document(let id, let range):
            library = .manuscript
            selectedDocumentID = id
            if let range { reveal = RevealRequest(range: range) }
        case .thread(let id):
            library = .threads
            selectedThreadID = id
        case .entity(let id):
            library = .story
            selectedEntityID = id
        case .relationship(let id):
            guard let relationship = project.story.relationships.first(where: { $0.id == id }) else { return }
            library = .story
            selectedEntityID = relationship.sourceEntityID
        case .event(let id):
            library = .timeline
            selectedEventID = id
        case .note(let id):
            library = .notes
            selectedNoteID = id
        case .snapshot(let id):
            library = .history
            selectedSnapshotID = id
        }
    }

    func search(_ query: String) -> [SearchHit] {
        SearchEngine.search(query, in: project, history: history)
    }

    // MARK: - Project lifecycle

    func newProject() {
        guard let url = savePanel(title: "Create StoryLoom Project", prompt: "Create", name: "Untitled Story") else { return }
        adopt(url) { [repository] in
            try await repository.createProject(title: url.lastPathComponent, at: url)
        }
    }

    func openProject() {
        let panel = NSOpenPanel()
        panel.title = "Open StoryLoom Project"
        panel.message = "Choose a project folder or a .storyloom file inside it."
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        // If the user picked a .storyloom file, open its parent folder.
        if url.pathExtension.lowercased() == "storyloom" {
            open(url.deletingLastPathComponent())
        } else {
            open(url)
        }
    }

    func open(_ url: URL) {
        adopt(url) { [repository] in
            try await repository.loadProject(at: url)
        }
    }

    func openRecent(_ entry: RecentProjects.Entry) {
        guard let url = recents.resolve(entry) else {
            error = WorkspaceError("StoryLoom no longer has permission to open “\(entry.name)”. Open it once more from the Open dialog.")
            recents.forget(entry)
            return
        }
        open(url)
    }

    /// Restores the last project on launch, if the author asked us to and the
    /// bookmark still resolves. Failure here is silent: it lands on the start
    /// screen, which is a perfectly good place to be.
    func restoreLastProject() {
        guard let entry = recents.mostRecent, let url = recents.resolve(entry) else { return }
        open(url)
    }

    func save() {
        guard projectURL != nil else {
            newProject()
            return
        }
        writeNow()
    }

    func renameProject(_ title: String) {
        guard project.title != title else { return }
        project.title = title
        scheduleAutosave()
    }

    // MARK: - History

    func createSnapshot(reason: String = HistoryReason.manual) {
        guard let projectURL else {
            newProject()
            return
        }
        let snapshot = project
        Task {
            do {
                let record = try await repository.createSnapshot(snapshot, to: projectURL, reason: reason)
                history.insert(record, at: 0)
                selectedSnapshotID = record.id
                lastSnapshotAt = record.createdAt
            } catch {
                self.error = WorkspaceError(error)
            }
        }
    }

    /// Restore never destroys later history: it writes a save point for where you
    /// were, then commits the older state as a new revision (17-Reliability).
    func restoreSnapshot(_ record: ProjectSnapshotRecord) {
        guard let projectURL else { return }
        let current = project
        persistence = .saving

        Task {
            do {
                _ = try await repository.createSnapshot(current, to: projectURL, reason: HistoryReason.beforeRestore)
                try await repository.save(record.project, to: projectURL)
                let committed = try await repository.createSnapshot(
                    record.project,
                    to: projectURL,
                    reason: HistoryReason.restored(from: record)
                )

                project = record.project
                repairSelection()
                history = try await repository.loadSnapshots(at: projectURL)
                selectedSnapshotID = committed.id
                lastSnapshotAt = committed.createdAt
                fingerprint = await repository.fingerprint(at: projectURL)
                persistence = .saved
                rebuildDerived()
                undoManager?.removeAllActions()
            } catch {
                persistence = .failed
                self.error = WorkspaceError(error)
            }
        }
    }

    func deleteSnapshot(_ record: ProjectSnapshotRecord) {
        guard let projectURL else { return }
        Task {
            do {
                try await repository.deleteSnapshot(record, at: projectURL)
                history.removeAll { $0.id == record.id }
                if selectedSnapshotID == record.id { selectedSnapshotID = history.first?.id }
            } catch {
                self.error = WorkspaceError(error)
            }
        }
    }

    // MARK: - Export

    func export(profile: ExportProfile) {
        let panel = NSSavePanel()
        panel.title = "Export Manuscript"
        panel.nameFieldStringValue = "\(project.title).\(profile.format.fileExtension)"
        panel.canCreateDirectories = true
        panel.prompt = "Export"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let record = try ExportService.write(project, profile: profile, to: url)
            writeExportRecord(record)
        } catch {
            self.error = WorkspaceError(error)
        }
    }

    private func writeExportRecord(_ record: ExportRecord) {
        guard let projectURL else { return }
        Task.detached {
            let directory = projectURL.appending(path: ".storyloom/artifacts/exports")
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            Timestamp.apply(to: encoder)
            guard let data = try? encoder.encode(record) else { return }
            try? data.write(to: directory.appending(path: "\(record.id.uuidString).json"), options: .atomic)
        }
    }

    // MARK: - External changes

    /// Checked when the app regains focus rather than through a file presenter,
    /// which would otherwise spend its life reacting to our own writes.
    func checkForExternalChanges() {
        guard let projectURL, let known = fingerprint, persistence != .saving else { return }
        Task {
            let current = await repository.fingerprint(at: projectURL)
            guard current != known, externalChange == nil else { return }
            externalChange = ExternalChange(fingerprint: current)
        }
    }

    /// Takes the version on disk. StoryLoom never silently overwrites an external
    /// edit, and it never silently discards yours either — this is a choice.
    func reloadFromDisk() {
        guard let projectURL else { return }
        externalChange = nil
        open(projectURL)
    }

    func keepMyVersion() {
        externalChange = nil
        writeNow()
    }

    // MARK: - Private

    private func adopt(_ url: URL, _ load: @escaping () async throws -> StoryProject) {
        let previous = securityScopedURL
        securityScopedURL?.stopAccessingSecurityScopedResource()
        _ = url.startAccessingSecurityScopedResource()
        securityScopedURL = url
        persistence = .loading

        Task {
            do {
                let loaded = try await load()
                let interrupted = await repository.hasInterruptedWrite(at: url)

                project = loaded
                projectURL = url
                sessionBaseline = loaded.totalWordCount
                history = try await repository.loadSnapshots(at: url)
                selectedSnapshotID = history.first?.id
                lastSnapshotAt = history.first?.createdAt
                fingerprint = await repository.fingerprint(at: url)
                persistence = .saved
                hasProject = true
                isRestoring = false
                repairSelection()
                rebuildDerived()
                recents.remember(url)
                undoManager?.removeAllActions()

                if interrupted {
                    recoveryNotice = "The last save to this project did not finish. Its files are intact and were loaded normally — but if anything is missing, History has a save point from before that write."
                }
            } catch {
                isRestoring = false
                securityScopedURL?.stopAccessingSecurityScopedResource()
                if let previous { _ = previous.startAccessingSecurityScopedResource() }
                securityScopedURL = previous
                persistence = projectURL == nil ? .unsaved : .saved
                self.error = WorkspaceError(error)
            }
        }
    }

    private func savePanel(title: String, prompt: String, name: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = title
        panel.message = "Choose a location and name for your project folder."
        panel.nameFieldLabel = "Novel Title:"
        panel.nameFieldStringValue = name
        panel.canCreateDirectories = true
        panel.showsTagField = false
        panel.prompt = prompt

        // No allowedContentTypes — the panel returns a plain path.
        // We will create a regular folder at that path, not a file.

        // Point initial directory to something the sandbox can reach.
        if let projectURL {
            panel.directoryURL = projectURL.deletingLastPathComponent()
        } else {
            panel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        }

        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        // Strip any accidental .storyloom extension the user might have typed.
        // The folder itself should be a clean name; the .storyloom file goes inside.
        if url.pathExtension.lowercased() == "storyloom" {
            return url.deletingPathExtension()
        }
        return url
    }

    /// The single funnel for structural change: snapshot, apply, register undo,
    /// persist. Prose edits deliberately bypass it.
    private func mutate(_ actionName: String, _ change: (inout StoryProject) -> Void) {
        let before = project
        var updated = project
        change(&updated)
        guard updated != before else { return }

        project = updated
        registerUndo(actionName, restoring: before)
        scheduleAutosave()
    }

    private func editSelectedDocument(_ actionName: String, _ change: @escaping (inout StoryDocument) -> Void) {
        guard let id = selectedDocumentID else { return }
        mutate(actionName) { project in
            guard let position = project.documents.firstIndex(where: { $0.id == id }) else { return }
            change(&project.documents[position])
        }
        scheduleReindex()
    }

    private func registerUndo(_ actionName: String, restoring previous: StoryProject) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated {
                let current = model.project
                model.project = previous
                model.repairSelection()
                model.registerUndo(actionName, restoring: current)
                model.scheduleAutosave()
                model.scheduleReindex()
            }
        }
        undoManager.setActionName(actionName)
    }

    private func repairSelection() {
        if selectedDocumentID == nil || project.document(selectedDocumentID!) == nil {
            selectedDocumentID = project.documents.first?.id
        }
        if selectedThreadID == nil || project.thread(selectedThreadID!) == nil {
            selectedThreadID = project.story.threads.first?.id
        }
        if selectedEntityID == nil || project.entity(selectedEntityID!) == nil {
            selectedEntityID = project.story.entities.first?.id
        }
        if selectedEventID == nil || !project.story.events.contains(where: { $0.id == selectedEventID }) {
            selectedEventID = project.story.events.first?.id
        }
        if selectedNoteID == nil || !project.story.notes.contains(where: { $0.id == selectedNoteID }) {
            selectedNoteID = project.story.notes.first?.id
        }
    }

    private func selectFirstRecords() {
        selectedThreadID = project.story.threads.first?.id
        selectedEntityID = project.story.entities.first?.id
        selectedEventID = project.story.events.first?.id
        selectedNoteID = project.story.notes.first?.id
    }

    // MARK: Derived work

    /// Indexing and continuity checks run behind the author, never in front of
    /// them: a keystroke must never wait for the story to be understood.
    private func scheduleReindex() {
        reindex?.cancel()
        reindex = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, let self else { return }
            self.rebuildDerived()
        }
    }

    private func rebuildDerived() {
        let snapshot = project
        Task.detached(priority: .utility) {
            let index = StoryIndex(project: snapshot)
            let arcs = ThreadTracker.arcs(for: snapshot)
            let findings = ContinuityChecker.findings(for: snapshot, index: index, arcs: arcs)
            await MainActor.run { [weak self] in
                guard let self, self.project.id == snapshot.id else { return }
                self.index = index
                self.threadArcs = arcs
                self.findings = findings
            }
        }
    }

    // MARK: Persistence

    private func scheduleAutosave() {
        guard projectURL != nil else {
            persistence = .unsaved
            return
        }
        autosave?.cancel()
        persistence = .saving
        autosave = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            self?.writeNow()
        }
    }

    private func writeNow() {
        guard let projectURL else { return }
        let snapshot = project
        persistence = .saving

        Task {
            do {
                try await repository.save(snapshot, to: projectURL)
                fingerprint = await repository.fingerprint(at: projectURL)

                // Only claim "saved" if nothing changed while we were writing.
                guard project == snapshot else { return }
                persistence = .saved

                if shouldSnapshot() {
                    let record = try await repository.createSnapshot(snapshot, to: projectURL, reason: HistoryReason.autosave)
                    lastSnapshotAt = record.createdAt
                    history.insert(record, at: 0)
                }
            } catch {
                persistence = .failed
                self.error = WorkspaceError(error)
            }
        }
    }

    private func shouldSnapshot(now: Date = .now) -> Bool {
        guard let lastSnapshotAt else { return true }
        return now.timeIntervalSince(lastSnapshotAt) >= 600
    }

    /// Called when the app is about to quit. Autosave debounces; termination does not.
    func flush() {
        autosave?.cancel()
        guard let projectURL, persistence != .saved else { return }
        let snapshot = project
        let repository = self.repository
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            try? await repository.save(snapshot, to: projectURL)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 2)
    }
}

// MARK: - Supporting types

/// The rooms of the application, each one the answer to a question a novelist
/// actually asks — which is why the order is what it is. *What am I writing* comes
/// first because it is what the author opened the app to do; *who is in it* and
/// *when did it happen* are the two things they leave the page to check; *what
/// have I promised* is the bookkeeping that only matters once there is a book.
enum LibraryItem: String, CaseIterable, Identifiable, Hashable {
    case manuscript
    case story
    case timeline
    case threads
    case notes
    case trash
    case history

    var id: String { rawValue }

    /// What the sidebar actually lists, in order.
    ///
    /// `allCases` is the routing table and stays complete; this is the navigation,
    /// and the two are not the same list. History is reachable — from the recovery
    /// banner, the palette, and the Go menu — but it is not a room anyone visits
    /// on a normal writing day, and a permanent seat in the sidebar is a claim on
    /// attention that has to be earned every session rather than once.
    static let rooms: [LibraryItem] = [.manuscript, .story, .timeline, .threads, .notes]

    /// Kept apart from `rooms` and pinned to the bottom. Trash is a destination of
    /// last resort, not a peer of the manuscript.
    static let utilities: [LibraryItem] = [.trash]

    /// Everywhere a room can be jumped to by number: the Go menu and the command
    /// palette both walk this, and both take the ⌘-digit from the position in it.
    ///
    /// One list, because two lists is how the shortcuts drifted last time — the
    /// palette used to keep its own hand-written copy, and adding a room silently
    /// pointed every shortcut below it at the wrong place. History is last and
    /// still reachable; leaving it out of the sidebar is a statement about
    /// prominence, not about access.
    static let navigable: [LibraryItem] = rooms + utilities + [.history]

    var title: String {
        switch self {
        case .manuscript: "Manuscript"
        case .story: "Story"
        case .timeline: "Timeline"
        case .threads: "Threads"
        case .notes: "Notes"
        case .trash: "Trash"
        case .history: "History"
        }
    }

    /// The question this room answers, in the author's words. Shown as the pane's
    /// subtitle so that nothing has to be learned twice.
    var question: String {
        switch self {
        case .manuscript: "What am I writing?"
        case .story: "Who and what is in this?"
        case .timeline: "When did it happen?"
        case .threads: "What have I promised the reader?"
        case .notes: "What did I want to remember?"
        case .trash: "What did I throw away?"
        case .history: "What did this used to say?"
        }
    }

    var icon: IconSource {
        switch self {
        case .manuscript: .glyph(.manuscript)
        case .story: .glyph(.story)
        case .timeline: .glyph(.timeline)
        case .threads: .glyph(.threads)
        case .notes: .glyph(.notes)
        case .trash: .glyph(.trash)
        case .history: .glyph(.history)
        }
    }
}

enum PersistenceState: Equatable {
    case unsaved
    case loading
    case saving
    case saved
    case failed

    var title: String {
        switch self {
        case .unsaved: "Not saved yet"
        case .loading: "Opening…"
        case .saving: "Saving…"
        case .saved: "Saved"
        case .failed: "Could not save"
        }
    }

    var symbolName: String {
        switch self {
        case .unsaved: "circle.dashed"
        case .loading: "arrow.down.circle"
        case .saving: "arrow.triangle.2.circlepath"
        case .saved: "checkmark.circle"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .unsaved, .loading, .saving: .secondary
        case .saved: Palette.confirmed
        case .failed: Palette.conflict
        }
    }
}

struct WorkspaceError: Identifiable {
    let id = UUID()
    let message: String

    init(_ message: String) {
        self.message = message
    }

    init(_ error: Error) {
        message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

struct ExternalChange: Identifiable {
    let id = UUID()
    let fingerprint: String
}

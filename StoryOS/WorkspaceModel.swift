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
    /// Which scene is open in the editor.
    ///
    /// The binder's highlight follows it, never the other way round: opening a
    /// scene from search, from a finding, or from undo's repair must move the
    /// outline's selection with it, or the author is looking at a highlighted
    /// row that is not the page in front of them.
    @Published var selectedDocumentID: StoryDocument.ID? {
        didSet { if selectedDocumentID != nil { selectedBinderID = selectedDocumentID } }
    }
    /// Which *row* of the binder is selected — a scene or a folder.
    ///
    /// Separate from `selectedDocumentID` because a folder is a legitimate thing
    /// to have selected and not a thing that can be edited. Clicking a chapter
    /// highlights it, aims Rename and New Scene at it, and leaves the scene on
    /// screen exactly where it was.
    @Published var selectedBinderID: UUID?
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
    private var folderWatch: [DispatchSourceFileSystemObject] = []
    private var folderSettle: Task<Void, Never>?
    /// Files taken in from the folder that StoryLoom has not yet written out as
    /// scenes of its own. Handed to the next save, which absorbs them; held here
    /// until then, so a crash before that save leaves the author's file exactly
    /// where they put it.
    private var pendingAdoptions: Set<String> = []

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

    /// A new scene dropped straight into a folder, for the binder's own menus.
    func createScene(inFolder folder: UUID) {
        let document = StoryDocument(
            title: "Untitled Scene",
            chapter: project.binder.find(folder)?.name ?? "",
            kind: .scene,
            text: "",
            status: .draft
        )
        mutate("New Scene") { project in
            project.documents.append(document)
            project.binder.insert(.document(document.id), into: folder, at: nil)
            project.applyBinderOrder()
        }
        library = .manuscript
        selectedDocumentID = document.id
    }

    /// A new scene at the end of a named chapter, for the outline's own menus.
    func createScene(in chapter: StoryProject.Chapter) {
        guard let last = chapter.documents.last else { return }
        let document = StoryDocument(
            title: "Untitled Scene",
            volume: last.volume,
            chapter: last.chapter,
            kind: .scene,
            text: "",
            status: .draft
        )
        mutate("New Scene") { project in
            if let position = project.documents.firstIndex(where: { $0.id == last.id }) {
                project.documents.insert(document, at: position + 1)
            } else {
                project.documents.append(document)
            }
        }
        library = .manuscript
        selectedDocumentID = document.id
    }

    func createScene(kind: DocumentKind = .scene) {
        // A selected folder is a request: the author clicked the chapter they
        // want the scene in. Only a scene selection falls through to "beside
        // whatever is open".
        if kind == .scene, let folder = selectedBinderID, project.binder.find(folder)?.isFolder == true {
            createScene(inFolder: folder)
            return
        }

        let chapter = selectedDocument?.chapter ?? project.documents.last?.chapter ?? "Chapter One"
        let document = StoryDocument(
            title: kind == .scene ? "Untitled Scene" : "Untitled Note",
            chapter: chapter,
            kind: kind,
            text: "",
            status: .draft
        )
        mutate("New Scene") { project in
            // Into the binder beside whatever is selected, so a new scene lands
            // in the chapter the author is working in rather than at the end of
            // the book. Appending to `documents` alone would leave the tree to
            // pick it up during reconciliation, which puts it last.
            if let id = self.selectedDocumentID, let place = project.binder.location(of: id) {
                project.binder.insert(.document(document.id), into: place.parent, at: place.index + 1)
            } else {
                project.binder.insert(.document(document.id), into: nil, at: nil)
            }
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

    /// Deletes a scene — into the trash, where the prose stays readable and the
    /// scene can be put back.
    ///
    /// Archive and delete are not the same act and both are worth having.
    /// Archiving says "not in the book, but I am keeping it"; the scene stays in
    /// the manuscript folder and in the outline under Archived. Deleting says "I
    /// was wrong to write this". The trash is what makes the second one sayable
    /// at one in the morning without it being irreversible.
    func deleteDocument(_ document: StoryDocument) {
        guard let position = project.documents.firstIndex(where: { $0.id == document.id }) else { return }
        mutate("Delete Scene") { project in
            let removed = project.documents.remove(at: position)
            project.story.trash.insert(TrashedItem(payload: .document(removed)), at: 0)
        }
        if selectedDocumentID == document.id {
            selectedDocumentID = project.documents.indices.contains(position)
                ? project.documents[position].id
                : project.documents.last?.id
        }
        scheduleReindex()
    }

    // MARK: - Binder

    /// A new folder, beside or inside whatever is selected.
    ///
    /// It starts empty and stays empty until something is dragged in, which is
    /// the entire reason the binder is a tree and not a grouping rule.
    @discardableResult
    func createGroup(_ group: GroupKind, inside parent: UUID? = nil) -> UUID {
        let folder = BinderItem.folder("New \(group.title)", [], group: group)
        // The add menu works from the current binder selection. A selected
        // Chapter, Part, or Volume is an unambiguous request to create inside
        // it; falling back to the manuscript root made a newly created chapter
        // appear somewhere the author was not looking.
        let destination = parent ?? selectedBinderID.flatMap { id in
            project.binder.find(id)?.isFolder == true ? id : nil
        }
        mutate("New \(group.title)") { project in
            project.binder.insert(folder, into: destination, at: nil)
        }
        selectedBinderID = folder.id
        renamingBinderID = folder.id
        return folder.id
    }

    /// Changes what a group means without touching what is in it.
    ///
    /// Children, order, prose and metadata all sit below this line and none of
    /// them are consulted: promoting a Chapter to a Part is a change of word and
    /// icon, nothing else. A conversion that reshuffled its contents would make
    /// the author afraid to try it.
    func changeGroupType(_ id: UUID, to group: GroupKind) {
        mutate("Change Type") { $0.binder.setGroup(id, to: group) }
    }

    /// Deep-copies a group: its subtree, and a fresh copy of every scene in it.
    func duplicateGroup(_ id: UUID) {
        guard let original = project.binder.find(id), original.isFolder else { return }
        mutate("Duplicate") { project in
            var copies: [StoryDocument] = []
            func clone(_ item: BinderItem) -> BinderItem {
                switch item.kind {
                case .document:
                    guard let source = project.documents.first(where: { $0.id == item.id }) else {
                        return .document(UUID())
                    }
                    var copy = source
                    copy.id = UUID()
                    copies.append(copy)
                    return .document(copy.id)
                case .folder:
                    var copy = item
                    copy.id = UUID()
                    copy.children = item.children.map(clone)
                    return copy
                }
            }
            var duplicate = clone(original)
            duplicate.name = original.displayName + " copy"
            project.documents.append(contentsOf: copies)
            let place = project.binder.location(of: id)
            project.binder.insert(duplicate, into: place?.parent, at: place.map { $0.index + 1 })
            project.applyBinderOrder()
        }
        scheduleReindex()
    }

    /// Moves an item so it lands immediately above or below `sibling`.
    ///
    /// The destination is resolved *after* the item has been lifted out, because
    /// removing it shifts every later sibling up by one — computing the index
    /// first is exactly how a drop ends up one row from where it was aimed.
    @discardableResult
    func moveBinderItem(_ id: UUID, beside sibling: UUID, below: Bool) -> Bool {
        guard id != sibling else { return false }
        if project.binder.contains(sibling, under: id) { return false }

        var moved = false
        mutate("Move in Binder") { project in
            guard let item = project.binder.remove(id) else { return }
            guard let place = project.binder.location(of: sibling) else {
                project.binder.insert(item, into: nil, at: nil)
                moved = true
                return
            }
            project.binder.insert(item, into: place.parent, at: place.index + (below ? 1 : 0))
            project.applyBinderOrder()
            moved = true
        }
        if moved { scheduleReindex() }
        return moved
    }

    /// Every group, flattened with its depth, for a "Move To…" menu.
    var groupDestinations: [(id: UUID, depth: Int, item: BinderItem)] {
        var out: [(UUID, Int, BinderItem)] = []
        func walk(_ items: [BinderItem], _ depth: Int) {
            for item in items where item.isFolder {
                out.append((item.id, depth, item))
                walk(item.children, depth + 1)
            }
        }
        walk(project.binder, 0)
        return out
    }

    /// Selects a row of the outline. A scene also becomes the open scene; a
    /// folder does not disturb whatever is being written.
    func selectBinderRow(_ id: UUID?) {
        selectedBinderID = id
        if let id, project.document(id) != nil { selectedDocumentID = id }
    }

    /// What is currently being dragged in the binder, for the length of the drag.
    ///
    /// Not `@Published`: the pointer moving across an outline must not redraw it,
    /// and nothing on screen depends on this value — the drop indicator is the
    /// row's own state. See `BinderDrag` for why the id lives here at all.
    var draggingBinderID: UUID?

    /// Which row is being renamed in place. The outline watches this so a folder
    /// made from a menu opens straight into an editable field — naming it is the
    /// next thing the author was going to do anyway.
    @Published var renamingBinderID: UUID?

    func renameBinderItem(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if project.documents.contains(where: { $0.id == id }) {
            mutate("Rename Scene") { project in
                guard let position = project.documents.firstIndex(where: { $0.id == id }) else { return }
                project.documents[position].title = trimmed
            }
        } else {
            mutate("Rename Folder") { $0.binder.rename(id, to: trimmed) }
        }
    }

    /// Moves an item in the tree. Returns false when the drop is refused.
    ///
    /// The one refusal that matters is dropping a folder into its own subtree:
    /// the move would detach that whole branch from the root and the author
    /// would watch half their book disappear. Everything else is allowed,
    /// including dragging a scene out of every folder to the top level.
    @discardableResult
    func moveBinderItem(_ id: UUID, into parent: UUID?, at index: Int?) -> Bool {
        guard id != parent else { return false }
        if let parent, project.binder.contains(parent, under: id) { return false }

        mutate("Move in Binder") { project in
            guard let item = project.binder.remove(id) else { return }
            project.binder.insert(item, into: parent, at: index)
            project.applyBinderOrder()
        }
        scheduleReindex()
        return true
    }

    /// Deletes a folder. Its contents come with it — scenes into the trash,
    /// where they can be put back one at a time.
    func deleteFolder(_ id: UUID) {
        guard let folder = project.binder.find(id), folder.isFolder else { return }
        mutate("Move to Trash") { project in
            guard let removed = project.binder.remove(id) else { return }
            let doomed = removed.children.documentIDs
            var carried: [StoryDocument] = []
            for documentID in doomed {
                guard let position = project.documents.firstIndex(where: { $0.id == documentID }) else { continue }
                carried.append(project.documents.remove(at: position))
            }
            project.story.trash.insert(TrashedItem(payload: .group(removed, carried)), at: 0)
            project.applyBinderOrder()
        }
        // The scenes inside it went to the trash with it, and one of them may be
        // the scene on screen.
        repairSelection()
        scheduleReindex()
    }

    /// The drag-to-trash entry point for the binder. It deliberately delegates
    /// to the existing deletion methods so a scene remains a scene-sized trash
    /// entry and a folder remains one restorable subtree with all its scenes.
    @discardableResult
    func trashBinderItem(_ id: UUID) -> Bool {
        guard let item = project.binder.find(id) else { return false }
        switch item.kind {
        case .document:
            guard let document = project.document(id) else { return false }
            deleteDocument(document)
        case .folder:
            deleteFolder(id)
        }
        return true
    }

    // MARK: - Outline

    /// Moves scenes to a new place in the running order.
    ///
    /// `documents` *is* the manuscript order, so a move is an array move and
    /// nothing else — no index stored on the scene to drift, no sort key to
    /// renumber. Landing inside a different chapter adopts that chapter's name,
    /// which is what makes dragging a scene into Chapter Four mean what it looks
    /// like it means.
    func moveDocuments(_ offsets: IndexSet, to destination: Int) {
        guard !offsets.isEmpty else { return }
        mutate("Reorder Scenes") { project in
            project.documents.move(fromOffsets: offsets, toOffset: destination)
            Self.adoptNeighbouringSection(in: &project, movedCount: offsets.count, around: destination, from: offsets)
        }
        scheduleReindex()
    }

    /// After a move, a scene takes the volume and chapter of whichever side of
    /// the gap it landed against — preferring the scene above, because dropping
    /// something *under* a heading is how every outliner in the world reads.
    private static func adoptNeighbouringSection(
        in project: inout StoryProject,
        movedCount: Int,
        around destination: Int,
        from offsets: IndexSet
    ) {
        let removedBefore = offsets.filter { $0 < destination }.count
        let start = destination - removedBefore
        let end = start + movedCount - 1
        guard project.documents.indices.contains(start) else { return }

        let anchor = start > 0
            ? project.documents[start - 1]
            : (project.documents.indices.contains(end + 1) ? project.documents[end + 1] : nil)
        guard let anchor else { return }

        for position in start...min(end, project.documents.count - 1) {
            project.documents[position].volume = anchor.volume
            project.documents[position].chapter = anchor.chapter
        }
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

    func duplicateNote(_ note: StoryNote) {
        var copy = note
        copy.id = UUID()
        copy.title = "\(note.displayTitle) Copy"
        copy.updatedAt = .stamp
        mutate("Duplicate Note") { $0.story.notes.append(copy) }
        selectedNoteID = copy.id
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
            case .document(let value):
                // Back at the end of the running order rather than at its old
                // index, for the same reason everything else here is: the index
                // recorded at deletion is a lie the moment anything else moves.
                project.documents.append(value)
                project.binder.insert(.document(value.id), into: nil, at: nil)
                project.applyBinderOrder()
            case .group(let item, let documents):
                // The subtree comes back intact, at the top level. Its old
                // parent may itself be in the trash by now, so re-attaching to
                // it would be guessing.
                project.documents.append(contentsOf: documents)
                project.binder.insert(item, into: nil, at: nil)
                project.applyBinderOrder()
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

    /// Checked when the app regains focus, and whenever the manuscript folder
    /// itself changes — never through a file presenter, which would spend its
    /// life reacting to our own writes.
    func checkForExternalChanges() {
        guard let projectURL, let known = fingerprint, persistence != .saving else { return }
        Task {
            let current = await repository.fingerprint(at: projectURL)
            guard current != known, externalChange == nil else { return }
            externalChange = ExternalChange(fingerprint: current)
        }
    }

    /// Watches `manuscript/` and `archive/` for the length of the session.
    ///
    /// A Markdown project is one an author is *expected* to reach into: a file
    /// dropped in from Finder, a scene written on a phone and synced back, a
    /// branch checked out underneath the application. Waiting for the window to
    /// regain focus catches all of that eventually; watching the folder catches
    /// it while the author is still looking at the screen, which is when the
    /// question "where did my file go" gets asked.
    ///
    /// A directory's vnode reports files arriving, leaving and being renamed —
    /// and most editors save by writing a temporary file and renaming it over
    /// the old one, so an edit to an existing scene usually shows up here too.
    /// The focus check remains for the ones that do not.
    private func watchProjectFolder(_ url: URL) {
        stopWatchingProjectFolder()

        for directory in ["manuscript", "archive"] {
            let path = url.appending(path: directory).path
            let descriptor = Darwin.open(path, O_EVTONLY)
            guard descriptor >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: [.write, .rename, .delete, .extend],
                queue: .global(qos: .utility)
            )
            source.setEventHandler { [weak self] in
                Task { @MainActor in self?.projectFolderChanged() }
            }
            source.setCancelHandler { Darwin.close(descriptor) }
            source.resume()
            folderWatch.append(source)
        }
    }

    private func stopWatchingProjectFolder() {
        folderWatch.forEach { $0.cancel() }
        folderWatch.removeAll()
        folderSettle?.cancel()
        folderSettle = nil
    }

    /// Waits for the dust to settle before looking.
    ///
    /// A single save from another application is several events, and one of our
    /// own autosaves is a whole directory rewritten. Both would otherwise put a
    /// banner in front of the author for something that had not finished
    /// happening yet — so the check waits until the folder has been quiet, and
    /// waits again if StoryLoom is the one making the noise.
    private func projectFolderChanged() {
        folderSettle?.cancel()
        folderSettle = Task { [weak self] in
            for _ in 0..<3 {
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled, let self else { return }
                guard self.persistence == .saving else {
                    self.checkForExternalChanges()
                    return
                }
            }
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

    private func adopt(_ url: URL, _ load: @escaping () async throws -> ProjectLoad) {
        let previous = securityScopedURL
        securityScopedURL?.stopAccessingSecurityScopedResource()
        _ = url.startAccessingSecurityScopedResource()
        securityScopedURL = url
        persistence = .loading

        Task {
            do {
                let loaded = try await load()
                let interrupted = await repository.hasInterruptedWrite(at: url)

                project = loaded.project
                projectURL = url
                sessionBaseline = loaded.project.totalWordCount
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
                watchProjectFolder(url)

                if !loaded.adopted.isEmpty {
                    // Written back at once, so the files stop being strays: they
                    // get their front matter, a place in the manifest, and a row
                    // in the binder that survives the next launch. The binder is
                    // the useful confirmation; a technical banner would merely
                    // make the author dismiss the same information twice.
                    pendingAdoptions = Set(loaded.adopted)
                    scheduleAutosave()
                } else {
                    pendingAdoptions = []
                }

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
        // A folder that has been deleted, or undone back out of existence, must
        // not leave the outline pointing at a row that is not there.
        if let id = selectedBinderID, project.binder.find(id) == nil {
            selectedBinderID = selectedDocumentID
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

        let claiming = pendingAdoptions

        Task {
            do {
                try await repository.save(snapshot, to: projectURL, claiming: claiming)
                // Those files are now scenes, written under StoryLoom's own
                // names. Cleared only on the way out of a save that worked.
                pendingAdoptions.subtract(claiming)
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

    var glyph: Glyph {
        switch self {
        case .unsaved: .unsaved
        case .loading: .loading
        case .saving: .saving
        case .saved: .saved
        case .failed: .threat
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

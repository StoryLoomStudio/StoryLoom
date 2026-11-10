// Writes a synthetic StoryLoom v1 project into a directory.
//
// The shape is what `LocalProjectRepository` writes today (see ProjectRepository,
// StoryMetadata, Trash, Presentation, ProjectHistory), plus the debris real
// projects have collected: a stale `manifest.yaml`, empty duplicate folders and
// an unprefixed folder of plain Markdown. All prose is generated filler.
//
// Foundation and CryptoKit only, so it compiles in the package tests and in the
// app's test target alike.

import CryptoKit
import Foundation

nonisolated struct V1FixtureOptions {
    /// Scenes listed in `project.storyloom`.
    var sceneCount = 60
    var seed: UInt64 = 7
    var scenesPerChapter = 5
    /// Add the stale manifest, empty duplicate folders and unprefixed folder.
    var debris = true
    var historySnapshots = 3

    init(sceneCount: Int = 60, debris: Bool = true, historySnapshots: Int = 3) {
        self.sceneCount = sceneCount
        self.debris = debris
        self.historySnapshots = historySnapshots
    }
}

nonisolated struct V1FixtureReport {
    var root: URL
    var projectID: UUID
    var title: String
    /// Scene ids in reading order, as the manifest lists them.
    var sceneIDs: [UUID]
    /// Project-relative scene paths, same order.
    var scenePaths: [String]
    var archivedIDs: [UUID]
    var threadIDs: [UUID]
    /// The thread that opens, advances and lands in several scenes.
    var linkedThreadID: UUID
    var entityCount: Int
    var relationshipCount: Int
    var eventCount: Int
    var noteCount: Int
    var commentCount: Int
    var trashCount: Int
    var presentationSceneIDs: [UUID]
    var snapshotCount: Int
    /// Folders in the outline, project-relative (empty ones included).
    var folderPaths: [String]
    var maxFolderDepth: Int
    /// Plain Markdown the loader will adopt: files the manifest does not list.
    var strayPaths: [String]
    /// Empty folders left behind by earlier saves.
    var emptyDuplicateFolders: [String]
    /// What `loadProject` should find in `documents`.
    var expectedLoadedSceneCount: Int
}

nonisolated enum V1Fixture {
    static let manifestFileName = "project.storyloom"

    // MARK: - Entry point

    @discardableResult
    static func write(to root: URL, options: V1FixtureOptions = .init()) throws -> V1FixtureReport {
        var builder = Builder(options: options)
        return try builder.build(at: root)
    }

    // MARK: - Builder

    private struct Builder {
        let options: V1FixtureOptions
        var rng: FixtureRandom
        let fm = FileManager.default

        // Names are invented.
        let characters: [(name: String, aliases: [String], pronouns: String, role: String)] = [
            ("Talwen Orsk", ["Tal", "Wen"], "she/her", "protagonist"),
            ("Maribel Quoin", ["Mari"], "she/her", "protagonist's sister"),
            ("Dessa Vorn", [], "they/them", "the stranger"),
            ("Harl Wexley", ["Harl", "the Warden"], "he/him", "antagonist"),
            ("Ismay Corth", ["Izzy"], "she/her", "archivist"),
            ("Odrun Faile", [], "he/him", "ferryman"),
        ]
        let locationNames = ["Brimmel Reach", "The Salt Cellar", "Vorrow Station"]

        init(options: V1FixtureOptions) {
            self.options = options
            self.rng = FixtureRandom(seed: options.seed)
        }

        // MARK: Deterministic identifiers

        /// Readable ids: the top eight digits say what it is, the tail counts.
        func uuid(_ kind: UInt32, _ n: Int) -> UUID {
            UUID(uuidString: String(format: "%08X-0000-4000-8000-%012X", kind, n))!
        }
        enum Kind {
            static let project: UInt32 = 0x0A00_0001
            static let scene: UInt32 = 0x5C00_0001
            static let archived: UInt32 = 0x5C00_00A1
            static let thread: UInt32 = 0x7400_0001
            static let entity: UInt32 = 0xE700_0001
            static let relationship: UInt32 = 0xE700_00B1
            static let event: UInt32 = 0xE700_00C1
            static let note: UInt32 = 0x4E00_0001
            static let comment: UInt32 = 0xC000_0001
            static let trash: UInt32 = 0x7A00_0001
            static let run: UInt32 = 0xA100_0001
            static let block: UInt32 = 0xA100_00B1
            static let snapshot: UInt32 = 0x5900_0001
            static let revision: UInt32 = 0x9E00_0001
        }

        let baseDate: Date = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: "2026-03-01T09:00:00.000Z")!
        }()
        func date(_ minutes: Int) -> Date { baseDate.addingTimeInterval(TimeInterval(minutes * 60)) }

        // MARK: Outline

        indirect enum Node {
            case scene(Int)
            case folder(name: String, group: String, children: [Node])
        }

        mutating func build(at root: URL) throws -> V1FixtureReport {
            let count = max(1, options.sceneCount)
            let names = characters.map(\.name) + locationNames
            let title = "Fixture Novel"
            let projectID = uuid(Kind.project, 1)

            // --- Outline: loose prologue and epilogue, then Book > Part > Chapter.
            let loose = count >= 10
            let bodyCount = count - (loose ? 2 : 0)
            let chapterCount = (bodyCount + options.scenesPerChapter - 1) / options.scenesPerChapter
            let partCount = (chapterCount + 2) / 3
            let bookCount = (partCount + 1) / 2

            var nextScene = loose ? 1 : 0
            var chapterNumber = 0
            var partNumber = 0
            var chapterOf: [Int: String] = [:]
            var bookOf: [Int: String] = [:]

            var books: [Node] = []
            for bookIndex in 0..<bookCount {
                let bookName = "Book \(["One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight"][bookIndex % 8])"
                var parts: [Node] = []
                for _ in 0..<2 where partNumber < partCount {
                    partNumber += 1
                    var chapters: [Node] = []
                    for _ in 0..<3 where chapterNumber < chapterCount {
                        chapterNumber += 1
                        let chapterName = "Chapter \(chapterNumber)"
                        let end = min(nextScene + options.scenesPerChapter, count - (loose ? 1 : 0))
                        var scenes: [Node] = []
                        for index in nextScene..<end {
                            scenes.append(.scene(index))
                            chapterOf[index] = chapterName
                            bookOf[index] = bookName
                        }
                        nextScene = end
                        chapters.append(.folder(name: chapterName, group: "chapter", children: scenes))
                    }
                    parts.append(.folder(name: "Part \(partNumber)", group: "part", children: chapters))
                }
                if bookIndex == bookCount - 1 {
                    // A Part made and not yet written into: an empty directory.
                    parts.append(.folder(name: "Part \(partNumber + 1)", group: "part", children: []))
                }
                books.append(.folder(name: bookName, group: "volume", children: parts))
            }

            var tree: [Node] = []
            if loose { tree.append(.scene(0)) }
            tree += books
            if loose { tree.append(.scene(count - 1)) }

            // --- Scenes.
            var documents: [V1Document] = []
            var titles: [String] = []
            for index in 0..<count {
                var sceneRng = FixtureRandom(seed: options.seed &+ UInt64(index) &* 0x1000_0000_01B3)
                titles.append(FixtureProse.title(&sceneRng))
            }
            for index in 0..<count {
                documents.append(makeScene(index: index, title: titles[index], count: count,
                                           book: bookOf[index] ?? "", chapter: chapterOf[index] ?? "",
                                           names: names))
            }

            // --- Threads linked from several scenes.
            let threads = makeThreads()
            func link(_ thread: Int, _ role: String, _ scene: Int) {
                let id = threads[thread].id
                let index = min(max(0, scene), count - 1)
                switch role {
                case "opens": documents[index].opensThreadIDs.append(id)
                case "advances": documents[index].advancesThreadIDs.append(id)
                default: documents[index].landsThreadIDs.append(id)
                }
            }
            link(0, "opens", 1)
            for scene in [3, 7, 12, 19, 26] { link(0, "advances", scene) }
            link(0, "lands", 33)
            link(1, "opens", 2); link(1, "advances", 8); link(1, "lands", 40)
            link(2, "opens", 5); link(2, "advances", 15)
            link(3, "opens", 9)
            link(4, "advances", 11); link(4, "lands", 50)
            // A scene holds one role per thread; drop any duplicate the clamping caused.
            for index in documents.indices {
                for thread in threads {
                    var seen = false
                    for keyPath in [\V1Document.opensThreadIDs, \.advancesThreadIDs, \.landsThreadIDs] {
                        if documents[index][keyPath: keyPath].contains(thread.id) {
                            if seen { documents[index][keyPath: keyPath].removeAll { $0 == thread.id } }
                            seen = true
                        }
                    }
                }
            }

            // --- Archive.
            var archived: [V1Document] = []
            for n in 0..<2 {
                var sceneRng = FixtureRandom(seed: options.seed &+ 9_000 &+ UInt64(n))
                var doc = makeScene(index: count + n, title: "Set Aside " + FixtureProse.title(&sceneRng),
                                    count: count + 2, book: "", chapter: "", names: names)
                doc.id = uuid(Kind.archived, n + 1)
                doc.status = "outline"
                archived.append(doc)
            }

            // --- Story records.
            let story = makeStory(documents: documents, threads: threads, tree: tree, count: count)

            // --- Write the manuscript the way writeManuscript does.
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            var entries: [(id: UUID, path: String)] = []
            var groups: [String: String] = [:]
            var folderPaths: [String] = []
            var maxDepth = 0
            var binder: [V1BinderItem] = []

            func write(_ nodes: [Node], into relative: String, depth: Int) throws -> [V1BinderItem] {
                try fm.createDirectory(at: root.appending(path: relative), withIntermediateDirectories: true)
                var items: [V1BinderItem] = []
                for (position, node) in nodes.enumerated() {
                    let prefix = String(format: "%03d-", position + 1)
                    switch node {
                    case .folder(let name, let group, let children):
                        let child = "\(relative)/\(prefix)\(Self.safeName(name))"
                        groups[child] = group
                        folderPaths.append(child)
                        maxDepth = max(maxDepth, depth + 1)
                        let inner = try write(children, into: child, depth: depth + 1)
                        items.append(V1BinderItem(id: Self.folderID(for: child), kind: "folder", group: group,
                                                  name: name, children: inner))
                    case .scene(let index):
                        let document = documents[index]
                        let child = "\(relative)/\(prefix)\(Self.slug(document.title)).md"
                        try put(Self.encodeScene(document), at: root.appending(path: child))
                        entries.append((document.id, child))
                        items.append(V1BinderItem(id: document.id, kind: "document", group: "folder",
                                                  name: "", children: []))
                    }
                }
                return items
            }
            binder = try write(tree, into: "manuscript", depth: 0)
            try fm.createDirectory(at: root.appending(path: "archive"), withIntermediateDirectories: true)
            var archivedEntries: [(id: UUID, path: String)] = []
            for (index, document) in archived.enumerated() {
                let path = "archive/" + String(format: "%04d", index + 1) + "-" + Self.slug(document.title) + ".md"
                try put(Self.encodeScene(document), at: root.appending(path: path))
                archivedEntries.append((document.id, path))
            }

            // --- Presentation (appearance spans) on a few scenes.
            let presentation = makePresentation(documents: documents)

            // --- Canonical files.
            let encoder = Self.encoder()
            try put(Self.encodeManifest(id: projectID, title: title, documents: entries, archived: archivedEntries),
                    at: root.appending(path: manifestFileName))
            try put(try encoder.encode(story), at: root.appending(path: "story/metadata.json"))
            try put(try encoder.encode(V1GroupIndex(formatVersion: 2, groups: groups)),
                    at: root.appending(path: "story/binder.json"))
            let store = V1PresentationStore(
                formatVersion: 1,
                entries: presentation.keys.sorted { $0.uuidString < $1.uuidString }
                    .map { .init(documentID: $0, layer: presentation[$0]!) }
            )
            try put(try encoder.encode(store), at: root.appending(path: "story/presentation.json"))
            try put(Data(V1FixtureText.aiGuide.utf8), at: root.appending(path: "story/AI-GUIDE.md"))
            try put(Self.encodeSchema(), at: root.appending(path: "story/schema.json"))
            try put(Data(V1FixtureText.agentsPointer.utf8), at: root.appending(path: "AGENTS.md"))

            // --- Journal and history.
            try writeJournal(at: root, documentCount: count)
            let project = V1Project(id: projectID, title: title, documents: documents, story: story,
                                    archivedDocuments: archived, binder: binder)
            let reasons = ["Project created", "Autosave checkpoint", "Manual snapshot"]
            var snapshotCount = 0
            for n in 0..<options.historySnapshots {
                let created = date(10 * (n + 1))
                let snapshot = V1Snapshot(
                    id: uuid(Kind.snapshot, n + 1), createdAt: created, reason: reasons[n % reasons.count],
                    projectTitle: title, wordCount: documents.reduce(0) { $0 + $1.wordCount },
                    documentCount: documents.count, project: project, presentation: presentation
                )
                let millis = Int((created.timeIntervalSince1970 * 1_000).rounded())
                try put(try encoder.encode(snapshot),
                        at: root.appending(path: "history/snapshots/\(millis)-\(snapshot.id.uuidString).json"))
                snapshotCount += 1
            }

            // --- Debris.
            var strays: [String] = []
            var empties: [String] = []
            if options.debris {
                try put(Self.encodeStaleManifest(), at: root.appending(path: "manifest.yaml"))
                for name in ["005-Book One", "006-Book One"] {
                    try fm.createDirectory(at: root.appending(path: "manuscript/\(name)"),
                                           withIntermediateDirectories: true)
                    empties.append("manuscript/\(name)")
                }
                var strayRng = FixtureRandom(seed: options.seed &+ 77)
                let heading = FixtureProse.title(&strayRng)
                try put(Data(("# \(heading)\n\n" + FixtureProse.paragraph(&strayRng, names: names) + "\n").utf8),
                        at: root.appending(path: "manuscript/Interludes/rain-on-the-roof.md"))
                try put(Data((FixtureProse.paragraph(&strayRng, names: names) + "\n").utf8),
                        at: root.appending(path: "manuscript/Interludes/short-note.md"))
                strays = ["manuscript/Interludes/rain-on-the-roof.md", "manuscript/Interludes/short-note.md"]
            }

            return V1FixtureReport(
                root: root, projectID: projectID, title: title,
                sceneIDs: entries.map(\.id), scenePaths: entries.map(\.path),
                archivedIDs: archived.map(\.id), threadIDs: threads.map(\.id), linkedThreadID: threads[0].id,
                entityCount: story.entities.count, relationshipCount: story.relationships.count,
                eventCount: story.events.count, noteCount: story.notes.count,
                commentCount: story.comments.count, trashCount: story.trash.count,
                presentationSceneIDs: presentation.keys.sorted { $0.uuidString < $1.uuidString },
                snapshotCount: snapshotCount, folderPaths: folderPaths, maxFolderDepth: maxDepth,
                strayPaths: strays, emptyDuplicateFolders: empties,
                expectedLoadedSceneCount: entries.count + strays.count
            )
        }

        // MARK: Scenes

        mutating func makeScene(index: Int, title: String, count: Int, book: String, chapter: String,
                                names: [String]) -> V1Document {
            var r = FixtureRandom(seed: options.seed &+ 0x5EED &+ UInt64(index) &* 0x2545_F491_4F6C_DD1D)
            let statuses = ["outline", "draft", "revised", "done"]
            let status = statuses[index % 4]
            let empty = index % 15 == 14
            let detailed = index % 3 == 0

            var preserved: [String] = []
            if index % 20 == 4 { preserved = ["editorNote: \"keep this key\""] }
            if index % 20 == 9 { preserved = ["synopsis: |", "  One paragraph, written by hand", "  across two lines."] }

            return V1Document(
                id: uuid(Kind.scene, index + 1),
                title: title,
                volume: book,
                chapter: chapter,
                kind: index % 25 == 24 ? "note" : "scene",
                text: empty ? "" : Self.sceneText(title: title, index: index, rng: &r, names: names),
                intention: detailed ? FixtureProse.sentence(&r, names: names) : "",
                turn: detailed ? FixtureProse.sentence(&r, names: names) : "",
                withheld: index % 6 == 0 ? FixtureProse.sentence(&r, names: []) : "",
                residue: detailed ? FixtureProse.sentence(&r, names: []) : "",
                opensThreadIDs: [], advancesThreadIDs: [], landsThreadIDs: [],
                status: status,
                pov: characters[index % 3].name,
                location: locationNames[index % locationNames.count],
                targetWordCount: index % 7 == 3 ? 2_500 : 500,
                preservedFrontMatter: preserved
            )
        }

        /// Heading, a few paragraphs, and every inline form the editor styles.
        static func sceneText(title: String, index: Int, rng: inout FixtureRandom, names: [String]) -> String {
            var blocks = ["# \(title)"]
            let paragraphs = rng.int(3..<7)
            for n in 0..<paragraphs {
                var text = FixtureProse.paragraph(&rng, names: names)
                switch (index + n) % 9 {
                case 0: text = "\"\(FixtureProse.sentence(&rng, names: names))\" " + text
                case 2: text = "*\(FixtureProse.word(&rng))* " + text
                case 4: text += " **\(FixtureProse.word(&rng))** and ==\(FixtureProse.word(&rng))=="
                case 6: text += " ~~\(FixtureProse.word(&rng))~~"
                default: break
                }
                blocks.append(text)
                if n == 1 && index % 5 == 0 { blocks.append("---") }
                if n == 2 && index % 8 == 0 { blocks.append("> " + FixtureProse.sentence(&rng, names: names)) }
                if n == 0 && index % 11 == 0 {
                    blocks.append("- " + FixtureProse.word(&rng) + "\n- " + FixtureProse.word(&rng))
                }
            }
            return blocks.joined(separator: "\n\n") + "\n"
        }

        // MARK: Story records

        mutating func makeThreads() -> [V1Thread] {
            let kinds = ["mystery", "promise", "threat", "character-arc", "foreshadowing"]
            return kinds.enumerated().map { n, kind in
                var r = FixtureRandom(seed: options.seed &+ 3_000 &+ UInt64(n))
                return V1Thread(
                    id: uuid(Kind.thread, n + 1),
                    question: "Why is the \(FixtureProse.word(&r)) \(FixtureProse.word(&r))?",
                    kind: kind,
                    answer: FixtureProse.sentence(&r, names: []),
                    isAbandoned: n == 4
                )
            }
        }

        mutating func makeStory(documents: [V1Document], threads: [V1Thread], tree: [Node], count: Int) -> V1Metadata {
            func sceneID(_ n: Int) -> UUID { documents[min(max(0, n), count - 1)].id }
            var entities: [V1Entity] = []
            var next = 0
            func add(_ name: String, _ kind: String, aliases: [String] = [], pronouns: String = "",
                     role: String = "", links: [Int] = []) -> UUID {
                next += 1
                var r = FixtureRandom(seed: options.seed &+ 4_000 &+ UInt64(next))
                let entity = V1Entity(
                    id: uuid(Kind.entity, next), name: name, kind: kind,
                    summary: FixtureProse.paragraph(&r, names: [], sentences: 2),
                    aliases: aliases, pronouns: pronouns, role: role,
                    linkedDocumentIDs: links.map(sceneID)
                )
                entities.append(entity)
                return entity.id
            }
            var characterIDs: [UUID] = []
            for (n, c) in characters.enumerated() {
                characterIDs.append(add(c.name, "character", aliases: c.aliases, pronouns: c.pronouns,
                                        role: c.role, links: [n, n + 10, n + 20]))
            }
            for name in locationNames { _ = add(name, "location", links: [2, 6]) }
            _ = add("The Brass Key", "object", links: [4])
            _ = add("The Lantern Guild", "organization", aliases: ["the Guild"])
            _ = add("Inheritance", "theme")
            _ = add("The Heron", "symbol", links: [8])

            let relationships = [
                V1Relationship(id: uuid(Kind.relationship, 1), sourceEntityID: characterIDs[0], targetEntityID: characterIDs[1],
                               kind: "family", label: "sisters", summary: "Close, until the letter."),
                V1Relationship(id: uuid(Kind.relationship, 2), sourceEntityID: characterIDs[0], targetEntityID: characterIDs[3],
                               kind: "opposes", label: "", summary: "Each wants the other's silence."),
                V1Relationship(id: uuid(Kind.relationship, 3), sourceEntityID: characterIDs[4], targetEntityID: characterIDs[2],
                               kind: "conceals", label: "the ledger", summary: ""),
            ]
            let certainties = ["stated", "approximate", "disputed", "unplaced"]
            let events = certainties.enumerated().map { n, certainty in
                V1Event(
                    id: uuid(Kind.event, n + 1),
                    title: "Event \(n + 1)",
                    chronologyLabel: ["Night 1, before high tide", "Some weeks later", "Depends who is asked", ""][n],
                    certainty: certainty,
                    narrativeDocumentID: certainty == "unplaced" ? nil : sceneID(3 + n * 6),
                    participantIDs: [characterIDs[n % 3], characterIDs[(n + 1) % 3]],
                    summary: n == 3 ? "" : "Something happens to someone."
                )
            }
            let notes = (0..<3).map { n -> V1Note in
                var r = FixtureRandom(seed: options.seed &+ 5_000 &+ UInt64(n))
                return V1Note(id: uuid(Kind.note, n + 1), title: FixtureProse.title(&r),
                              body: FixtureProse.paragraph(&r, names: []) + "\n\n" + FixtureProse.paragraph(&r, names: []),
                              updatedAt: date(60 + n))
            }
            var comments: [V1Comment] = []
            for (n, sceneIndex) in [4, 13, 22].enumerated() {
                let document = documents[min(sceneIndex, count - 1)]
                let ns = document.text as NSString
                let paragraph = ns.range(of: "\n\n")
                guard paragraph.location != NSNotFound else { continue }
                let start = paragraph.location + 2
                let words = ns.substring(from: start).split(separator: " ").prefix(3).joined(separator: " ")
                let range = ns.range(of: words, options: .literal, range: NSRange(location: start, length: ns.length - start))
                guard range.location != NSNotFound else { continue }
                comments.append(V1Comment(
                    id: uuid(Kind.comment, n + 1), documentID: document.id,
                    anchor: V1Anchor.make(in: document.text, range: range),
                    body: ["Tighten this.", "Is this too early to say?", "Lovely."][n],
                    createdAt: date(80 + n), resolvedAt: n == 2 ? date(120) : nil
                ))
            }

            // Trash: a scene, a folder with scenes inside it, an entity, a note.
            func trashed(_ n: Int, _ payload: V1Payload) -> V1Trashed {
                V1Trashed(id: uuid(Kind.trash, n), deletedAt: date(200 + n), payload: payload)
            }
            var cutA = makeScene(index: 9_001, title: "Cut Opening", count: 10_000, book: "Book One",
                                 chapter: "Chapter 2", names: [])
            cutA.id = uuid(Kind.scene, 9_001)
            var cutB = makeScene(index: 9_002, title: "Cut Middle", count: 10_000, book: "Book One",
                                 chapter: "Deleted Chapter", names: [])
            cutB.id = uuid(Kind.scene, 9_002)
            var cutC = makeScene(index: 9_003, title: "Cut Ending", count: 10_000, book: "Book One",
                                 chapter: "Deleted Chapter", names: [])
            cutC.id = uuid(Kind.scene, 9_003)
            let deletedFolder = V1BinderItem(
                id: Self.folderID(for: "manuscript/002-Deleted Part"), kind: "folder", group: "part", name: "Deleted Part",
                children: [V1BinderItem(
                    id: Self.folderID(for: "manuscript/002-Deleted Part/001-Deleted Chapter"), kind: "folder",
                    group: "chapter", name: "Deleted Chapter",
                    children: [
                        V1BinderItem(id: cutB.id, kind: "document", group: "folder", name: "", children: []),
                        V1BinderItem(id: cutC.id, kind: "document", group: "folder", name: "", children: []),
                    ]
                )]
            )
            let trash = [
                trashed(1, .document(cutA)),
                trashed(2, .group(deletedFolder, [cutB, cutC])),
                trashed(3, .entity(V1Entity(
                    id: uuid(Kind.entity, 900), name: "Old Alias Person", kind: "character", summary: "",
                    aliases: [], pronouns: "", role: "", linkedDocumentIDs: []))),
                trashed(4, .note(V1Note(id: uuid(Kind.note, 900), title: "Dropped idea",
                                        body: "Not this.", updatedAt: date(150)))),
            ]

            return V1Metadata(
                threads: threads, entities: entities, relationships: relationships, events: events,
                notes: notes, comments: comments,
                dispositions: ["finding-alias-clash": "dismissed", "finding-late-reveal": "intentional"],
                projectWordTarget: 100_000, trash: trash
            )
        }

        // MARK: Presentation

        func makePresentation(documents: [V1Document]) -> [UUID: V1Layer] {
            var layers: [UUID: V1Layer] = [:]
            var counter = 0
            for index in [1, 6, 11] where index < documents.count && !documents[index].text.isEmpty {
                let text = documents[index].text
                let ns = text as NSString
                let heading = ns.paragraphRange(for: NSRange(location: 0, length: 0))
                var runs: [V1Run] = []
                let words = text.split(separator: " ")
                if words.count > 8, let first = words.dropFirst(5).first {
                    let range = ns.range(of: String(first), options: .literal,
                                         range: NSRange(location: heading.length, length: ns.length - heading.length))
                    if range.location != NSNotFound {
                        counter += 1
                        runs.append(V1Run(id: uuid(Kind.run, counter), location: range.location, length: range.length,
                                          anchor: V1Anchor.make(in: text, range: range), underline: true,
                                          highlight: index == 6 ? "amber" : nil,
                                          fontName: index == 11 ? "Georgia" : nil,
                                          fontSize: index == 11 ? 19 : nil))
                    }
                }
                counter += 1
                let trimmed = NSRange(location: heading.location, length: max(0, heading.length - 1))
                let block = V1Block(id: uuid(Kind.block, counter), location: trimmed.location, length: trimmed.length,
                                    anchor: V1Anchor.make(in: text, range: trimmed), alignment: "centre")
                layers[documents[index].id] = V1Layer(runs: runs, blocks: [block])
            }
            return layers
        }

        // MARK: Journal

        func writeJournal(at root: URL, documentCount: Int) throws {
            var lines = Data()
            for (n, event) in ["begin", "commit"].enumerated() {
                let record: [String: String] = [
                    "event": event,
                    "revision": uuid(Kind.revision, 1).uuidString,
                    "at": Self.timestamp(date(5 + n)),
                    "actor": "author",
                    "detail": event == "begin" ? "\(documentCount) documents" : String(repeating: "0", count: 64),
                ]
                lines.append(try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]))
                lines.append(Data("\n".utf8))
            }
            try put(lines, at: root.appending(path: ".storyloom/journal/journal.ndjson"))
        }

        // MARK: Encoding (v1 exactly)

        static func encoder() -> JSONEncoder {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            encoder.dateEncodingStrategy = .custom { date, encoder in
                var container = encoder.singleValueContainer()
                try container.encode(timestamp(date))
            }
            return encoder
        }

        static func timestamp(_ date: Date) -> String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.string(from: date)
        }

        /// A JSON string is a YAML scalar; slashes are left alone.
        static func scalar(_ value: String) -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.withoutEscapingSlashes]
            return String(data: try! encoder.encode(value), encoding: .utf8)!
        }

        static func list(_ ids: [UUID]) -> String {
            ids.isEmpty ? "[]" : "[" + ids.map { scalar($0.uuidString) }.joined(separator: ", ") + "]"
        }

        /// `MarkdownDocument.encode`: all sixteen keys, empty or not.
        static func encodeScene(_ d: V1Document) -> Data {
            var lines = [
                "---",
                "id: \(scalar(d.id.uuidString))",
                "title: \(scalar(d.title))",
                "volume: \(scalar(d.volume))",
                "chapter: \(scalar(d.chapter))",
                "kind: \(scalar(d.kind))",
                "status: \(scalar(d.status))",
                "pov: \(scalar(d.pov))",
                "location: \(scalar(d.location))",
                "targetWordCount: \(max(0, d.targetWordCount))",
                "intention: \(scalar(d.intention))",
                "turn: \(scalar(d.turn))",
                "withheld: \(scalar(d.withheld))",
                "residue: \(scalar(d.residue))",
                "opens: \(list(d.opensThreadIDs))",
                "advances: \(list(d.advancesThreadIDs))",
                "lands: \(list(d.landsThreadIDs))",
            ]
            lines += d.preservedFrontMatter
            lines.append("---")
            return Data((lines.joined(separator: "\n") + "\n" + d.text).utf8)
        }

        static func encodeManifest(id: UUID, title: String, documents: [(id: UUID, path: String)],
                                   archived: [(id: UUID, path: String)]) -> Data {
            var lines = [
                "# StoryLoom project manifest. This file is canonical and meant to be read.",
                "formatVersion: 1",
                "id: \(scalar(id.uuidString))",
                "title: \(scalar(title))",
                "documents:",
            ]
            lines += documents.flatMap { ["  - id: \(scalar($0.id.uuidString))", "    path: \(scalar($0.path))"] }
            lines.append("archivedDocuments:")
            lines += archived.flatMap { ["  - id: \(scalar($0.id.uuidString))", "    path: \(scalar($0.path))"] }
            return Data((lines.joined(separator: "\n") + "\n").utf8)
        }

        /// The leftover from before the manifest was renamed: same layout, a
        /// different id and title, and paths that no longer exist.
        static func encodeStaleManifest() -> Data {
            let stale = (1...3).map { n in
                (id: UUID(uuidString: String(format: "0D00000%d-0000-4000-8000-000000000000", n))!,
                 path: String(format: "manuscript/%03d-old-scene.md", n))
            }
            return encodeManifest(id: UUID(uuidString: "0D000000-0000-4000-8000-000000000000")!,
                                  title: "Working Title", documents: stale, archived: [])
        }

        static func encodeSchema() throws -> Data {
            let schema: [String: Any] = [
                "formatVersion": 1,
                "prose": [
                    "location": "manuscript/**/*.md",
                    "format": "UTF-8 Markdown with optional YAML front matter",
                    "ordering": "lexicographic path order; numeric prefixes are generated ordering",
                ],
                "sceneFrontMatter": [
                    "id": ["type": "uuid", "requiredForExistingScene": true],
                    "title": ["type": "string"],
                    "volume": ["type": "string"],
                    "chapter": ["type": "string"],
                    "kind": ["type": "enum", "values": ["scene", "note"]],
                    "status": ["type": "enum", "values": ["outline", "draft", "revised", "done"]],
                    "pov": ["type": "string"],
                    "location": ["type": "string"],
                    "targetWordCount": ["type": "integer", "minimum": 0],
                    "intention": ["type": "string"],
                    "turn": ["type": "string"],
                    "withheld": ["type": "string"],
                    "residue": ["type": "string"],
                    "opens": ["type": "array", "items": "thread UUID"],
                    "advances": ["type": "array", "items": "thread UUID"],
                    "lands": ["type": "array", "items": "thread UUID"],
                ],
                "metadata": [
                    "storyRecords": "story/metadata.json",
                    "folderTypes": "story/binder.json",
                    "presentation": "story/presentation.json",
                    "manifest": "project.storyloom",
                ],
                "enumValues": [
                    "folderType": ["volume", "part", "chapter", "folder"],
                    "threadKind": ["mystery", "promise", "threat", "goal", "relationship", "character-arc",
                                   "foreshadowing", "conflict", "theme"],
                    "entityKind": ["character", "location", "object", "organization", "theme", "symbol"],
                ],
            ]
            let data = try JSONSerialization.data(
                withJSONObject: schema, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            return data + Data("\n".utf8)
        }

        // MARK: Names

        /// A path-derived id, as `LocalProjectRepository.folderID(for:)`.
        static func folderID(for path: String) -> UUID {
            var hasher = SHA256()
            hasher.update(data: Data(path.utf8))
            let d = Array(hasher.finalize().prefix(16))
            return UUID(uuid: (d[0], d[1], d[2], d[3], d[4], d[5], d[6], d[7],
                               d[8], d[9], d[10], d[11], d[12], d[13], d[14], d[15]))
        }

        static func safeName(_ name: String) -> String {
            var safe = name
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
                .components(separatedBy: .controlCharacters).joined()
                .trimmingCharacters(in: .whitespaces)
            while safe.first == "." { safe.removeFirst() }
            if safe.first?.isNumber == true { safe = "_" + safe }
            return safe.isEmpty ? "untitled" : String(safe.prefix(80))
        }

        static func slug(_ title: String) -> String {
            let folded = title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let mapped = folded.unicodeScalars.map { scalar -> String in
                CharacterSet.alphanumerics.contains(scalar) ? String(Character(scalar)).lowercased() : "-"
            }
            let collapsed = mapped.joined()
                .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            let limited = String(collapsed.prefix(60))
            return limited.isEmpty ? "untitled" : limited
        }

        func put(_ data: Data, at url: URL) throws {
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        }
    }
}

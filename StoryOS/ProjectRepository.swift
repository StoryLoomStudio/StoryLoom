//
//  ProjectRepository.swift
//  StoryLoom
//
//  The portable project package. Everything the author wrote must remain
//  readable — and editable — in a plain text editor after StoryLoom is deleted
//  (00-Vision, 05-Project-Format). That constraint drives every decision here:
//  Markdown bodies verbatim, YAML front matter, JSON for nested records, and no
//  proprietary representation of the novel anywhere.
//
//  Unknown front matter is preserved. If a future StoryLoom, or a scrivener with
//  a text editor, adds a field this version has never heard of, saving must not
//  eat it.
//
//  THE OUTLINE IS THE FOLDER
//
//  `manuscript/` used to be a flat heap of numbered Markdown, with the shape of
//  the book held separately in `story/binder.json` as a tree of names, nesting
//  and ids. Two indexes of one structure, and only one of them was visible to
//  the author: opening the project in the Finder showed four hundred files in a
//  row, and a Part that existed only inside a JSON file the format promised
//  nobody would have to read.
//
//  So the directory *is* the outline. A group is a real directory, nesting is
//  real nesting, and reading order is a zero-padded number on the front of every
//  entry — files and directories share one counter, so sorting a folder by name
//  is the manuscript's order. An empty Part is an empty directory, which is
//  exactly the thing the old derived outline could not represent and the thing
//  a binder exists to give an author.
//
//  What is left in `story/binder.json` is the one fact a directory cannot state
//  about itself: whether it is a Volume, a Part, a Chapter, or just a folder. A
//  path this index has never heard of — a directory made in the Finder, a branch
//  merged in, a folder renamed while the app was shut — is a Folder, which is
//  the honest answer and never a wrong one.
//

import CryptoKit
import Foundation

/// A project, and what had to be taken in from the folder to assemble it.
///
/// `adopted` is the project-relative paths of Markdown that was in the folder
/// without being in the manifest. Two things are owed to it. The author is owed
/// the news — being told which files were picked up is the difference between a
/// feature and a surprise — and the next save is owed the list, because until
/// StoryLoom has written those scenes out under its own names the originals are
/// still lying there, and a second load would take them in all over again.
nonisolated struct ProjectLoad: Sendable {
    var project: StoryProject
    var presentation: [UUID: PresentationLayer] = [:]
    var adopted: [String] = []
    /// The directories this load read the outline out of.
    ///
    /// The same debt as `adopted`, owed for the same reason. A directory the
    /// author made in the Finder becomes a group of the outline, and the next
    /// save writes it again under a numbered name — at which point the original
    /// is an empty duplicate that would come back as a second, identical folder
    /// on the next load. The save is allowed to tidy those away *because* this
    /// load turned them into something. A directory nobody has read yet is
    /// nobody's to delete: it might have been made a second ago, by an author
    /// who is about to put something in it.
    var directories: [String] = []
    /// Recoverable auxiliary-file problems. The manuscript still opens and the
    /// author gets one actionable notice instead of a blank workspace.
    var warnings: [String] = []
}

actor LocalProjectRepository {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// The fixed filename for the project manifest inside every project folder.
    static let manifestFileName = "project.storyloom"

    // MARK: - Lifecycle

    func createProject(title: String, at projectURL: URL) throws -> ProjectLoad {
        try fileManager.createDirectory(at: projectURL, withIntermediateDirectories: true)

        // Chapter One, one scene in it, and nothing else.
        //
        // No Volume and no Part. A novel that needs them will say so later, and
        // a new project that opens with three empty tiers has spent the
        // author's first minute asking them to organise a book they have not
        // written a word of.
        let opening = StoryDocument(
            title: "Untitled Scene",
            chapter: "Chapter One",
            kind: .scene,
            text: "",
            status: .draft
        )
        let project = StoryProject(
            title: title,
            documents: [opening],
            binder: [.folder("Chapter One", [.document(opening.id)], group: .chapter)]
        )
        try save(project, to: projectURL)
        _ = try createSnapshot(project, to: projectURL, reason: HistoryReason.projectCreated)
        return ProjectLoad(project: project)
    }

    /// Writes an existing in-memory project into a brand new folder. Used by the
    /// start screen so the example project can be adopted as real work.
    func createProject(from project: StoryProject, title: String, at projectURL: URL) throws -> ProjectLoad {
        try fileManager.createDirectory(at: projectURL, withIntermediateDirectories: true)

        var copy = project
        copy.id = UUID()
        copy.title = title
        try save(copy, to: projectURL)
        _ = try createSnapshot(copy, to: projectURL, reason: HistoryReason.projectCreated)
        return ProjectLoad(project: copy)
    }

    func loadProject(at projectURL: URL) throws -> ProjectLoad {
        let manifestURL = resolveManifest(in: projectURL)
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw ProjectRepositoryError.missingManifest(manifestURL)
        }

        let manifest = try ProjectManifest.decode(from: try readString(manifestURL))
        guard manifest.formatVersion <= ProjectManifest.currentFormatVersion else {
            throw ProjectRepositoryError.unsupportedFormatVersion(manifest.formatVersion)
        }

        // What the directories mean. Absent, unreadable, or simply behind what
        // is on disk — none of those is an error, they only mean more of the
        // tree reads as plain folders.
        let index = GroupIndex.read(at: projectURL.appending(path: "story/binder.json"))

        // The manuscript, as the folder has it: the tree, the scenes, and any
        // Markdown that arrived by some other route than this application.
        //
        // The project is a folder of Markdown files and StoryLoom has always
        // promised that this is a real format, not an export — so a scene that
        // arrives another way (dropped in from the Finder, written in another
        // editor, restored from a backup, pulled by a sync client, merged by
        // git) is a scene, and the author will be looking for it. It now also
        // appears *where they put it*, because the folder it is sitting in is a
        // folder of the outline rather than a fact the old manifest had no way
        // to record.
        let claimed = Set(manifest.documents.map(\.path) + manifest.archivedDocuments.map(\.path))
        let manuscript = try readManuscript(at: projectURL, claimed: claimed, groups: index.groups)

        // `archive/` stays flat. It is a holding pen, not an outline: nothing in
        // it has a place in the book, which is what being archived means.
        let archived = try load(entries: manifest.archivedDocuments, in: projectURL)
        var archivedDocuments = archived
        let archivedStrays = adoptStrays(
            in: "archive",
            of: projectURL,
            claimed: claimed,
            taken: Set(manuscript.documents.map(\.id) + archived.map(\.id))
        )
        archivedDocuments.append(contentsOf: archivedStrays.documents)

        let storyDirectory = projectURL.appending(path: "story")
        let storyURL = storyDirectory.appending(path: "metadata.json")
        var warnings: [String] = []
        let story: StoryMetadata
        if fileManager.fileExists(atPath: storyURL.path) {
            do {
                story = try decodeStoryMetadata(from: storyURL)
            } catch {
                story = StoryMetadata()
                warnings.append("Story records could not be read. The manuscript was opened without them; the unreadable metadata file was left untouched.")
            }
        } else {
            story = StoryMetadata()
        }
        let presentationResult = loadPresentation(at: storyDirectory.appending(path: "presentation.json"))
        if let warning = presentationResult.warning { warnings.append(warning) }

        // A project written before the outline was the folder has every scene
        // loose in `manuscript/` and its shape in the old tree. Read that tree
        // one last time; the next save lays the directories down and the index
        // is a list of types from then on. Nothing is converted on load, so a
        // project opened and closed without being touched is left exactly as it
        // was found.
        let binder = manuscript.sawDirectories ? manuscript.items : (index.legacyTree ?? manuscript.items)

        var project = StoryProject(
            id: manifest.id,
            title: manifest.title,
            documents: manuscript.documents,
            story: story,
            archivedDocuments: archivedDocuments,
            binder: binder
        )
        // Puts `documents` in the order the tree reads in, and gives a home to
        // anything the tree has not heard of.
        project.applyBinderOrder()

        return ProjectLoad(
            project: project,
            presentation: presentationResult.layers,
            adopted: manuscript.adopted + archivedStrays.paths,
            directories: manuscript.directories,
            warnings: warnings
        )
    }

    /// Reads `manuscript/` as what it now is: the outline.
    ///
    /// Directories become groups, `.md` files become scenes, and the order is
    /// the order the names sort in — which the numeric prefix on every entry
    /// makes the order the author put them in.
    ///
    /// Every file states its own identity in its own front matter, so the
    /// manifest is not consulted to read one. It used to be, and it used to
    /// *refuse* a file whose id had changed underneath it, because the outline
    /// was a separate tree of ids and a scene that swapped identity took some
    /// other scene's place in it. The outline is these directories now. A file
    /// is where it is, and it is whatever it says it is.
    private func readManuscript(
        at projectURL: URL,
        claimed: Set<String>,
        groups: [String: GroupKind]
    ) throws -> (
        items: [BinderItem],
        documents: [StoryDocument],
        adopted: [String],
        directories: [String],
        sawDirectories: Bool
    ) {
        var documents: [StoryDocument] = []
        var adopted: [String] = []
        var directories: [String] = []
        var taken = Set<UUID>()

        func walk(_ relative: String) throws -> [BinderItem] {
            let directoryURL = projectURL.appending(path: relative)
            let contents = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            var items: [BinderItem] = []
            for url in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let child = "\(relative)/\(url.lastPathComponent)"
                let isDirectory = try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false

                if isDirectory {
                    directories.append(child)
                    items.append(
                        BinderItem(
                            id: Self.folderID(for: child),
                            kind: .folder,
                            // The one thing a directory cannot say about itself.
                            // A path the index has never heard of is a Folder.
                            group: groups[child] ?? .folder,
                            name: Self.folderName(from: url.lastPathComponent),
                            children: try walk(child)
                        )
                    )
                    continue
                }

                guard url.pathExtension.lowercased() == "md" else { continue }
                let text = try readString(url)

                var document = MarkdownDocument.adopt(from: text, url: url)
                // A file duplicated in the Finder carries the id of the scene it
                // was copied from. Two documents with one id is the one thing
                // the rest of the application cannot survive, and the copy is
                // plainly meant to be a second scene — so it becomes one.
                if taken.contains(document.id) { document.id = UUID() }
                taken.insert(document.id)
                documents.append(document)
                items.append(.document(document.id))
                if !claimed.contains(child) { adopted.append(child) }
            }
            return items
        }

        let items = try walk("manuscript")
        return (items, documents, adopted, directories, !directories.isEmpty)
    }

    /// A folder's identity, derived from where it is.
    ///
    /// The outline is the filesystem now, and a directory has nowhere to keep a
    /// UUID that would not be litter in a folder the author is meant to open.
    /// Hashing the path gives an id that is the same on every load, which is all
    /// anything needs it for — selection, expansion, the row being dragged. A
    /// folder renamed outside the app gets a new one, and the only thing it
    /// costs is that it is no longer the row that happened to be selected.
    private static func folderID(for path: String) -> UUID {
        var hasher = SHA256()
        hasher.update(data: Data(path.utf8))
        let d = Array(hasher.finalize().prefix(16))
        return UUID(uuid: (d[0], d[1], d[2], d[3], d[4], d[5], d[6], d[7],
                           d[8], d[9], d[10], d[11], d[12], d[13], d[14], d[15]))
    }

    /// `003-Part One` is Part One. The number is ordering, not name.
    private static func folderName(from component: String) -> String {
        var name = component
        name.replace(/^\d+[-_ ]+/, with: "")
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? component : trimmed
    }

    /// Every `.md` file in a directory that the manifest does not account for,
    /// read as a document.
    ///
    /// Two kinds turn up. One carries StoryLoom's own front matter — a file
    /// copied out of another project, or one this project lost track of — and
    /// keeps everything it says about itself. The other is a plain Markdown file
    /// somebody wrote in a text editor, which has no front matter at all and is
    /// still, unmistakably, prose; it gets an identity and a title and nothing
    /// is taken away from what it says.
    ///
    /// The body is never edited on the way in. A leading `# Heading` becomes the
    /// title *and* stays in the text: it is the author's line, and a reader who
    /// opens the file in the editor they wrote it in should find it unchanged.
    private func adoptStrays(
        in directory: String,
        of projectURL: URL,
        claimed: Set<String>,
        taken: Set<UUID>
    ) -> (documents: [StoryDocument], paths: [String]) {
        let directoryURL = projectURL.appending(path: directory)
        let contents = (try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )) ?? []

        var ids = taken
        var documents: [StoryDocument] = []
        var paths: [String] = []

        for url in contents.filter({ $0.pathExtension.lowercased() == "md" }).sorted(by: { $0.path < $1.path }) {
            let relative = "\(directory)/\(url.lastPathComponent)"
            guard !claimed.contains(relative) else { continue }
            guard let text = try? readString(url) else { continue }

            var document = MarkdownDocument.adopt(from: text, url: url)
            // A file duplicated in Finder carries the id of the scene it was
            // copied from. Two documents with one id is the one thing the rest
            // of the application cannot survive, and the copy is plainly meant
            // to be a second scene — so it becomes one.
            if ids.contains(document.id) { document.id = UUID() }

            ids.insert(document.id)
            documents.append(document)
            paths.append(relative)
        }

        return (documents, paths)
    }

    /// Finds the manifest inside a project folder. Supports both the current
    /// format (`project.storyloom`) and the legacy format (`manifest.yaml`).
    private func resolveManifest(in projectURL: URL) -> URL {
        let current = projectURL.appending(path: Self.manifestFileName)
        if fileManager.fileExists(atPath: current.path) { return current }
        // Legacy fallback: old .storyloom packages stored it as manifest.yaml
        return projectURL.appending(path: "manifest.yaml")
    }

    private func load(entries: [ProjectManifest.DocumentEntry], in projectURL: URL) throws -> [StoryDocument] {
        try entries.map { entry in
            let url = try resolve(entry.path, in: projectURL)
            guard fileManager.fileExists(atPath: url.path) else {
                throw ProjectRepositoryError.missingDocument(url)
            }
            return try MarkdownDocument.decode(from: try readString(url), expectedID: entry.id, url: url)
        }
    }

    // MARK: - Saving

    /// Writes the project out.
    ///
    /// `claiming` is the files this session adopted — Markdown that was in the
    /// folder without being in the manifest. Once their scenes have been written
    /// under StoryLoom's own names, the originals are the same prose twice, and
    /// leaving them would mean the next load adopted them again, and the one
    /// after that, until a folder of five scenes opened as fifty. So a save is
    /// where an adopted file stops being a stray and becomes a scene.
    func save(
        _ project: StoryProject,
        to projectURL: URL,
        presentation: [UUID: PresentationLayer] = [:],
        claiming adopted: Set<String> = [],
        directories claimedDirectories: Set<String> = [],
        expectedFingerprint: String? = nil
    ) throws {
        if let expectedFingerprint {
            let actual = fingerprint(at: projectURL)
            guard actual == expectedFingerprint else {
                throw ProjectRepositoryError.projectChangedOnDisk
            }
        }
        let revision = UUID()
        try journal(projectURL, event: "begin", revision: revision, detail: "\(project.documents.count) documents")

        // What the last save put on disk, plus what this session took in. Only
        // those may be cleaned up — see `sweep(_:of:ours:keeping:)`.
        let manifestURL = resolveManifest(in: projectURL)
        let previous = (try? readString(manifestURL)).flatMap { try? ProjectManifest.decode(from: $0) }
        let storyURL = projectURL.appending(path: "story")
        let previousIndex = GroupIndex.read(at: storyURL.appending(path: "binder.json"))
        let ours = Set((previous?.documents ?? []).map(\.path) + (previous?.archivedDocuments ?? []).map(\.path))
            .union(adopted)
        // Directories we are allowed to tidy away once they are empty: the ones
        // the last index named, the ones an adopted file was sitting in, and the
        // ones the load read the outline out of. A directory none of the three
        // has heard of was made after this session last looked, and an author
        // who has just made a folder is usually about to put something in it.
        let ourDirectories = Set(previousIndex.groups.keys)
            .union(adopted.flatMap(Self.ancestors(of:)))
            .union(claimedDirectories)

        do {
            let manuscript = try writeManuscript(project, to: projectURL, ours: ours, ourDirectories: ourDirectories)
            let archived = try writeFlat(project.archivedDocuments, into: "archive", of: projectURL, ours: ours)

            let manifest = ProjectManifest(
                id: project.id,
                title: project.title,
                documents: manuscript.entries,
                archivedDocuments: archived
            )
            try atomicWrite(Data(manifest.encode().utf8), to: projectURL.appending(path: Self.manifestFileName))

            try fileManager.createDirectory(at: storyURL, withIntermediateDirectories: true)
            try atomicWrite(try encodeStoryMetadata(project.story), to: storyURL.appending(path: "metadata.json"))
            try atomicWrite(GroupIndex(groups: manuscript.groups).encode(), to: storyURL.appending(path: "binder.json"))
            try atomicWrite(try encodePresentation(presentation), to: storyURL.appending(path: "presentation.json"))
            try writeAICoauthorFiles(to: projectURL)

            try journal(projectURL, event: "commit", revision: revision, detail: fingerprint(at: projectURL))
        } catch {
            try? journal(projectURL, event: "failed", revision: revision, detail: error.localizedDescription)
            throw error
        }
    }

    /// Lays the outline down as directories and Markdown.
    ///
    /// Files and directories share one counter per level, so sorting any folder
    /// of the manuscript by name gives the order the author reads it in. A group
    /// keeps the author's own name, capitals, spaces and all — a scene can be
    /// slugged because its title is safe in its front matter, and a directory's
    /// name is the only place a group's name exists.
    private func writeManuscript(
        _ project: StoryProject,
        to projectURL: URL,
        ours: Set<String>,
        ourDirectories: Set<String>
    ) throws -> (entries: [ProjectManifest.DocumentEntry], groups: [String: GroupKind]) {
        let documents = Dictionary(project.documents.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var entries: [ProjectManifest.DocumentEntry] = []
        var groups: [String: GroupKind] = [:]
        var writtenFiles = Set<String>()
        var writtenDirectories = Set<String>()

        func write(_ items: [BinderItem], into relative: String) throws {
            try fileManager.createDirectory(
                at: projectURL.appending(path: relative),
                withIntermediateDirectories: true
            )

            for (position, item) in items.enumerated() {
                let prefix = String(format: "%03d-", position + 1)
                switch item.kind {
                case .folder:
                    let child = "\(relative)/\(prefix)\(Self.safeName(item.displayName))"
                    groups[child] = item.group
                    writtenDirectories.insert(child)
                    try write(item.children, into: child)

                case .document:
                    guard let document = documents[item.id] else { continue }
                    let child = "\(relative)/\(prefix)\(slug(document.title)).md"
                    try atomicWrite(
                        Data(MarkdownDocument.encode(document).utf8),
                        to: projectURL.appending(path: child)
                    )
                    writtenFiles.insert(child)
                    entries.append(.init(id: document.id, path: child))
                }
            }
        }

        try write(project.binder, into: "manuscript")
        sweep("manuscript", of: projectURL, ours: ours, ourDirectories: ourDirectories,
              keepingFiles: writtenFiles, keepingDirectories: writtenDirectories)
        return (entries, groups)
    }

    /// Clears away what this save has replaced, and nothing else.
    ///
    /// Reordering or renaming a scene changes its filename, and moving one
    /// between chapters changes its directory. Without this the package slowly
    /// fills with orphans that no manifest points at, and the "open it in a text
    /// editor" promise degrades into a junk drawer.
    ///
    /// Only ever *our* orphans. An earlier version deleted every `.md` it had
    /// not just written, which meant a file an author dropped into the folder
    /// between two autosaves was destroyed by the next keystroke — the one
    /// outcome a plain-text format must never have. A file is ours only if the
    /// manifest we are replacing pointed at it, or this session adopted it;
    /// anything else belongs to whoever put it there and is picked up as a new
    /// scene on the next load. Directories go by the same rule, and only when
    /// empty: a directory still holding something is holding something that is
    /// not ours to throw away.
    private func sweep(
        _ directory: String,
        of projectURL: URL,
        ours: Set<String>,
        ourDirectories: Set<String>,
        keepingFiles: Set<String>,
        keepingDirectories: Set<String>
    ) {
        var directories: [String] = []

        func visit(_ relative: String) {
            let contents = (try? fileManager.contentsOfDirectory(
                at: projectURL.appending(path: relative),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? []

            for url in contents {
                let child = "\(relative)/\(url.lastPathComponent)"
                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                if isDirectory {
                    directories.append(child)
                    visit(child)
                } else if url.pathExtension.lowercased() == "md",
                          !keepingFiles.contains(child),
                          ours.contains(child) {
                    try? fileManager.removeItem(at: url)
                }
            }
        }

        visit(directory)

        // Deepest first, so a chapter emptied by this sweep can be taken with
        // the part that held it.
        for relative in directories.sorted(by: { $0.count > $1.count }) {
            guard !keepingDirectories.contains(relative), ourDirectories.contains(relative) else { continue }
            let url = projectURL.appending(path: relative)
            let remaining = (try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
            guard remaining.isEmpty else { continue }
            try? fileManager.removeItem(at: url)
        }
    }

    /// `archive/` has no outline, so it is written the way the whole manuscript
    /// used to be: one flat, numbered list.
    private func writeFlat(
        _ documents: [StoryDocument],
        into directory: String,
        of projectURL: URL,
        ours: Set<String>
    ) throws -> [ProjectManifest.DocumentEntry] {
        let directoryURL = projectURL.appending(path: directory)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        var written = Set<String>()
        var entries: [ProjectManifest.DocumentEntry] = []

        for (index, document) in documents.enumerated() {
            let fileName = String(format: "%04d", index + 1) + "-" + slug(document.title) + ".md"
            let relativePath = "\(directory)/\(fileName)"
            try atomicWrite(Data(MarkdownDocument.encode(document).utf8), to: projectURL.appending(path: relativePath))
            written.insert(fileName)
            entries.append(.init(id: document.id, path: relativePath))
        }

        let existing = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
        for url in existing where url.pathExtension == "md" && !written.contains(url.lastPathComponent) {
            guard ours.contains("\(directory)/\(url.lastPathComponent)") else { continue }
            try? fileManager.removeItem(at: url)
        }

        return entries
    }

    /// Every directory above a project-relative file path.
    private static func ancestors(of path: String) -> [String] {
        var components = path.split(separator: "/").map(String.init)
        components.removeLast()
        return components.indices.map { components[...$0].joined(separator: "/") }
    }

    /// A group's name, made safe to be a directory and no more mangled than
    /// that. `/` is the only character a name cannot contain, and `:` is the one
    /// the Finder still shows back to front.
    private static func safeName(_ name: String) -> String {
        var safe = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .components(separatedBy: .controlCharacters).joined()
            .trimmingCharacters(in: .whitespaces)
        // A leading dot would hide the folder from the author, and a leading
        // digit would be read back as an ordering prefix that was never there.
        while safe.first == "." { safe.removeFirst() }
        if safe.first?.isNumber == true { safe = "_" + safe }
        return safe.isEmpty ? "untitled" : String(safe.prefix(80))
    }

    // MARK: - History

    func loadSnapshots(at projectURL: URL) throws -> [ProjectSnapshotRecord] {
        let snapshotsURL = projectURL.appending(path: "history/snapshots")
        guard fileManager.fileExists(atPath: snapshotsURL.path) else { return [] }

        let files = try fileManager.contentsOfDirectory(
            at: snapshotsURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        let decoder = historyDecoder()
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                // History is auxiliary recovery data. One damaged checkpoint
                // must not prevent the manuscript—or the other checkpoints—from
                // opening.
                try? decoder.decode(ProjectSnapshotRecord.self, from: Data(contentsOf: url))
            }
            // Newest first. The id breaks a tie only so that the list is stable:
            // two save points recorded in the same millisecond have no true order,
            // and the alternative is whatever sequence the file system hands back,
            // which can differ between two readings of the same folder.
            .sorted { ($0.createdAt, $0.id.uuidString) > ($1.createdAt, $1.id.uuidString) }
    }

    @discardableResult
    func createSnapshot(
        _ project: StoryProject,
        presentation: [UUID: PresentationLayer] = [:],
        to projectURL: URL,
        reason: String
    ) throws -> ProjectSnapshotRecord {
        let snapshotsURL = projectURL.appending(path: "history/snapshots")
        try fileManager.createDirectory(at: snapshotsURL, withIntermediateDirectories: true)

        let record = ProjectSnapshotRecord(reason: reason, project: project, presentation: presentation)
        let milliseconds = Int(record.createdAt.timeIntervalSince1970 * 1_000)
        let fileName = "\(milliseconds)-\(record.id.uuidString).json"
        try atomicWrite(try historyEncoder().encode(record), to: snapshotsURL.appending(path: fileName))
        if reason == HistoryReason.autosave { try? pruneAutosaveSnapshots(at: projectURL, keeping: 144) }
        return record
    }

    /// Keep one day of continuous ten-minute autosaves. Manual, restore, and
    /// project-creation save points are never pruned automatically.
    private func pruneAutosaveSnapshots(at projectURL: URL, keeping limit: Int) throws {
        let snapshotsURL = projectURL.appending(path: "history/snapshots")
        let files = try fileManager.contentsOfDirectory(at: snapshotsURL, includingPropertiesForKeys: nil)
        let decoder = historyDecoder()
        let autosaves: [(url: URL, record: ProjectSnapshotRecord)] = files.compactMap { url in
            guard url.pathExtension == "json",
                  let data = try? Data(contentsOf: url),
                  let record = try? decoder.decode(ProjectSnapshotRecord.self, from: data),
                  record.reason == HistoryReason.autosave
            else { return nil }
            return (url, record)
        }
        for item in autosaves.sorted(by: { $0.record.createdAt > $1.record.createdAt }).dropFirst(limit) {
            try fileManager.removeItem(at: item.url)
        }
    }

    func deleteSnapshot(_ record: ProjectSnapshotRecord, at projectURL: URL) throws {
        let snapshotsURL = projectURL.appending(path: "history/snapshots")
        let files = try fileManager.contentsOfDirectory(at: snapshotsURL, includingPropertiesForKeys: nil)
        for url in files where url.lastPathComponent.contains(record.id.uuidString) {
            try fileManager.removeItem(at: url)
        }
    }

    // MARK: - Integrity

    /// A cheap content signature for the canonical files. Comparing it after the
    /// app regains focus is how an external edit is noticed without a file
    /// presenter fighting our own writes.
    func fingerprint(at projectURL: URL) -> String {
        var hasher = SHA256()
        let canonical = [
            Self.manifestFileName,
            "story/metadata.json",
            "story/binder.json",
            "story/presentation.json"
        ]

        for relative in canonical {
            let url = projectURL.appending(path: relative)
            if let data = try? Data(contentsOf: url) {
                hasher.update(data: Data(relative.utf8))
                hasher.update(data: data)
            }
        }
        // Recursive, and hashing the *path* rather than the filename: the shape
        // of the manuscript is now the directories it is in, so a scene dragged
        // from one chapter to another changes nothing about the file and
        // everything about the book. The old signature could not see that move.
        for directory in ["manuscript", "archive"] {
            for relative in markdownPaths(under: directory, of: projectURL).sorted() {
                if let data = try? Data(contentsOf: projectURL.appending(path: relative)) {
                    hasher.update(data: Data(relative.utf8))
                    hasher.update(data: data)
                }
            }
        }
        // Empty directories say something too — a Part made and not yet written
        // into is a real part of the outline, and its arrival or removal is an
        // external change worth noticing.
        for relative in directoryPaths(under: "manuscript", of: projectURL).sorted() {
            hasher.update(data: Data(relative.utf8))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Every `.md` under a directory, project-relative, at any depth.
    private func markdownPaths(under directory: String, of projectURL: URL) -> [String] {
        var found: [String] = []
        walk(directory, of: projectURL) { relative, isDirectory in
            if !isDirectory, relative.lowercased().hasSuffix(".md") { found.append(relative) }
        }
        return found
    }

    /// Every directory under a directory, project-relative, at any depth.
    func directoryPaths(under directory: String, of projectURL: URL) -> [String] {
        var found: [String] = []
        walk(directory, of: projectURL) { relative, isDirectory in
            if isDirectory { found.append(relative) }
        }
        return found
    }

    private func walk(_ relative: String, of projectURL: URL, visit: (String, Bool) -> Void) {
        let contents = (try? fileManager.contentsOfDirectory(
            at: projectURL.appending(path: relative),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        for url in contents {
            let child = "\(relative)/\(url.lastPathComponent)"
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            visit(child, isDirectory)
            if isDirectory { walk(child, of: projectURL, visit: visit) }
        }
    }

    /// True when the journal's last entry opened a write that never committed —
    /// which is what a crash or a power cut during a save looks like from here.
    func hasInterruptedWrite(at projectURL: URL) -> Bool {
        let url = projectURL.appending(path: ".storyloom/journal/journal.ndjson")
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return false }
        let lines = contents.split(separator: "\n").filter { !$0.isEmpty }
        guard let last = lines.last else { return false }
        return last.contains("\"event\":\"begin\"")
    }

    /// Journal entries are fsynced before a checkpoint is acknowledged, so a
    /// record of intent cannot be lost while the thing it describes survives.
    private func journal(_ projectURL: URL, event: String, revision: UUID, detail: String) throws {
        let directory = projectURL.appending(path: ".storyloom/journal")
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "journal.ndjson")

        let record: [String: String] = [
            "event": event,
            "revision": revision.uuidString,
            "at": Timestamp.string(from: .stamp),
            "actor": "author",
            "detail": detail
        ]
        guard let line = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]) else { return }

        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: line + Data("\n".utf8))
        try handle.synchronize()
    }

    // MARK: - Encoding helpers

    private func atomicWrite(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    private func readString(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    private func encodeStoryMetadata(_ metadata: StoryMetadata) throws -> Data {
        try historyEncoder().encode(metadata)
    }

    private func decodeStoryMetadata(from url: URL) throws -> StoryMetadata {
        do {
            return try historyDecoder().decode(StoryMetadata.self, from: Data(contentsOf: url))
        } catch {
            throw ProjectRepositoryError.malformedStoryMetadata(url)
        }
    }

    private struct PresentationStore: Codable {
        static let currentFormatVersion = 1

        struct Entry: Codable {
            var documentID: UUID
            var layer: PresentationLayer
        }

        var formatVersion: Int
        var entries: [Entry]
    }

    private func encodePresentation(_ layers: [UUID: PresentationLayer]) throws -> Data {
        let store = PresentationStore(
            formatVersion: PresentationStore.currentFormatVersion,
            entries: layers
                .filter { !$0.value.isEmpty }
                .map { PresentationStore.Entry(documentID: $0.key, layer: $0.value) }
                .sorted { $0.documentID.uuidString < $1.documentID.uuidString }
        )
        return try historyEncoder().encode(store)
    }

    private func loadPresentation(at url: URL) -> (layers: [UUID: PresentationLayer], warning: String?) {
        guard fileManager.fileExists(atPath: url.path) else { return ([:], nil) }
        do {
            let store = try historyDecoder().decode(PresentationStore.self, from: Data(contentsOf: url))
            guard store.formatVersion <= PresentationStore.currentFormatVersion else {
                return ([:], "Text appearance was written by a newer StoryLoom and was left untouched.")
            }
            return (Dictionary(uniqueKeysWithValues: store.entries.map { ($0.documentID, $0.layer) }), nil)
        } catch {
            return ([:], "Text appearance could not be read. The manuscript was opened and the unreadable appearance file was left untouched.")
        }
    }

    /// Makes a project self-describing to an AI that is handed only the folder.
    /// `AGENTS.md` is the discovery hook used by coding agents; the detailed
    /// guide and schema live under `story/` with the metadata they explain.
    private func writeAICoauthorFiles(to projectURL: URL) throws {
        let storyURL = projectURL.appending(path: "story")
        try fileManager.createDirectory(at: storyURL, withIntermediateDirectories: true)

        let guide = """
        # StoryLoom AI Co-author Guide

        This is a live StoryLoom project. You may read and edit it directly while StoryLoom is open. StoryLoom automatically imports disk-only changes and asks before resolving a scene changed both in the app and on disk.

        ## Start here

        - Write prose in `manuscript/**/*.md`.
        - The directory tree under `manuscript/` is the binder. Number prefixes define reading order.
        - Edit an existing scene in place and preserve its `id` front-matter value.
        - To add a scene, create a `.md` file in the intended folder. Plain Markdown is valid; StoryLoom will assign identity and normalized front matter when it adopts the file.
        - Never reuse an existing scene UUID for a new file.

        ## Scene front matter

        StoryLoom writes a YAML front-matter block followed by ordinary Markdown prose. Supported keys:

        - `id`: stable UUID; preserve it on existing scenes.
        - `title`: scene title.
        - `volume`, `chapter`: optional narrative labels. Folder placement is the structural source of truth.
        - `kind`: `scene` or `note`.
        - `status`: `outline`, `draft`, `revised`, or `done`.
        - `pov`, `location`: free text.
        - `targetWordCount`: non-negative integer.
        - `intention`, `turn`, `withheld`, `residue`: private craft notes.
        - `opens`, `advances`, `lands`: JSON-style arrays of thread UUIDs.

        Unknown front-matter fields are preserved. Keep YAML at the top level unless the field is intentionally external to StoryLoom.

        ## Other metadata

        - `project.storyloom`: generated project manifest and path index.
        - `story/metadata.json`: characters, locations, relationships, timeline, threads, notes, comments, and project targets.
        - `story/binder.json`: semantic folder types (`volume`, `part`, `chapter`, `folder`); the folder tree itself owns structure and order.
        - `story/presentation.json`: StoryLoom-managed underline, alignment, highlight, font, and size spans. Do not edit it to write prose.
        - `story/schema.json`: machine-readable field locations and valid enum values.
        - `archive/`: scenes intentionally outside the running manuscript.
        - `history/` and `.storyloom/`: recovery and application bookkeeping; do not edit as part of prose generation.

        ## Safe co-author workflow

        1. Read the relevant scenes and `story/metadata.json` before drafting.
        2. Change only the prose/front matter you were asked to change.
        3. Preserve IDs and unrelated metadata.
        4. Save complete UTF-8 files atomically when your tool supports it.
        5. If StoryLoom reports a simultaneous-edit conflict, do not keep writing that scene until the author chooses a version.

        This file is generated by StoryLoom. Put project-specific AI instructions in root `AGENTS.md` below its StoryLoom pointer, or in a separate file referenced from there.
        """
        try atomicWrite(Data(guide.utf8), to: storyURL.appending(path: "AI-GUIDE.md"))

        let schema: [String: Any] = [
            "formatVersion": 1,
            "prose": [
                "location": "manuscript/**/*.md",
                "format": "UTF-8 Markdown with optional YAML front matter",
                "ordering": "lexicographic path order; numeric prefixes are generated ordering"
            ],
            "sceneFrontMatter": [
                "id": ["type": "uuid", "requiredForExistingScene": true],
                "title": ["type": "string"],
                "volume": ["type": "string"],
                "chapter": ["type": "string"],
                "kind": ["type": "enum", "values": DocumentKind.allCases.map(\.rawValue)],
                "status": ["type": "enum", "values": DocumentStatus.allCases.map(\.rawValue)],
                "pov": ["type": "string"],
                "location": ["type": "string"],
                "targetWordCount": ["type": "integer", "minimum": 0],
                "intention": ["type": "string"],
                "turn": ["type": "string"],
                "withheld": ["type": "string"],
                "residue": ["type": "string"],
                "opens": ["type": "array", "items": "thread UUID"],
                "advances": ["type": "array", "items": "thread UUID"],
                "lands": ["type": "array", "items": "thread UUID"]
            ],
            "metadata": [
                "storyRecords": "story/metadata.json",
                "folderTypes": "story/binder.json",
                "presentation": "story/presentation.json",
                "manifest": "project.storyloom"
            ],
            "enumValues": [
                "folderType": GroupKind.allCases.map(\.rawValue),
                "threadKind": ThreadKind.allCases.map(\.rawValue),
                "entityKind": EntityKind.allCases.map(\.rawValue)
            ]
        ]
        let schemaData = try JSONSerialization.data(withJSONObject: schema, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try atomicWrite(schemaData + Data("\n".utf8), to: storyURL.appending(path: "schema.json"))

        let agentsURL = projectURL.appending(path: "AGENTS.md")
        if !fileManager.fileExists(atPath: agentsURL.path) {
            let pointer = """
            # StoryLoom co-author project

            Read `story/AI-GUIDE.md` and `story/schema.json` before editing. Prose lives in `manuscript/**/*.md`; preserve existing scene UUIDs and unrelated front matter.

            """
            try atomicWrite(Data(pointer.utf8), to: agentsURL)
        }
    }

    private func historyEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        Timestamp.apply(to: encoder)
        return encoder
    }

    private func historyDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        Timestamp.apply(to: decoder)
        return decoder
    }

    /// A manifest path must stay inside the package. A project is a document, and
    /// a document should not be able to reach the rest of the disk (17-Reliability).
    private func resolve(_ relativePath: String, in projectURL: URL) throws -> URL {
        let root = projectURL.standardizedFileURL
        let candidate = root.appending(path: relativePath).standardizedFileURL
        guard candidate.path.hasPrefix(root.path + "/") else {
            throw ProjectRepositoryError.invalidDocumentPath(relativePath)
        }
        return candidate
    }

    private func slug(_ title: String) -> String {
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
}

// MARK: - Errors

enum ProjectRepositoryError: LocalizedError {
    case projectAlreadyExists(URL)
    case missingManifest(URL)
    case missingDocument(URL)
    case invalidDocumentPath(String)
    case malformedStoryMetadata(URL)
    case malformedSnapshot(URL)
    case unsupportedFormatVersion(Int)
    case malformedManifest
    case malformedDocument(URL?)
    case identityMismatch(URL?)
    case projectChangedOnDisk

    var errorDescription: String? {
        switch self {
        case .projectAlreadyExists(let url):
            "A project already exists at “\(url.lastPathComponent)”."
        case .missingManifest:
            "This folder is not a StoryLoom project: it has no project.storyloom file."
        case .missingDocument(let url):
            "The manifest points at a document that is not there: \(url.lastPathComponent)."
        case .invalidDocumentPath:
            "The manifest refers to a file outside the project folder. StoryLoom will not open it."
        case .malformedStoryMetadata(let url):
            "Story records could not be read: \(url.lastPathComponent). The manuscript itself is unaffected."
        case .malformedSnapshot(let url):
            "A history snapshot could not be read: \(url.lastPathComponent)."
        case .unsupportedFormatVersion(let version):
            "This project was written by a newer StoryLoom (format \(version)). Open it there, or export a copy."
        case .malformedManifest:
            "manifest.yaml could not be read."
        case .malformedDocument(let url):
            "A scene could not be read\(url.map { ": \($0.lastPathComponent)" } ?? "")."
        case .identityMismatch(let url):
            "A scene's id does not match the manifest\(url.map { ": \($0.lastPathComponent)" } ?? "")."
        case .projectChangedOnDisk:
            "The project changed on disk before StoryLoom could save. The new prose is being synchronized first."
        }
    }
}

// MARK: - Group index

/// What each directory under `manuscript/` is.
///
/// This is the whole of `story/binder.json` now. It used to hold the outline —
/// names, nesting, ids, order, the lot — and the outline is the directory tree
/// itself, so what is left is the one fact a directory cannot state about
/// itself: whether it is a Volume, a Part, a Chapter, or just a folder.
///
/// Keyed by project-relative path, which means it falls behind the moment
/// somebody renames or moves a directory while the application is not looking.
/// That is the design and it costs exactly one thing: that directory reads as a
/// Folder until its type is set again, which is the answer that is never wrong
/// about a folder nobody has said anything about. An index that could not fall
/// behind would have to be a marker file inside every one of the author's
/// directories, and this format does not litter a folder it asks people to open.
private struct GroupIndex {
    nonisolated static let currentFormatVersion = 2

    var groups: [String: GroupKind] = [:]

    /// The outline as a project written before the folder held it. Present only
    /// on the load that finds one; the next save replaces the file with types.
    var legacyTree: [BinderItem]?

    nonisolated init(groups: [String: GroupKind] = [:], legacyTree: [BinderItem]? = nil) {
        self.groups = groups
        self.legacyTree = legacyTree
    }

    /// `nonisolated`, or its `Codable` conformance is main-actor bound and
    /// cannot be used from the reading and writing below — a warning today and
    /// an error under the Swift 6 language mode.
    nonisolated private struct Stored: Codable {
        var formatVersion: Int
        var groups: [String: String]
    }

    nonisolated func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(
            Stored(
                formatVersion: Self.currentFormatVersion,
                groups: groups.mapValues(\.rawValue)
            )
        )
    }

    /// Missing, unreadable, or written by a StoryLoom that kept the whole tree
    /// here — none of the three is an error. The manuscript is on disk either
    /// way, and the worst case is a tree of plain folders.
    nonisolated static func read(at url: URL) -> GroupIndex {
        guard let data = try? Data(contentsOf: url) else { return GroupIndex() }

        if let stored = try? JSONDecoder().decode(Stored.self, from: data) {
            return GroupIndex(groups: stored.groups.compactMapValues(GroupKind.init(rawValue:)))
        }
        if let tree = try? JSONDecoder().decode([BinderItem].self, from: data) {
            return GroupIndex(legacyTree: tree)
        }
        return GroupIndex()
    }
}

// MARK: - Manifest

private struct ProjectManifest {
    nonisolated static let currentFormatVersion = 1

    struct DocumentEntry {
        let id: UUID
        let path: String

        nonisolated init(id: UUID, path: String) {
            self.id = id
            self.path = path
        }
    }

    let formatVersion: Int
    let id: UUID
    let title: String
    let documents: [DocumentEntry]
    let archivedDocuments: [DocumentEntry]

    nonisolated init(id: UUID, title: String, documents: [DocumentEntry], archivedDocuments: [DocumentEntry] = []) {
        self.formatVersion = Self.currentFormatVersion
        self.id = id
        self.title = title
        self.documents = documents
        self.archivedDocuments = archivedDocuments
    }

    nonisolated private init(
        formatVersion: Int,
        id: UUID,
        title: String,
        documents: [DocumentEntry],
        archivedDocuments: [DocumentEntry]
    ) {
        self.formatVersion = formatVersion
        self.id = id
        self.title = title
        self.documents = documents
        self.archivedDocuments = archivedDocuments
    }

    nonisolated func encode() -> String {
        var lines = [
            "# StoryLoom project manifest. This file is canonical and meant to be read.",
            "formatVersion: \(formatVersion)",
            "id: \(YAML.scalar(id.uuidString))",
            "title: \(YAML.scalar(title))",
            "documents:"
        ]
        lines += documents.flatMap { entry in
            ["  - id: \(YAML.scalar(entry.id.uuidString))", "    path: \(YAML.scalar(entry.path))"]
        }
        lines.append("archivedDocuments:")
        lines += archivedDocuments.flatMap { entry in
            ["  - id: \(YAML.scalar(entry.id.uuidString))", "    path: \(YAML.scalar(entry.path))"]
        }
        return lines.joined(separator: "\n") + "\n"
    }

    nonisolated static func decode(from string: String) throws -> ProjectManifest {
        var scalars: [String: String] = [:]
        var documents: [DocumentEntry] = []
        var archived: [DocumentEntry] = []
        var pending: [String: String] = [:]
        var section: Section?

        func flush() throws {
            guard !pending.isEmpty else { return }
            guard let rawID = pending["id"], let id = UUID(uuidString: rawID), let path = pending["path"] else {
                throw ProjectRepositoryError.malformedManifest
            }
            switch section {
            case .documents: documents.append(.init(id: id, path: path))
            case .archived: archived.append(.init(id: id, path: path))
            case nil: throw ProjectRepositoryError.malformedManifest
            }
            pending = [:]
        }

        for line in string.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.hasPrefix("#") || line.trimmingCharacters(in: .whitespaces).isEmpty { continue }

            if line == "documents:" {
                try flush()
                section = .documents
                continue
            }
            if line == "archivedDocuments:" {
                try flush()
                section = .archived
                continue
            }
            if line.hasPrefix("  - ") {
                guard section != nil else { throw ProjectRepositoryError.malformedManifest }
                try flush()
                let pair = try YAML.pair(line: String(line.dropFirst(4)))
                pending[pair.key] = pair.value
            } else if line.hasPrefix("    ") {
                guard section != nil else { throw ProjectRepositoryError.malformedManifest }
                let pair = try YAML.pair(line: String(line.dropFirst(4)))
                pending[pair.key] = pair.value
            } else {
                let pair = try YAML.pair(line: line)
                scalars[pair.key] = pair.value
            }
        }
        try flush()

        guard let versionText = scalars["formatVersion"], let version = Int(versionText),
              let rawID = scalars["id"], let id = UUID(uuidString: rawID),
              let title = scalars["title"] else {
            throw ProjectRepositoryError.malformedManifest
        }

        return .init(
            formatVersion: version,
            id: id,
            title: title,
            documents: documents,
            archivedDocuments: archived
        )
    }

    private enum Section {
        case documents
        case archived
    }
}

// MARK: - Markdown documents

private enum MarkdownDocument {
    /// Keys this version of StoryLoom understands. Everything else in the front
    /// matter is somebody else's, and is written back out untouched.
    nonisolated static let knownKeys: Set<String> = [
        "id", "title", "volume", "chapter", "kind", "status", "pov", "location",
        "targetWordCount",
        "intention", "turn", "withheld", "residue",
        "opens", "advances", "lands"
    ]

    nonisolated static func encode(_ document: StoryDocument) -> String {
        var lines = [
            "---",
            "id: \(YAML.scalar(document.id.uuidString))",
            "title: \(YAML.scalar(document.title))",
            "volume: \(YAML.scalar(document.volume))",
            "chapter: \(YAML.scalar(document.chapter))",
            "kind: \(YAML.scalar(document.kind.rawValue))",
            "status: \(YAML.scalar(document.status.rawValue))",
            "pov: \(YAML.scalar(document.pov))",
            "location: \(YAML.scalar(document.location))",
            "targetWordCount: \(max(0, document.targetWordCount))",
            "intention: \(YAML.scalar(document.intention))",
            "turn: \(YAML.scalar(document.turn))",
            "withheld: \(YAML.scalar(document.withheld))",
            "residue: \(YAML.scalar(document.residue))",
            "opens: \(YAML.identifiers(document.opensThreadIDs))",
            "advances: \(YAML.identifiers(document.advancesThreadIDs))",
            "lands: \(YAML.identifiers(document.landsThreadIDs))"
        ]
        lines += document.preservedFrontMatter
        lines.append("---")
        return lines.joined(separator: "\n") + "\n" + document.text
    }

    /// Reads a Markdown file that arrived from outside StoryLoom.
    ///
    /// Nothing here can fail, because there is no failure worth reporting: the
    /// file is prose either way, and refusing to open it would leave the author
    /// looking at a folder containing a scene the application says is not there.
    /// Front matter is used when it is ours and ignored when it is not.
    nonisolated static func adopt(from string: String, url: URL) -> StoryDocument {
        if let decoded = try? decode(from: string, expectedID: nil, url: url) { return decoded }

        return StoryDocument(
            title: adoptedTitle(from: string, url: url),
            // No chapter: the file said nothing about where it belongs, and
            // guessing would put it in a chapter the author never wrote.
            chapter: "",
            kind: .scene,
            text: string,
            status: .draft
        )
    }

    /// The first `# Heading`, or the filename made readable.
    ///
    /// A file called `0004-the-long-way-down.md` was almost certainly written by
    /// an earlier StoryLoom, so the ordering prefix comes off; one called
    /// `chapter-three.md` was written by a person, and its hyphens are the only
    /// spaces they had available.
    nonisolated static func adoptedTitle(from string: String, url: URL) -> String {
        let heading = string
            .components(separatedBy: "\n")
            .prefix(20)
            .first { $0.hasPrefix("# ") }
            .map { String($0.dropFirst(2)).trimmingCharacters(in: .whitespaces) }
        if let heading, !heading.isEmpty { return heading }

        var stem = url.deletingPathExtension().lastPathComponent
        stem.replace(/^\d+[-_ ]+/, with: "")
        let spaced = stem
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespaces)
        guard let first = spaced.first else { return "Untitled Scene" }
        return first.uppercased() + spaced.dropFirst()
    }

    /// `expectedID` is the identity the manifest promised. Nil accepts whatever
    /// the file says it is, which is what adoption needs and what a file already
    /// listed in the manifest must never be allowed: a scene that quietly
    /// changes id underneath a binder takes its place in the outline with it.
    nonisolated static func decode(from string: String, expectedID: UUID?, url: URL?) throws -> StoryDocument {
        // Line-based, so that an empty front matter block parses and a `---`
        // scene break in the prose is never mistaken for the terminator.
        let lines = string.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---",
              let terminator = lines.dropFirst().firstIndex(where: {
                  $0.trimmingCharacters(in: .whitespaces) == "---"
              })
        else {
            throw ProjectRepositoryError.malformedDocument(url)
        }

        let body = lines[(terminator + 1)...].joined(separator: "\n")

        var values: [String: String] = [:]
        var preserved: [String] = []

        for line in lines[1..<terminator] {
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }

            // A key is only ours if it is at the top level and we know its name.
            // Anything indented belongs to a structure we do not model, and any
            // unfamiliar key belongs to someone else. Both survive verbatim.
            let isTopLevel = !(line.first?.isWhitespace ?? false)
            if isTopLevel,
               let separator = line.firstIndex(of: ":"),
               knownKeys.contains(String(line[..<separator]).trimmingCharacters(in: .whitespaces)),
               let pair = try? YAML.pair(line: line) {
                values[pair.key] = pair.value
            } else {
                preserved.append(line)
            }
        }

        guard let rawID = values["id"], let id = UUID(uuidString: rawID) else {
            throw ProjectRepositoryError.malformedDocument(url)
        }
        if let expectedID, id != expectedID {
            throw ProjectRepositoryError.identityMismatch(url)
        }

        // Only identity is mandatory. A scene that has lost its `kind` is still a
        // scene with prose in it, and refusing to open it would help no one.
        return StoryDocument(
            id: id,
            title: values["title"] ?? "Untitled Scene",
            volume: values["volume"] ?? "",
            chapter: values["chapter"] ?? "",
            kind: values["kind"].flatMap(DocumentKind.init(rawValue:)) ?? .scene,
            text: body,
            intention: values["intention"] ?? "",
            turn: values["turn"] ?? "",
            withheld: values["withheld"] ?? "",
            residue: values["residue"] ?? "",
            opensThreadIDs: values["opens"].map(YAML.parseIdentifiers) ?? [],
            advancesThreadIDs: values["advances"].map(YAML.parseIdentifiers) ?? [],
            landsThreadIDs: values["lands"].map(YAML.parseIdentifiers) ?? [],
            status: values["status"].flatMap(DocumentStatus.init(rawValue:)) ?? .draft,
            pov: values["pov"] ?? "",
            location: values["location"] ?? "",
            targetWordCount: values["targetWordCount"].flatMap(Int.init).map { max(0, $0) } ?? 500,
            preservedFrontMatter: preserved
        )
    }
}

// MARK: - YAML scalars

/// StoryLoom writes a deliberately small YAML subset and reads a slightly larger
/// one, because the file is a promise to a human with a text editor: what we
/// write must be unambiguous, and what they write back must still parse.
private enum YAML {
    /// JSON strings are valid YAML scalars, which buys dependable quoting and
    /// escaping without taking on a YAML dependency.
    ///
    /// Slashes are left alone. JSON escapes them by default, and every path in the
    /// manifest would read `manuscript\/0001-scene.md` — legal, but the manifest is
    /// meant to be opened and hand-edited by a person, and that is not a path a
    /// person should have to decode.
    nonisolated static func scalar(_ value: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        guard let data = try? encoder.encode(value),
              let encoded = String(data: data, encoding: .utf8) else { return "\"\"" }
        return encoded
    }

    nonisolated static func list(_ values: [String]) -> String {
        guard !values.isEmpty else { return "[]" }
        return "[" + values.map(scalar).joined(separator: ", ") + "]"
    }

    nonisolated static func identifiers(_ values: [UUID]) -> String {
        list(values.map(\.uuidString))
    }

    /// A thread id that no longer names a thread is dropped rather than kept as a
    /// dangling reference: the scene's link is a claim about a question, and a
    /// question that has been deleted cannot be claimed about. The prose is
    /// untouched either way.
    nonisolated static func parseIdentifiers(_ raw: String) -> [UUID] {
        parseList(raw).compactMap(UUID.init(uuidString:))
    }

    nonisolated static func pair(line: String) throws -> (key: String, value: String) {
        guard let separator = line.firstIndex(of: ":") else {
            throw ProjectRepositoryError.malformedManifest
        }
        let key = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
        let raw = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
        return (key, unquote(raw))
    }

    /// Accepts what we write (a JSON string) and what a person would write
    /// (a bare scalar, or one in single quotes).
    nonisolated static func unquote(_ raw: String) -> String {
        if raw.hasPrefix("\""),
           let data = raw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(String.self, from: data) {
            return decoded
        }
        if raw.hasPrefix("'"), raw.hasSuffix("'"), raw.count >= 2 {
            return String(raw.dropFirst().dropLast()).replacingOccurrences(of: "''", with: "'")
        }
        return raw
    }

    nonisolated static func parseList(_ raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else {
            guard !trimmed.isEmpty else { return [] }
            return trimmed.split(separator: ",").map {
                unquote($0.trimmingCharacters(in: .whitespaces))
            }.filter { !$0.isEmpty }
        }
        if let data = trimmed.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            return decoded
        }
        let inner = trimmed.dropFirst().dropLast()
        return inner.split(separator: ",").map {
            unquote($0.trimmingCharacters(in: .whitespaces))
        }.filter { !$0.isEmpty }
    }
}

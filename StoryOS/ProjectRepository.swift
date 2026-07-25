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

import CryptoKit
import Foundation

actor LocalProjectRepository {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// The fixed filename for the project manifest inside every project folder.
    static let manifestFileName = "project.storyloom"

    // MARK: - Lifecycle

    func createProject(title: String, at projectURL: URL) throws -> StoryProject {
        try fileManager.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let project = StoryProject(
            title: title,
            documents: [
                StoryDocument(
                    title: "Untitled Scene",
                    chapter: "Chapter One",
                    kind: .scene,
                    text: "",
                    status: .draft
                )
            ]
        )
        try save(project, to: projectURL)
        _ = try createSnapshot(project, to: projectURL, reason: HistoryReason.projectCreated)
        return project
    }

    /// Writes an existing in-memory project into a brand new folder. Used by the
    /// start screen so the example project can be adopted as real work.
    func createProject(from project: StoryProject, title: String, at projectURL: URL) throws -> StoryProject {
        try fileManager.createDirectory(at: projectURL, withIntermediateDirectories: true)

        var copy = project
        copy.id = UUID()
        copy.title = title
        try save(copy, to: projectURL)
        _ = try createSnapshot(copy, to: projectURL, reason: HistoryReason.projectCreated)
        return copy
    }

    func loadProject(at projectURL: URL) throws -> StoryProject {
        let manifestURL = resolveManifest(in: projectURL)
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw ProjectRepositoryError.missingManifest(manifestURL)
        }

        let manifest = try ProjectManifest.decode(from: try readString(manifestURL))
        guard manifest.formatVersion <= ProjectManifest.currentFormatVersion else {
            throw ProjectRepositoryError.unsupportedFormatVersion(manifest.formatVersion)
        }

        let documents = try load(entries: manifest.documents, in: projectURL)
        let archived = try load(entries: manifest.archivedDocuments, in: projectURL)

        let storyURL = projectURL.appending(path: "story/metadata.json")
        let story: StoryMetadata = fileManager.fileExists(atPath: storyURL.path)
            ? try decodeStoryMetadata(from: storyURL)
            : StoryMetadata()

        return StoryProject(
            id: manifest.id,
            title: manifest.title,
            documents: documents,
            story: story,
            archivedDocuments: archived
        )
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

    func save(_ project: StoryProject, to projectURL: URL) throws {
        let revision = UUID()
        try journal(projectURL, event: "begin", revision: revision, detail: "\(project.documents.count) documents")

        do {
            let entries = try write(project.documents, into: "manuscript", of: projectURL)
            let archived = try write(project.archivedDocuments, into: "archive", of: projectURL)

            let manifest = ProjectManifest(
                id: project.id,
                title: project.title,
                documents: entries,
                archivedDocuments: archived
            )
            try atomicWrite(Data(manifest.encode().utf8), to: projectURL.appending(path: Self.manifestFileName))

            let storyURL = projectURL.appending(path: "story")
            try fileManager.createDirectory(at: storyURL, withIntermediateDirectories: true)
            try atomicWrite(try encodeStoryMetadata(project.story), to: storyURL.appending(path: "metadata.json"))

            try journal(projectURL, event: "commit", revision: revision, detail: fingerprint(at: projectURL))
        } catch {
            try? journal(projectURL, event: "failed", revision: revision, detail: error.localizedDescription)
            throw error
        }
    }

    private func write(
        _ documents: [StoryDocument],
        into directory: String,
        of projectURL: URL
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

        // Reordering or renaming a scene changes its filename. Without this, the
        // package slowly fills with orphans that no manifest points at, and the
        // "open it in a text editor" promise degrades into a junk drawer.
        let existing = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
        for url in existing where url.pathExtension == "md" && !written.contains(url.lastPathComponent) {
            try? fileManager.removeItem(at: url)
        }

        return entries
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
        return try files
            .filter { $0.pathExtension == "json" }
            .map { url in
                do {
                    return try decoder.decode(ProjectSnapshotRecord.self, from: Data(contentsOf: url))
                } catch {
                    throw ProjectRepositoryError.malformedSnapshot(url)
                }
            }
            // Newest first. The id breaks a tie only so that the list is stable:
            // two save points recorded in the same millisecond have no true order,
            // and the alternative is whatever sequence the file system hands back,
            // which can differ between two readings of the same folder.
            .sorted { ($0.createdAt, $0.id.uuidString) > ($1.createdAt, $1.id.uuidString) }
    }

    @discardableResult
    func createSnapshot(_ project: StoryProject, to projectURL: URL, reason: String) throws -> ProjectSnapshotRecord {
        let snapshotsURL = projectURL.appending(path: "history/snapshots")
        try fileManager.createDirectory(at: snapshotsURL, withIntermediateDirectories: true)

        let record = ProjectSnapshotRecord(reason: reason, project: project)
        let milliseconds = Int(record.createdAt.timeIntervalSince1970 * 1_000)
        let fileName = "\(milliseconds)-\(record.id.uuidString).json"
        try atomicWrite(try historyEncoder().encode(record), to: snapshotsURL.appending(path: fileName))
        return record
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
        let canonical = [Self.manifestFileName, "story/metadata.json"]

        for relative in canonical {
            let url = projectURL.appending(path: relative)
            if let data = try? Data(contentsOf: url) {
                hasher.update(data: Data(relative.utf8))
                hasher.update(data: data)
            }
        }
        for directory in ["manuscript", "archive"] {
            let url = projectURL.appending(path: directory)
            let contents = (try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
            for file in contents.filter({ $0.pathExtension == "md" }).sorted(by: { $0.path < $1.path }) {
                if let data = try? Data(contentsOf: file) {
                    hasher.update(data: Data(file.lastPathComponent.utf8))
                    hasher.update(data: data)
                }
            }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
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
        }
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

    nonisolated static func decode(from string: String, expectedID: UUID, url: URL?) throws -> StoryDocument {
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
        guard id == expectedID else {
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

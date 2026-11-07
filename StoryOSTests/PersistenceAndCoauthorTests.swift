import Foundation
import AppKit
import Testing
@testable import StoryLoom

@Suite("Persistence and AI co-authoring", .serialized)
struct PersistenceAndCoauthorTests {
    private func temporaryProjectURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "storyloom-tests-\(UUID().uuidString)")
    }

    private func firstMarkdownFile(in root: URL) -> URL? {
        let enumerator = FileManager.default.enumerator(
            at: root.appending(path: "manuscript"),
            includingPropertiesForKeys: nil
        )
        return (enumerator?.allObjects as? [URL])?
            .filter { $0.pathExtension == "md" }
            .sorted { $0.path < $1.path }
            .first
    }

    @Test("Project format preserves targets, presentation, and AI documentation")
    func persistenceRoundTrip() async throws {
        let root = temporaryProjectURL()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = LocalProjectRepository()
        var opened = try await repository.createProject(title: "Coauthor Test", at: root)

        #expect(FileManager.default.fileExists(atPath: root.appending(path: "AGENTS.md").path))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "story/AI-GUIDE.md").path))
        let schema = try Data(contentsOf: root.appending(path: "story/schema.json"))
        #expect((try JSONSerialization.jsonObject(with: schema)) is [String: Any])

        opened.project.documents[0].text = "Five words live in this scene."
        opened.project.documents[0].targetWordCount = 1_234
        let id = opened.project.documents[0].id
        let run = PresentationRun(
            location: 0,
            length: 4,
            anchor: TextAnchor.make(in: opened.project.documents[0].text, range: NSRange(location: 0, length: 4)),
            underline: true
        )
        let presentation = [id: PresentationLayer(runs: [run])]
        try await repository.save(opened.project, to: root, presentation: presentation)

        let roundTrip = try await repository.loadProject(at: root)
        #expect(roundTrip.project.documents[0].targetWordCount == 1_234)
        #expect(roundTrip.presentation[id]?.runs.first?.underline == true)
    }

    @Test("A stale save cannot overwrite AI prose")
    func staleWriteGuard() async throws {
        let root = temporaryProjectURL()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = LocalProjectRepository()
        let opened = try await repository.createProject(title: "Guard Test", at: root)
        let fingerprint = await repository.fingerprint(at: root)
        let sceneURL = try #require(firstMarkdownFile(in: root))

        var text = try String(contentsOf: sceneURL, encoding: .utf8)
        text += "\nAI added this sentence.\n"
        try Data(text.utf8).write(to: sceneURL, options: .atomic)

        await #expect(throws: ProjectRepositoryError.self) {
            try await repository.save(opened.project, to: root, expectedFingerprint: fingerprint)
        }
        let disk = try await repository.loadProject(at: root)
        #expect(disk.project.documents[0].text.contains("AI added this sentence."))
    }

    @MainActor
    @Test("Disk-only AI edits auto-apply; simultaneous scene edits conflict")
    func workspaceThreeWaySync() async throws {
        let root = temporaryProjectURL()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = LocalProjectRepository()
        var created = try await repository.createProject(title: "Merge Test", at: root)
        created.project.documents.append(StoryDocument(
            title: "Second Scene",
            chapter: "Chapter One",
            kind: .scene,
            text: "Second scene base."
        ))
        created.project.binder = StoryProject.binder(from: created.project.documents)
        try await repository.save(created.project, to: root)
        let defaults = try #require(UserDefaults(suiteName: "StoryLoomTests.\(UUID().uuidString)"))
        let workspace = WorkspaceModel(repository: repository, recents: RecentProjects(defaults: defaults))
        workspace.open(root)
        try await waitUntil("initial project open") { workspace.hasProject && workspace.persistence == .saved }
        let sceneURL = try #require(firstMarkdownFile(in: root))

        var diskText = try String(contentsOf: sceneURL, encoding: .utf8)
        diskText += "\nAI wrote on disk.\n"
        try Data(diskText.utf8).write(to: sceneURL, options: .atomic)
        workspace.checkForExternalChanges()
        try await waitUntil("disk-only prose merge") {
            workspace.project.documents.first?.text.contains("AI wrote on disk.") == true
        }
        #expect(workspace.externalChange == nil)

        workspace.updateText("Local simultaneous edit")
        var disk = try await repository.loadProject(at: root)
        disk.project.documents[0].text += "\nAI simultaneous edit."
        disk.project.documents[1].text = "AI changed only the other scene."
        try await repository.save(disk.project, to: root, presentation: disk.presentation)
        workspace.checkForExternalChanges()
        try await waitUntil("simultaneous-edit conflict") { workspace.externalChange != nil }

        #expect(workspace.project.documents.first?.text == "Local simultaneous edit")
        #expect(workspace.externalChange?.conflictingDocumentIDs.isEmpty == false)
        #expect((try await repository.loadProject(at: root)).project.documents[0].text.contains("AI simultaneous edit."))

        workspace.keepMyVersion()
        try await waitUntil("conflict resolution save") {
            workspace.externalChange == nil && workspace.persistence == .saved
        }
        #expect(workspace.project.documents[0].text == "Local simultaneous edit")
        #expect(workspace.project.documents[1].text == "AI changed only the other scene.")
    }

    @MainActor
    @Test("Rich export preserves Markdown blocks and sidecar presentation")
    func richExportFidelity() throws {
        let text = """
        # A heading

        > Quoted **line**.

        - First
        - Second

        ==bright== and ~~cut~~
        """
        let document = StoryDocument(
            title: "Scene",
            chapter: "Chapter",
            kind: .scene,
            text: text
        )
        let source = text as NSString
        let quotedWord = source.range(of: "Quoted")
        let quoteParagraph = source.paragraphRange(for: quotedWord)
        let layer = PresentationLayer(
            runs: [PresentationRun(
                location: quotedWord.location,
                length: quotedWord.length,
                anchor: TextAnchor.make(in: text, range: quotedWord),
                underline: true
            )],
            blocks: [PresentationBlock(
                location: quoteParagraph.location,
                length: quoteParagraph.length,
                anchor: TextAnchor.make(in: text, range: quoteParagraph),
                alignment: .centre
            )]
        )
        let project = StoryProject(title: "Export", documents: [document])
        var profile = ExportProfile()
        profile.format = .rtf
        profile.includesTitlePage = false
        profile.includesChapterHeadings = false

        let rendered = ExportService.attributed(
            project,
            documents: [document],
            presentation: [document.id: layer],
            profile: profile
        )
        #expect(rendered.string.contains("Quoted line."))
        #expect(rendered.string.contains("•\tFirst"))
        #expect(!rendered.string.contains("> Quoted"))
        #expect(!rendered.string.contains("**"))
        #expect(!rendered.string.contains("=="))
        #expect(!rendered.string.contains("~~"))

        let quote = (rendered.string as NSString).range(of: "Quoted")
        #expect(quote.location != NSNotFound)
        #expect((rendered.attribute(.underlineStyle, at: quote.location, effectiveRange: nil) as? Int) == NSUnderlineStyle.single.rawValue)
        #expect((rendered.attribute(.paragraphStyle, at: quote.location, effectiveRange: nil) as? NSParagraphStyle)?.alignment == .center)

        let bright = (rendered.string as NSString).range(of: "bright")
        let cut = (rendered.string as NSString).range(of: "cut")
        #expect(rendered.attribute(.backgroundColor, at: bright.location, effectiveRange: nil) != nil)
        #expect((rendered.attribute(.strikethroughStyle, at: cut.location, effectiveRange: nil) as? Int) == NSUnderlineStyle.single.rawValue)
    }

    @MainActor
    private func waitUntil(
        _ stage: String,
        timeout: Duration = .seconds(4),
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            guard clock.now < deadline else { throw TestTimeout(stage: stage) }
            try await Task.sleep(for: .milliseconds(25))
        }
    }
}

private struct TestTimeout: LocalizedError {
    let stage: String
    var errorDescription: String? { "Timed out waiting for \(stage)" }
}

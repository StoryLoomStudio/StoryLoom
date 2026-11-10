import Foundation
import Testing
@testable import StoryLoom

/// The v1 fixture generator (shared with the StoryLoomKit tests) must write what
/// the current app writes and reads. These tests are the check that its
/// hand-written JSON and front matter have not drifted from the real types.
@Suite("v1 fixture compatibility", .serialized)
struct V1FixtureCompatibilityTests {
    private func relativeFiles(under root: URL) -> [String] {
        let root = root.resolvingSymlinksInPath()
        let urls = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])?
            .allObjects as? [URL] ?? []
        return urls
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true }
            .map { String($0.resolvingSymlinksInPath().path.dropFirst(root.path.count + 1)) }
            .sorted()
    }

    private func depth(of items: [BinderItem]) -> Int {
        items.filter(\.isFolder).map { 1 + depth(of: $0.children) }.max() ?? 0
    }

    @Test("The current loader opens the generated project and finds every scene", arguments: [60, 1_000])
    func loaderOpensFixture(count: Int) async throws {
        let temp = TemporaryDirectory("storyloom-v1-fixture")
        defer { temp.cleanUp() }
        let root = temp.child("Fixture Novel")
        let report = try V1Fixture.write(to: root, options: .init(sceneCount: count, historySnapshots: 1))

        let load = try await LocalProjectRepository().loadProject(at: root)

        // Listed scenes plus the unprefixed folder's plain Markdown.
        #expect(load.project.documents.count == report.expectedLoadedSceneCount)
        #expect(load.project.archivedDocuments.count == report.archivedIDs.count)
        #expect(Set(load.adopted) == Set(report.strayPaths))
        #expect(load.warnings.isEmpty)
        #expect(load.project.id == report.projectID)
        #expect(load.project.title == report.title)

        // Reading order is the manifest's, with the strays after the prefixed entries.
        #expect(Array(load.project.documents.map(\.id).prefix(count)) == report.sceneIDs)
        #expect(depth(of: load.project.binder) >= 3)

        let story = load.project.story
        #expect(story.entities.count == report.entityCount)
        #expect(story.relationships.count == report.relationshipCount)
        #expect(story.events.count == report.eventCount)
        #expect(story.notes.count == report.noteCount)
        #expect(story.comments.count == report.commentCount)
        #expect(story.trash.count == report.trashCount)
        #expect(story.threads.count == report.threadIDs.count)
        #expect(story.entities.contains { $0.kind == .character && !$0.aliases.isEmpty })
        #expect(Set(load.presentation.keys) == Set(report.presentationSceneIDs))

        let linked = load.project.documents.filter { !$0.roles(for: report.linkedThreadID).isEmpty }
        #expect(linked.count >= 5)

        let payloads = story.trash.map(\.payload)
        #expect(payloads.contains { if case .document = $0 { true } else { false } })
        #expect(payloads.contains { if case .group(_, let docs) = $0 { docs.count == 2 } else { false } })
    }

    @Test("Loading then saving the generated project reproduces its files byte for byte")
    func roundTripIsByteIdentical() async throws {
        let temp = TemporaryDirectory("storyloom-v1-roundtrip")
        defer { temp.cleanUp() }
        let original = temp.child("original")
        let copy = temp.child("copy")
        try V1Fixture.write(to: original, options: .init(sceneCount: 60, debris: false, historySnapshots: 1))
        try FileManager.default.copyItem(at: original, to: copy)

        let repository = LocalProjectRepository()
        let load = try await repository.loadProject(at: copy)
        try await repository.save(load.project, to: copy, presentation: load.presentation)

        // History and the journal are bookkeeping the save appends to.
        func canonical(_ files: [String]) -> [String] {
            files.filter { !$0.hasPrefix("history/") && !$0.hasPrefix(".storyloom/") }
        }
        let originalFiles = canonical(relativeFiles(under: original))
        #expect(originalFiles == canonical(relativeFiles(under: copy)))
        #expect(originalFiles.count > 60)
        for path in originalFiles {
            let before = try Data(contentsOf: original.appending(path: path))
            let after = try Data(contentsOf: copy.appending(path: path))
            #expect(before == after, "\(path) differs after a load/save round trip")
        }
    }

    @Test("Generated save points decode with the app's history reader")
    func snapshotsDecode() async throws {
        let temp = TemporaryDirectory("storyloom-v1-history")
        defer { temp.cleanUp() }
        let root = temp.child("Fixture Novel")
        let report = try V1Fixture.write(to: root, options: .init(sceneCount: 60, historySnapshots: 3))

        let snapshots = try await LocalProjectRepository().loadSnapshots(at: root)
        #expect(snapshots.count == 3)
        #expect(snapshots.allSatisfy { $0.project.documents.count == report.sceneIDs.count })
        #expect(snapshots.allSatisfy { $0.documentCount == report.sceneIDs.count })
        #expect(Set(snapshots.map(\.reason)) == ["Project created", "Autosave checkpoint", "Manual snapshot"])
        #expect(snapshots.first?.presentation.count == report.presentationSceneIDs.count)
    }
}

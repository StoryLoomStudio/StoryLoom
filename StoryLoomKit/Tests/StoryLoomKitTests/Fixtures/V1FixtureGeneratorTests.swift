import Foundation
import Testing

@Suite("v1 fixture generator")
struct V1FixtureGeneratorTests {
    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "storyloomkit-fixture-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    private func files(under root: URL, extension ext: String? = nil) -> [String] {
        let root = root.resolvingSymlinksInPath()
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])
        return (enumerator?.allObjects as? [URL] ?? [])
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true }
            .filter { ext == nil || $0.pathExtension == ext }
            .map { String($0.resolvingSymlinksInPath().path.dropFirst(root.path.count + 1)) }
            .sorted()
    }

    @Test("A 60-scene project has the v1 layout and debris", arguments: [60, 1_000])
    func layout(count: Int) throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let report = try V1Fixture.write(to: root, options: .init(sceneCount: count, historySnapshots: count > 100 ? 1 : 3))

        #expect(report.sceneIDs.count == count)
        #expect(Set(report.sceneIDs).count == count)
        #expect(report.maxFolderDepth >= 3)
        #expect(report.expectedLoadedSceneCount == count + 2)

        for name in ["project.storyloom", "manifest.yaml", "AGENTS.md", "story/metadata.json", "story/binder.json",
                     "story/presentation.json", "story/AI-GUIDE.md", "story/schema.json",
                     ".storyloom/journal/journal.ndjson"] {
            #expect(FileManager.default.fileExists(atPath: root.appending(path: name).path), "missing \(name)")
        }
        #expect(files(under: root.appending(path: "history/snapshots"), extension: "json").count == report.snapshotCount)

        // Every listed scene exists; nothing under manuscript/ beyond the listed scenes and the strays.
        let manuscript = files(under: root, extension: "md").filter { $0.hasPrefix("manuscript/") }
        #expect(Set(manuscript) == Set(report.scenePaths).union(report.strayPaths))

        // The debris is there: two empty duplicate folders and an unprefixed one.
        for folder in report.emptyDuplicateFolders {
            let contents = try FileManager.default.contentsOfDirectory(atPath: root.appending(path: folder).path)
            #expect(contents.isEmpty)
        }
        #expect(report.strayPaths.allSatisfy { !$0.split(separator: "/").dropLast().last!.first!.isNumber })
    }

    @Test("Scene files carry all sixteen v1 keys, even when empty")
    func sceneFrontMatter() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let report = try V1Fixture.write(to: root, options: .init(sceneCount: 60))
        let keys = ["id", "title", "volume", "chapter", "kind", "status", "pov", "location", "targetWordCount",
                    "intention", "turn", "withheld", "residue", "opens", "advances", "lands"]
        for path in report.scenePaths {
            let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
            let front = text.components(separatedBy: "\n").dropFirst().prefix(while: { $0 != "---" })
            let present = front.compactMap { $0.split(separator: ":", maxSplits: 1).first.map(String.init) }
            #expect(Array(present.prefix(16)) == keys, "\(path)")
        }
    }

    @Test("A thread is linked from several scenes")
    func threadLinks() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let report = try V1Fixture.write(to: root, options: .init(sceneCount: 60))
        var linked = 0
        for path in report.scenePaths {
            let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
            if text.contains(report.linkedThreadID.uuidString) { linked += 1 }
        }
        #expect(linked >= 5)
    }

    @Test("The same seed produces the same bytes")
    func deterministic() throws {
        let a = temporaryRoot(), b = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: a); try? FileManager.default.removeItem(at: b) }
        try V1Fixture.write(to: a, options: .init(sceneCount: 60))
        try V1Fixture.write(to: b, options: .init(sceneCount: 60))
        let listing = files(under: a)
        #expect(listing == files(under: b))
        for path in listing {
            #expect(try Data(contentsOf: a.appending(path: path)) == Data(contentsOf: b.appending(path: path)), "\(path)")
        }
    }

    @Test("Story records and trash are populated")
    func storyRecords() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let report = try V1Fixture.write(to: root, options: .init(sceneCount: 60))
        let data = try Data(contentsOf: root.appending(path: "story/metadata.json"))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect((json["entities"] as? [Any])?.count == report.entityCount)
        #expect((json["trash"] as? [[String: Any]])?.count == 4)
        let payloads = (json["trash"] as? [[String: Any]])?.compactMap { ($0["payload"] as? [String: Any])?.keys.first }
        #expect(payloads?.contains("document") == true)
        #expect(payloads?.contains("group") == true)
        let characters = (json["entities"] as? [[String: Any]])?.filter { $0["kind"] as? String == "character" }
        #expect(characters?.contains { ($0["aliases"] as? [String])?.isEmpty == false } == true)
        #expect(report.eventCount == 4 && report.commentCount > 0 && report.noteCount > 0)
    }

    @Test("Filler prose is invented, not borrowed")
    func proseIsGenerated() {
        var rng = FixtureRandom(seed: 1)
        let sample = FixtureProse.paragraph(&rng, names: [], sentences: 4)
        #expect(sample.split(separator: " ").count > 20)
        var again = FixtureRandom(seed: 1)
        #expect(sample == FixtureProse.paragraph(&again, names: [], sentences: 4))
    }
}

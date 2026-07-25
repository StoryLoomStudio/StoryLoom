//
//  RecentProjects.swift
//  StoryLoom
//
//  Reopening yesterday's work must not require finding it again. Under the
//  sandbox that means security-scoped bookmarks: permission to a folder the
//  author once chose, persisted across launches, revocable by forgetting it.
//

import AppKit
import Combine
import Foundation

@MainActor
final class RecentProjects: ObservableObject {
    struct Entry: Identifiable, Hashable {
        let path: String
        let name: String
        let lastOpened: Date

        var id: String { path }
        var url: URL { URL(filePath: path) }
        var exists: Bool { FileManager.default.fileExists(atPath: path) }
    }

    @Published private(set) var entries: [Entry] = []

    private let defaults: UserDefaults
    private let key = "storyloom.recentProjects"
    private let limit = 8

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        entries = load()
    }

    var mostRecent: Entry? { entries.first { $0.exists } }

    func remember(_ url: URL) {
        var stored = rawEntries().filter { $0["path"] as? String != url.path }

        var record: [String: Any] = [
            "path": url.path,
            "name": url.deletingPathExtension().lastPathComponent,
            "date": Date.now
        ]

        let accessed = url.startAccessingSecurityScopedResource()
        if let bookmark = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
            record["bookmark"] = bookmark
        }
        if accessed {
            url.stopAccessingSecurityScopedResource()
        }

        stored.insert(record, at: 0)
        defaults.set(Array(stored.prefix(limit)), forKey: key)
        entries = load()
    }

    /// Resolves the bookmark and begins security-scoped access. The caller owns
    /// stopping it; `WorkspaceModel` does that when it switches projects.
    func resolve(_ entry: Entry) -> URL? {
        guard let record = rawEntries().first(where: { $0["path"] as? String == entry.path }),
              let bookmark = record["bookmark"] as? Data else {
            return nil
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        if isStale { remember(url) }
        return url
    }

    func forget(_ entry: Entry) {
        let stored = rawEntries().filter { $0["path"] as? String != entry.path }
        defaults.set(stored, forKey: key)
        entries = load()
    }

    func clear() {
        defaults.removeObject(forKey: key)
        entries = []
    }

    private func rawEntries() -> [[String: Any]] {
        defaults.array(forKey: key) as? [[String: Any]] ?? []
    }

    private func load() -> [Entry] {
        rawEntries().compactMap { record in
            guard let path = record["path"] as? String,
                  let name = record["name"] as? String else { return nil }
            return Entry(path: path, name: name, lastOpened: record["date"] as? Date ?? .distantPast)
        }
    }
}

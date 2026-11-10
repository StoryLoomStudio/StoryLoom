import Foundation
@testable import StoryLoom

/// A throwaway `UserDefaults` store. Tests run inside the app's sandbox
/// container, so a named suite would leave a `.plist` in the author's
/// preferences (and `removePersistentDomain` does not stop the daemon from
/// re-creating an empty one). A suite named by an absolute path keeps its plist
/// inside a temporary directory instead, and `cleanUp()` removes both.
final class IsolatedDefaults {
    let directory = TemporaryDirectory("storyloom-defaults")
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: directory.child("defaults").path)!
    }

    func cleanUp() {
        defaults.removePersistentDomain(forName: directory.child("defaults").path)
        directory.cleanUp()
    }
}

/// A fresh directory under the system temporary folder, removed by `cleanUp()`.
final class TemporaryDirectory {
    let url: URL

    init(_ label: String = "storyloom-tests") {
        url = FileManager.default.temporaryDirectory
            .appending(path: "\(label)-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    /// A child path that does not exist yet (for `createProject(at:)`).
    func child(_ name: String) -> URL { url.appending(path: name) }

    func cleanUp() { try? FileManager.default.removeItem(at: url) }
}

import Foundation
import OSLog

/// Facts about the process the app is running in.
nonisolated enum AppEnvironment {
    /// True when the app is only the host process for the unit-test bundle.
    /// A hosted run must not reopen a remembered project or touch real recents.
    static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "io.storyloom"
}

/// One `Logger` per concern, all under the bundle id so a Debug build
/// (`io.storyloom.dev`) and the release app are filtered separately in Console.
nonisolated enum Log {
    static let persistence = Logger(subsystem: AppEnvironment.bundleIdentifier, category: "persistence")
    static let sync = Logger(subsystem: AppEnvironment.bundleIdentifier, category: "sync")
    static let history = Logger(subsystem: AppEnvironment.bundleIdentifier, category: "history")
    static let export = Logger(subsystem: AppEnvironment.bundleIdentifier, category: "export")
    static let editor = Logger(subsystem: AppEnvironment.bundleIdentifier, category: "editor")
    static let app = Logger(subsystem: AppEnvironment.bundleIdentifier, category: "app")
}

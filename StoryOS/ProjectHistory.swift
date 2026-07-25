//
//  ProjectHistory.swift
//  StoryLoom
//
//  Portable save points for early recovery and version history. These records
//  are intentionally separate from canonical manuscript files so the current
//  project remains readable even without the app.
//

import Foundation

nonisolated struct ProjectSnapshotRecord: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var createdAt = Date.stamp
    var reason: String
    var projectTitle: String
    var wordCount: Int
    var documentCount: Int
    var project: StoryProject

    nonisolated init(reason: String, project: StoryProject, createdAt: Date = .stamp) {
        self.createdAt = createdAt
        self.reason = reason
        self.projectTitle = project.title
        self.wordCount = project.totalWordCount
        self.documentCount = project.documents.count
        self.project = project
    }
}

nonisolated enum HistoryReason {
    static let projectCreated = "Project created"
    static let manual = "Manual snapshot"
    static let autosave = "Autosave checkpoint"
    static let beforeRestore = "Before restore"

    static func restored(from snapshot: ProjectSnapshotRecord) -> String {
        "Restored from \(snapshot.projectTitle) snapshot"
    }
}

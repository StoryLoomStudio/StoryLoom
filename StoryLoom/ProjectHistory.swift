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
    /// Appearance that cannot be represented in Markdown. Kept in history with
    /// the prose so restoring a save point restores what the author actually
    /// saw, not only the characters underneath it.
    var presentation: [UUID: PresentationLayer]

    nonisolated init(
        reason: String,
        project: StoryProject,
        presentation: [UUID: PresentationLayer] = [:],
        createdAt: Date = .stamp
    ) {
        self.createdAt = createdAt
        self.reason = reason
        self.projectTitle = project.title
        self.wordCount = project.totalWordCount
        self.documentCount = project.documents.count
        self.project = project
        self.presentation = presentation
    }

    private enum CodingKeys: String, CodingKey {
        case id, createdAt, reason, projectTitle, wordCount, documentCount, project, presentation
    }

    /// Snapshots written before presentation persistence remain valid.
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .stamp
        reason = try container.decode(String.self, forKey: .reason)
        project = try container.decode(StoryProject.self, forKey: .project)
        projectTitle = try container.decodeIfPresent(String.self, forKey: .projectTitle) ?? project.title
        wordCount = try container.decodeIfPresent(Int.self, forKey: .wordCount) ?? project.totalWordCount
        documentCount = try container.decodeIfPresent(Int.self, forKey: .documentCount) ?? project.documents.count
        presentation = try container.decodeIfPresent([UUID: PresentationLayer].self, forKey: .presentation) ?? [:]
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

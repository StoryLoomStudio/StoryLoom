//
//  HistoryViews.swift
//  StoryLoom
//
//  Project history: the save points, and what a project used to say.
//
//  This file used to open with the continuity review — the findings list and its
//  evidence pane. That room was removed from the sidebar, and its two views went
//  with it rather than being left compiling but unreachable.
//
//  `ContinuityChecker` and `WorkspaceModel.findings` survive it and currently
//  have no reader. They are deliberately not deleted here: the engine is the
//  hard part and the disposition data on disk is the author's, not ours.
//

import Combine
import SwiftUI


// MARK: - History: list

struct SnapshotList: View {
    @EnvironmentObject private var workspace: WorkspaceModel

    var body: some View {
        VStack(spacing: 0) {
            Strip {
                Text(workspace.history.isEmpty ? "No save points" : "\(workspace.history.count) save points")
                    .font(Chrome.small)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer(minLength: Space.small)

                Button {
                    workspace.createSnapshot()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11, weight: .medium))
                .help("Save a point you can come back to (⇧⌘S)")
            }

            if workspace.history.isEmpty {
                EmptyStateView(
                    symbol: "clock.arrow.circlepath",
                    title: "No save points yet",
                    message: workspace.projectURL == nil
                        ? "Save this project to disk and StoryLoom will start keeping history for you."
                        : "StoryLoom adds one as you work. You can also make one now, before you try something reckless.",
                    actionTitle: workspace.projectURL == nil ? "Save Project…" : "Save a point now",
                    action: {
                        workspace.createSnapshot()
                    }
                )
            } else {
                List(selection: $workspace.selectedSnapshotID) {
                    ForEach(workspace.history) { snapshot in
                        HStack(spacing: Space.snug) {
                            Text(snapshot.reason)
                                .font(Chrome.body)
                                .lineLimit(1)

                            Spacer(minLength: Space.tight)

                            Text(snapshot.createdAt, format: .dateTime.month().day().hour().minute())
                                .font(Chrome.small)
                                .foregroundStyle(.tertiary)
                                .monospacedDigit()
                                .lineLimit(1)
                        }
                        .tag(snapshot.id)
                        .contextMenu {
                            Button("Delete Save Point", role: .destructive) {
                                workspace.deleteSnapshot(snapshot)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .denseList()
            }
        }
    }
}

// MARK: - History: detail

struct SnapshotDetail: View {
    @EnvironmentObject private var workspace: WorkspaceModel
    @State private var isConfirmingRestore = false

    var body: some View {
        Group {
            if let snapshot = workspace.selectedSnapshot {
                VStack(spacing: 0) {
                    Strip {
                        Text(snapshot.createdAt, format: .dateTime.weekday(.wide).month().day().hour().minute())
                            .font(Chrome.small)
                            .foregroundStyle(.secondary)

                        Spacer(minLength: Space.small)

                        Button {
                            isConfirmingRestore = true
                        } label: {
                            Label("Restore this version", systemImage: "arrow.counterclockwise")
                        }
                        .controlSize(.small)
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: Space.section) {
                            VStack(alignment: .leading, spacing: Space.snug) {
                                Text(snapshot.reason)
                                    .font(.system(size: 22, weight: .semibold))

                                Text(summary(snapshot))
                                    .font(Chrome.text)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()

                                Text("Restoring writes a save point for where you are now, then brings this version forward as a new revision. Nothing later is deleted.")
                                    .font(Chrome.meta)
                                    .foregroundStyle(.tertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, Space.tight)
                            }

                            Block("What was in it", caption: "read-only") {
                                VStack(spacing: 0) {
                                    ForEach(snapshot.project.documents.prefix(12)) { document in
                                        VStack(alignment: .leading, spacing: 1) {
                                            HStack(spacing: Space.small) {
                                                Text(document.displayTitle)
                                                    .font(Chrome.textStrong)
                                                Text(document.chapterTitle)
                                                    .font(Chrome.meta)
                                                    .foregroundStyle(.tertiary)
                                                Spacer(minLength: Space.medium)
                                                Text(document.wordCount.formatted())
                                                    .font(Chrome.meta)
                                                    .foregroundStyle(.tertiary)
                                                    .monospacedDigit()
                                            }
                                            Text(document.isEmpty ? "Empty." : document.text)
                                                .font(.system(size: 12, design: .serif))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                        }
                                        .padding(.vertical, Space.medium)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .overlay(alignment: .bottom) {
                                            Rectangle()
                                                .fill(Palette.hairline)
                                                .frame(height: 1)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: Metrics.canvasWidth, alignment: .leading)
                        .padding(.horizontal, Space.page)
                        .padding(.top, Space.section)
                        .padding(.bottom, Space.page * 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .confirmationDialog(
                    "Restore “\(snapshot.reason)”?",
                    isPresented: $isConfirmingRestore,
                    titleVisibility: .visible
                ) {
                    Button("Restore") { workspace.restoreSnapshot(snapshot) }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Your current version is saved as a new point first, so this is reversible.")
                }
            } else {
                EmptyStateView(
                    symbol: "clock.arrow.circlepath",
                    title: "No save point selected",
                    message: "Inspect a version before you decide to go back to it."
                )
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    /// Three numbers, one line. They used to be three stat blocks in a row, which is
    /// what a dashboard does with a fact it does not trust you to read.
    private func summary(_ snapshot: ProjectSnapshotRecord) -> String {
        let words = snapshot.wordCount.formatted()
        let documents = snapshot.documentCount
        let delta = workspace.project.totalWordCount - snapshot.wordCount
        let since = delta == 0 ? "the same as now" : (delta > 0 ? "\(delta.formatted()) fewer than now" : "\((-delta).formatted()) more than now")
        return "\(words) words · \(documents) document\(documents == 1 ? "" : "s") · \(since)"
    }
}

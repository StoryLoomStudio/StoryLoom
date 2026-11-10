//
//  TrashViews.swift
//  StoryLoom
//
//  The list of what was thrown away, and the one thing you can do about it.
//
//  This room is deliberately dull. It has no search, no sorting, no bulk
//  selection and no preview of the deleted thing's contents, because the moment
//  it becomes pleasant to browse it stops being a safety net and starts being a
//  place things live. Newest first, put it back or lose it, and nothing else.
//

import SwiftUI

// MARK: - List

struct TrashList: View {
    @EnvironmentObject private var workspace: WorkspaceModel
    @State private var isConfirmingEmpty = false

    private var items: [TrashedItem] { workspace.project.story.trash }

    var body: some View {
        VStack(spacing: 0) {
            Strip {
                Text(items.isEmpty ? "Empty" : "\(items.count) \(items.count == 1 ? "item" : "items")")
                    .font(Chrome.small)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer(minLength: Space.small)

                Button("Delete All", role: .destructive) { isConfirmingEmpty = true }
                    .buttonStyle(.borderless)
                    .font(Chrome.small)
                    .tint(.red)
                    .disabled(items.isEmpty)
                    .help("Delete everything here permanently")
            }

            if items.isEmpty {
                EmptyStateView(
                    glyph: .trash,
                    title: "Nothing in the trash",
                    message: "Records, threads, events and notes you delete wait here until you empty it."
                )
            } else {
                List(selection: $workspace.selectedTrashID) {
                    ForEach(items) { item in
                        TrashRow(item: item)
                            .tag(item.id)
                            .contextMenu {
                                Button("Put Back") { workspace.restoreFromTrash(item) }
                                    .disabled(!workspace.canRestore(item))
                                Divider()
                                Button("Delete Permanently", role: .destructive) {
                                    workspace.purgeFromTrash(item)
                                }
                            }
                    }
                }
                .listStyle(.sidebar)
                .denseList()
            }
        }
        .confirmationDialog(
            "Empty the trash?",
            isPresented: $isConfirmingEmpty,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive) { workspace.emptyTrash() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(items.count) \(items.count == 1 ? "item" : "items") will be deleted permanently. This cannot be undone.")
        }
    }
}

private struct TrashRow: View {
    let item: TrashedItem

    var body: some View {
        HStack(spacing: Space.snug) {
            IconView(item.icon, size: Icon.navigatorRow)
                .foregroundStyle(item.tint)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(Chrome.body)
                    .lineLimit(1)

                Text(item.contentsSummary)
                    .font(Chrome.small)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Space.tight)

            Text(item.deletedAt, format: .relative(presentation: .numeric))
                .font(Chrome.small)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.category): \(item.title), \(item.contentsSummary)")
    }
}

// MARK: - Detail

struct TrashDetail: View {
    @EnvironmentObject private var workspace: WorkspaceModel

    private var item: TrashedItem? {
        workspace.project.story.trash.first { $0.id == workspace.selectedTrashID }
    }

    var body: some View {
        Group {
            if let item {
                VStack(spacing: 0) {
                    Strip {
                        Text(item.category)
                            .font(Chrome.small)
                            .foregroundStyle(.secondary)

                        Spacer(minLength: Space.small)

                        Text(item.deletedAt, format: .dateTime.weekday(.wide).month().day().hour().minute())
                            .font(Chrome.small)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }

                    VStack(alignment: .leading, spacing: Space.regular) {
                        HStack(spacing: Space.small) {
                            IconView(item.icon, size: Icon.emptyState)
                                .foregroundStyle(item.tint)

                            Text(item.title)
                                .font(.system(size: 17, weight: .semibold))
                                .textSelection(.enabled)
                        }

                        TrashContents(item: item)

                        if !workspace.canRestore(item) {
                            // Said plainly and up front, rather than by disabling a
                            // button and leaving the author to guess why.
                            Label {
                                Text("The record this connected is gone, so this cannot be put back.")
                            } icon: {
                                GlyphIcon(glyph: .threat, size: Icon.inline)
                            }
                            .font(Chrome.small)
                            .foregroundStyle(.secondary)
                        }

                        HStack(spacing: Space.small) {
                            Button("Put Back") { workspace.restoreFromTrash(item) }
                                .buttonStyle(.borderedProminent)
                                .disabled(!workspace.canRestore(item))

                            Button("Delete Permanently", role: .destructive) {
                                workspace.purgeFromTrash(item)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(Space.section)
                }
            } else {
                EmptyStateView(
                    glyph: .trash,
                    title: "Nothing selected",
                    message: "Choose something on the left to put it back or delete it for good."
                )
            }
        }
    }
}

/// Shows the prose that is protected by a trash entry without turning Trash
/// into another editor. A deleted chapter remains one restorable unit, while
/// its scenes and their word counts stay visible enough to restore confidently.
private struct TrashContents: View {
    let item: TrashedItem

    var body: some View {
        switch item.payload {
        case .document(let document):
            documentPreview(document)
        case .group(_, let documents):
            groupPreview(documents)
        default:
            Text(item.contentsSummary)
                .font(Chrome.body)
                .foregroundStyle(.secondary)
        }
    }

    private func documentPreview(_ document: StoryDocument) -> some View {
        VStack(alignment: .leading, spacing: Space.snug) {
            Text("Contents")
                .font(Chrome.small)
                .foregroundStyle(.secondary)

            Text(document.wordCount > 0 ? "\(document.wordCount.formatted()) words" : "Empty scene")
                .font(Chrome.small)
                .foregroundStyle(.tertiary)

            Text(excerpt(from: document.text))
                .font(Chrome.body)
                .foregroundStyle(document.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .primary)
                .lineLimit(8)
                .textSelection(.enabled)
        }
        .padding(Space.regular)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panel)
    }

    private func groupPreview(_ documents: [StoryDocument]) -> some View {
        VStack(alignment: .leading, spacing: Space.snug) {
            HStack {
                Text("Contents")
                    .font(Chrome.small)
                    .foregroundStyle(.secondary)

                Spacer(minLength: Space.small)

                Text(item.contentsSummary)
                    .font(Chrome.small)
                    .foregroundStyle(.tertiary)
            }

            if documents.isEmpty {
                Text("This group was empty.")
                    .font(Chrome.body)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(documents.prefix(8)) { document in
                        HStack(spacing: Space.snug) {
                            StatusDot(color: document.status.tint, size: 7)
                            Text(document.displayTitle)
                                .font(Chrome.body)
                                .lineLimit(1)
                            Spacer(minLength: Space.small)
                            if document.wordCount > 0 {
                                Text(document.wordCount.formatted(.number))
                                    .font(Chrome.small)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, Space.tight)
                    }

                    if documents.count > 8 {
                        Text("+ \(documents.count - 8) more scenes")
                            .font(Chrome.small)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, Space.small)
                    }
                }
            }
        }
        .padding(Space.regular)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panel)
    }

    private var panel: some View {
        RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
            .fill(Color.primary.opacity(0.05))
    }

    private func excerpt(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "This scene did not contain any prose." : trimmed
    }
}

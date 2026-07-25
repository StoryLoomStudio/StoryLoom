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

                Button("Empty") { isConfirmingEmpty = true }
                    .buttonStyle(.borderless)
                    .font(Chrome.small)
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
            Button("Empty Trash", role: .destructive) { workspace.emptyTrash() }
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

            Text(item.title)
                .font(Chrome.body)
                .lineLimit(1)

            Spacer(minLength: Space.tight)

            Text(item.deletedAt, format: .relative(presentation: .numeric))
                .font(Chrome.small)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.category): \(item.title)")
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

//
//  ThreadViews.swift
//  StoryLoom
//
//  The room where a novelist finds out what they still owe.
//
//  Everything else in StoryLoom shows the author what they have written. This shows
//  them what the reader is *holding* — the questions still open, in the order the
//  reader met them, with how long it has been since anything touched each one. It
//  is the screen you open on the morning of chapter forty, and it is the reason
//  the rest of the application exists.
//

import SwiftUI

// MARK: - Navigator

struct ThreadList: View {
    @EnvironmentObject private var workspace: WorkspaceModel
    @State private var filter = ""

    private var arcs: [ThreadArc] {
        guard !filter.isEmpty else { return workspace.arcs }
        return workspace.arcs.filter {
            $0.thread.question.localizedCaseInsensitiveContains(filter)
                || $0.thread.answer.localizedCaseInsensitiveContains(filter)
        }
    }

    private var groups: [(state: ThreadState, arcs: [ThreadArc])] {
        ThreadState.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { state in
                let matching = arcs.filter { $0.state == state }
                return matching.isEmpty ? nil : (state, matching)
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigatorBar(filter: $filter, prompt: "Filter threads") {
                Menu {
                    ForEach(ThreadKind.allCases, id: \.self) { kind in
                        Button {
                            workspace.createThread(kind: kind)
                        } label: {
                            Label { Text(kind.title) } icon: { kind.glyph.menuImage() }
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .help("Open a new thread")
            }

            if arcs.isEmpty {
                EmptyStateView(
                    symbol: filter.isEmpty ? "questionmark.diamond" : "magnifyingglass",
                    title: filter.isEmpty ? "Nothing is owed yet" : "Nothing matches “\(filter)”",
                    message: filter.isEmpty
                        ? "A thread is a question living in the reader's head — a mystery, a promise, a threat, a want. One scene opens it and another lands it, and StoryLoom keeps count of the distance between."
                        : "Try another word, or clear the filter.",
                    actionTitle: filter.isEmpty ? "Open the first thread" : nil,
                    action: filter.isEmpty ? { workspace.createThread() } : nil
                )
            } else {
                List(selection: $workspace.selectedThreadID) {
                    ForEach(groups, id: \.state) { group in
                        Section {
                            ForEach(group.arcs) { arc in
                                ThreadRow(arc: arc)
                                    .tag(arc.thread.id)
                                    .contextMenu { menu(arc) }
                            }
                        } header: {
                            GroupHeader(title: group.state.title, count: group.arcs.count)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .controlBackgroundColor))
                .denseList()
            }
        }
    }

    @ViewBuilder
    private func menu(_ arc: ThreadArc) -> some View {
        if arc.thread.isAbandoned {
            Button("Owe It Again") { workspace.setThreadAbandoned(arc.thread.id, false) }
        } else {
            Button("Leave Open on Purpose") { workspace.setThreadAbandoned(arc.thread.id, true) }
        }
        Divider()
        Button("Delete", role: .destructive) { workspace.deleteThread(arc.thread.id) }
    }
}

/// A question, and the one number that matters about it: how far the reader has
/// carried it without being given anything.
///
/// The question truncates. That is deliberate — the first five words of a question
/// are enough to know which question it is, and the alternative is a two-line row,
/// which halves how many of your own promises you can see at once.
private struct ThreadRow: View {
    let arc: ThreadArc

    var body: some View {
        HStack(spacing: Space.snug) {
            IconView(arc.thread.kind.icon, size: Icon.threadKind)
                .foregroundStyle(arc.thread.kind.tint)

            Text(arc.thread.displayQuestion)
                .font(Chrome.body)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: Space.tight)

            Text(detail)
                .font(Chrome.small)
                .foregroundStyle(arc.state == .cooling ? AnyShapeStyle(Palette.caution) : AnyShapeStyle(.tertiary))
                .monospacedDigit()
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(arc.thread.displayQuestion). \(arc.state.title). \(accessibleDetail)")
    }

    /// One number, and only when there is something to say.
    ///
    /// The state is already the group header this row is sitting under, so repeating
    /// it per row is the same fact twice. What the header cannot say is *how long*,
    /// and that is the number a novelist is scanning this list for: the count of
    /// written scenes the reader has carried this question through since anything
    /// last touched it. A thread that is moving says nothing at all.
    private var detail: String {
        switch arc.state {
        case .unopened, .landed, .abandoned: ""
        case .open, .cooling:
            arc.scenesSinceProgress == 0 ? "" : "\(arc.scenesSinceProgress)"
        }
    }

    private var accessibleDetail: String {
        switch arc.state {
        case .unopened: "No scene asks it yet"
        case .landed: "Landed after \(arc.beats.count) scenes"
        case .abandoned: "Never answered, on purpose"
        case .open, .cooling:
            arc.scenesSinceProgress == 0
                ? "Still open"
                : "Quiet for \(arc.scenesSinceProgress) scene\(arc.scenesSinceProgress == 1 ? "" : "s")"
        }
    }
}

// MARK: - Canvas

struct ThreadCanvas: View {
    @EnvironmentObject private var workspace: WorkspaceModel

    var body: some View {
        if let thread = workspace.selectedThread, let arc = workspace.arc(for: thread.id) {
            VStack(spacing: 0) {
                ThreadStrip(thread: thread, arc: arc)

                ScrollView {
                    VStack(alignment: .leading, spacing: Space.section) {
                        QuestionBlock(thread: thread, arc: arc)
                        ArcBlock(arc: arc)
                        AnswerBlock(thread: thread, arc: arc)
                    }
                    .frame(maxWidth: Metrics.canvasWidth, alignment: .leading)
                    .padding(.horizontal, Space.page)
                    .padding(.top, Space.section)
                    .padding(.bottom, Space.page * 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
        } else {
            EmptyStateView(
                symbol: "questionmark.diamond",
                title: "No thread selected",
                message: "Choose a question on the left, or open a new one.",
                actionTitle: "Open a Thread",
                action: { workspace.createThread() }
            )
        }
    }
}

/// Kind, state, and the one decision available: stop counting.
private struct ThreadStrip: View {
    let thread: StoryThread
    let arc: ThreadArc
    @EnvironmentObject private var workspace: WorkspaceModel

    var body: some View {
        Strip {
            Menu {
                ForEach(ThreadKind.allCases, id: \.self) { kind in
                    Button {
                        workspace.updateThread(thread.id, kind: kind)
                    } label: {
                        Label { Text(kind.title) } icon: { kind.glyph.menuImage() }
                    }
                }
            } label: {
                Label { Text(thread.kind.title) } icon: { thread.kind.glyph.menuImage() }
                    .font(Chrome.small)
                    .foregroundStyle(thread.kind.tint)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Text("·")
                .foregroundStyle(.quaternary)

            Label(arc.state.title, systemImage: arc.state.symbolName)
                .font(Chrome.small)
                .foregroundStyle(arc.state.tint)

            Spacer(minLength: Space.small)

            if arc.state == .abandoned {
                Button("Owe It Again") { workspace.setThreadAbandoned(thread.id, false) }
                    .buttonStyle(.link)
                    .font(Chrome.small)
            } else if arc.isOwed {
                Button("Leave Open on Purpose") { workspace.setThreadAbandoned(thread.id, true) }
                    .buttonStyle(.link)
                    .font(Chrome.small)
                    .help("Some questions are meant to stay open. StoryLoom will stop counting.")
            }
        }
    }
}

/// The question, and only the question. It is set in a serif because it is prose:
/// it is the sentence in the reader's head, and it should look like one.
private struct QuestionBlock: View {
    let thread: StoryThread
    let arc: ThreadArc
    @EnvironmentObject private var workspace: WorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: Space.snug) {
            QuietField(
                placeholder: thread.kind.prompt,
                text: Binding(
                    get: { workspace.selectedThread?.question ?? "" },
                    set: { workspace.updateThread(thread.id, question: $0) }
                ),
                font: .system(size: 24, design: .serif)
            )

            if arc.state == .cooling {
                Label(
                    "\(arc.scenesSinceProgress) scenes and \(arc.wordsSinceProgress.formatted()) words have passed since anything moved this.",
                    systemImage: "clock.badge.exclamationmark"
                )
                .font(Chrome.meta)
                .foregroundStyle(Palette.caution)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Promise, progress, payoff — the shape of every thread that works, drawn in
/// manuscript order because that is the order the reader gets it in.
private struct ArcBlock: View {
    let arc: ThreadArc

    var body: some View {
        Block("The arc") {
            VStack(alignment: .leading, spacing: 0) {
                if arc.beats.isEmpty {
                    Text("No scene touches this yet. Open a scene and link it in the inspector.")
                        .font(Chrome.text)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, Space.snug)
                } else {
                    ForEach(Array(arc.beats.enumerated()), id: \.element.id) { position, beat in
                        BeatRow(
                            beat: beat,
                            isFirst: position == 0,
                            isLast: position == arc.beats.count - 1 && !arc.isOwed
                        )
                    }
                }

                if arc.isOwed, !arc.beats.isEmpty {
                    OwedRow()
                }
            }
        }
    }
}

private struct BeatRow: View {
    let beat: ThreadBeat
    let isFirst: Bool
    let isLast: Bool
    @EnvironmentObject private var workspace: WorkspaceModel

    var body: some View {
        HStack(alignment: .top, spacing: Space.small) {
            ThreadLine(
                symbol: beat.role.symbolName,
                tint: AnyShapeStyle(beat.role == .lands ? Palette.confirmed : Color.secondary),
                isFirst: isFirst,
                isLast: isLast
            )

            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: Space.small) {
                    Button {
                        workspace.navigate(to: .document(beat.documentID, nil))
                    } label: {
                        Text(workspace.documentTitle(beat.documentID) ?? "A deleted scene")
                            .font(Chrome.textStrong)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: Space.medium)

                    Text(beat.role.arcTitle)
                        .font(Chrome.meta)
                        .foregroundStyle(.tertiary)
                }

                if let turn = workspace.project.document(beat.documentID)?.turn, !turn.isEmpty {
                    Text(turn)
                        .font(Chrome.meta)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, isLast ? 0 : Space.wide)
        }
    }
}

/// The end of the line, when the line has no end. This is the whole product in one
/// row: the reader is still holding this, and nothing in the manuscript gives it back.
private struct OwedRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: Space.small) {
            ThreadLine(symbol: "circle.dotted", tint: AnyShapeStyle(.tertiary), isFirst: false, isLast: true)

            HStack(alignment: .firstTextBaseline, spacing: Space.small) {
                Text("No scene lands this. The reader is still holding it.")
                    .font(Chrome.text)
                    .foregroundStyle(.secondary)
                Spacer(minLength: Space.medium)
                Text(ThreadRole.lands.arcTitle)
                    .font(Chrome.meta)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

/// The thread itself, drawn: a line down the page through every scene that carries
/// it. The only ornament in the application, and it earns its place by being the
/// thing the room is named after.
private struct ThreadLine: View {
    let symbol: String
    let tint: AnyShapeStyle
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isFirst ? .clear : Palette.thread)
                .frame(width: 1, height: 5)
            Image(systemName: symbol)
                .font(.system(size: Icon.inline, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 12, height: 12)
            Rectangle()
                .fill(isLast ? .clear : Palette.thread)
                .frame(width: 1)
                .frame(maxHeight: .infinity)
        }
        .frame(width: 12)
    }
}

/// The answer. The single most spoiler-dense field in the project, which is why it
/// says so out loud and why the export boundary knows its name.
private struct AnswerBlock: View {
    let thread: StoryThread
    let arc: ThreadArc
    @EnvironmentObject private var workspace: WorkspaceModel

    var body: some View {
        Block("The answer", caption: caption) {
            QuietText(
                placeholder: "What is actually going on — and what the reader will feel when they find out.",
                text: Binding(
                    get: { workspace.selectedThread?.answer ?? "" },
                    set: { workspace.updateThread(thread.id, answer: $0) }
                ),
                size: 13,
                minimumLines: 3
            )
        }
    }

    private var caption: String {
        arc.landedAt == nil ? "Never exported. Write it down while you still know it." : "Never exported."
    }
}

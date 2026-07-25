//
//  StoryViews.swift
//  StoryLoom
//
//  Story records, chronology, and notes. Every field here is optional — "a
//  character can exist as a name and one cited appearance" (14-Character-System) —
//  and nothing on these surfaces is inferred. What StoryLoom shows as evidence, it
//  can point at in the prose.
//

import SwiftUI

// MARK: - Story: list

struct EntityList: View {
    @EnvironmentObject private var workspace: WorkspaceModel
    @State private var filter = ""

    private var grouped: [(kind: EntityKind, entities: [StoryEntity])] {
        let matching = workspace.project.story.entities.filter { entity in
            filter.isEmpty
                || entity.name.localizedCaseInsensitiveContains(filter)
                || entity.summary.localizedCaseInsensitiveContains(filter)
                || entity.aliases.contains { $0.localizedCaseInsensitiveContains(filter) }
        }
        return EntityKind.allCases.compactMap { kind in
            let entities = matching.filter { $0.kind == kind }
            return entities.isEmpty ? nil : (kind, entities)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigatorBar(filter: $filter, prompt: "Filter records") {
                Menu {
                    ForEach(EntityKind.allCases, id: \.self) { kind in
                        Button("New \(kind.title)") { workspace.createEntity(kind: kind) }
                    }
                } label: {
                    GlyphIcon(glyph: .plus, size: Icon.control)
                }
                .help("New record")
            }

            if grouped.isEmpty {
                EmptyStateView(
                    glyph: .family,
                    title: filter.isEmpty ? "No records yet" : "Nothing matches",
                    message: filter.isEmpty
                        ? "Records are optional. Make one when naming something explicitly would save you work — never before."
                        : "Try another name.",
                    actionTitle: filter.isEmpty ? "New Character" : nil,
                    action: filter.isEmpty ? { workspace.createEntity(kind: .character) } : nil
                )
            } else {
                List(selection: $workspace.selectedEntityID) {
                    ForEach(grouped, id: \.kind) { group in
                        Section {
                            ForEach(group.entities) { entity in
                                EntityRow(entity: entity, mentions: workspace.index.mentions(of: entity.id).count)
                                    .tag(entity.id)
                                    .contextMenu {
                                        Button("Delete", role: .destructive) { workspace.deleteEntity(entity.id) }
                                    }
                            }
                        } header: {
                            GroupHeader(title: group.kind.plural, count: group.entities.count)
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
}

/// A name and how many times it is actually in the book. The second number is the
/// only one worth a column: a character with a dossier and no mentions is a
/// character who does not exist yet, and that is worth seeing at a glance.
private struct EntityRow: View {
    let entity: StoryEntity
    let mentions: Int

    var body: some View {
        HStack(spacing: Space.snug) {
            GlyphIcon(glyph: entity.kind.glyph, size: Icon.inline)
                .font(.system(size: Icon.inline))
                .foregroundStyle(entity.kind.tint)
                .frame(width: 13)

            Text(entity.displayName)
                .font(Chrome.body)
                .lineLimit(1)

            Spacer(minLength: Space.tight)

            Text(mentions == 0 ? "—" : mentions.formatted())
                .font(Chrome.small)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(mentions == 0
            ? "\(entity.displayName), not yet written"
            : "\(entity.displayName), \(mentions) mention\(mentions == 1 ? "" : "s")")
    }
}

// MARK: - Story: dossier

struct EntityDossier: View {
    @EnvironmentObject private var workspace: WorkspaceModel

    var body: some View {
        Group {
            if let entity = workspace.selectedEntity {
                VStack(spacing: 0) {
                    strip(entity)

                    ScrollView {
                        VStack(alignment: .leading, spacing: Space.section) {
                            identity(entity)
                            facts(entity)
                            relationships(entity)
                            appearances(entity)
                            events(entity)
                        }
                        .frame(maxWidth: Metrics.canvasWidth, alignment: .leading)
                        .padding(.horizontal, Space.page)
                        .padding(.top, Space.section)
                        .padding(.bottom, Space.page * 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                EmptyStateView(
                    glyph: .family,
                    title: "No record selected",
                    message: "Choose a person, place, object, or idea to see where it appears."
                )
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func strip(_ entity: StoryEntity) -> some View {
        Strip {
            Menu {
                ForEach(EntityKind.allCases, id: \.self) { kind in
                    Button(kind.title) { workspace.updateEntity(entity.id, kind: kind) }
                }
            } label: {
                Label { Text(entity.kind.title) } icon: { entity.kind.glyph.menuImage(size: Icon.control) }
                    .font(Chrome.small)
                    .foregroundStyle(entity.kind.tint)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer(minLength: Space.small)

            Button("Delete Record", role: .destructive) { workspace.deleteEntity(entity.id) }
                .buttonStyle(.link)
                .font(Chrome.small)
        }
    }

    /// Who this is, in one name and one paragraph.
    private func identity(_ entity: StoryEntity) -> some View {
        VStack(alignment: .leading, spacing: Space.regular) {
            QuietField(
                placeholder: "Name",
                text: Binding(
                    get: { entity.name },
                    set: { workspace.updateEntity(entity.id, name: $0) }
                ),
                font: Chrome.display
            )

            QuietText(
                placeholder: "What matters about them, in your words.",
                text: Binding(
                    get: { entity.summary },
                    set: { workspace.updateEntity(entity.id, summary: $0) }
                ),
                size: 14
            )
        }
    }

    /// What to call them, side by side. These were three stacked rows in a
    /// sixty-point label column, which spent a third of the page on the word "Role"
    /// and made "Also called" wrap onto two lines to say one word.
    private func facts(_ entity: StoryEntity) -> some View {
        Facts {
            Fact("Also called") {
                QuietField(
                    placeholder: "comma, separated",
                    text: Binding(
                        get: { entity.aliases.joined(separator: ", ") },
                        set: { value in
                            workspace.updateEntity(entity.id, aliases: value.split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespaces) }
                                .filter { !$0.isEmpty })
                        }
                    ),
                    font: Chrome.text
                )
            }

            if entity.kind == .character {
                Fact("Pronouns") {
                    QuietField(
                        placeholder: "as you write them",
                        text: Binding(
                            get: { entity.pronouns },
                            set: { workspace.updateEntity(entity.id, pronouns: $0) }
                        ),
                        font: Chrome.text
                    )
                }
            }

            Fact("Role") {
                QuietField(
                    placeholder: "optional",
                    text: Binding(
                        get: { entity.role },
                        set: { workspace.updateEntity(entity.id, role: $0) }
                    ),
                    font: Chrome.text
                )
            }
        }
    }

    private func relationships(_ entity: StoryEntity) -> some View {
        Block("Relationships", caption: "confirmed by you, never inferred") {
            let links = workspace.relationships(for: entity)
            let others = workspace.project.story.entities.filter { $0.id != entity.id }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(links) { relationship in
                    RelationshipRow(relationship: relationship, subject: entity)
                }

                Menu {
                    ForEach(others) { target in
                        Button(target.displayName) { workspace.createRelationship(from: entity, to: target) }
                    }
                } label: {
                    Label { Text("Add relationship") } icon: { Glyph.plus.menuImage(size: Icon.control) }
                        .font(Chrome.meta)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .disabled(others.isEmpty)
                .padding(.top, links.isEmpty ? 0 : Space.regular)
            }
        }
    }

    /// Evidence. Every row here exists because the name is literally in the prose,
    /// and clicking it lands on the sentence.
    private func appearances(_ entity: StoryEntity) -> some View {
        Block("Appearances", caption: "where the name occurs") {
            let mentions = workspace.index.mentions(of: entity.id)
            if mentions.isEmpty {
                Text("Not written yet. That is not a problem to solve — it is a scene to write.")
                    .font(Chrome.text)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: Space.tight) {
                    ForEach(grouped(mentions), id: \.documentID) { group in
                        AppearanceRow(group: group)
                    }
                }
            }
        }
    }

    private func grouped(_ mentions: [Mention]) -> [MentionGroup] {
        let byDocument = Dictionary(grouping: mentions, by: \.documentID)
        return workspace.project.documents.compactMap { document in
            guard let hits = byDocument[document.id], let first = hits.first else { return nil }
            let (excerpt, highlight) = StoryBrain.excerpt(around: first.range, in: document.text)
            return MentionGroup(
                documentID: document.id,
                title: document.displayTitle,
                chapter: document.chapterTitle,
                count: hits.count,
                excerpt: excerpt,
                highlight: highlight,
                range: first.range
            )
        }
    }

    private func events(_ entity: StoryEntity) -> some View {
        Block("Events") {
            let participating = workspace.project.story.events.filter { $0.participantIDs.contains(entity.id) }
            if participating.isEmpty {
                Text("Not in any event.")
                    .font(Chrome.text)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: Space.tight) {
                    ForEach(participating) { event in
                        HoverRow(padding: Space.snug, action: { workspace.navigate(to: .event(event.id)) }) {
                            HStack(spacing: Space.small) {
                                GlyphIcon(glyph: event.certainty.glyph, size: Icon.inline)
                                    .font(.system(size: Icon.inline))
                                    .foregroundStyle(event.certainty.tint)
                                    .frame(width: 14)
                                Text(event.displayTitle)
                                    .font(Chrome.text)
                                Spacer(minLength: Space.medium)
                                Text(event.chronologyLabel)
                                    .font(Chrome.meta)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct MentionGroup {
    let documentID: UUID
    let title: String
    let chapter: String
    let count: Int
    let excerpt: String
    let highlight: Range<String.Index>?
    let range: NSRange
}

private struct AppearanceRow: View {
    let group: MentionGroup
    @EnvironmentObject private var workspace: WorkspaceModel

    var body: some View {
        HoverRow(padding: Space.snug, action: {
            workspace.navigate(to: .document(group.documentID, group.range))
        }) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Space.small) {
                    Text(group.title)
                        .font(Chrome.textStrong)
                    Text(group.chapter)
                        .font(Chrome.meta)
                        .foregroundStyle(.tertiary)
                    Spacer(minLength: Space.medium)
                    Text("\(group.count)×")
                        .font(Chrome.meta)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                HighlightedText(
                    text: group.excerpt,
                    ranges: group.highlight.map { [$0] } ?? [],
                    font: .system(size: 12, design: .serif),
                    lineLimit: 2
                )
            }
        }
    }
}

/// A relationship, on two lines rather than four things elbowing each other on one.
///
/// It used to be a truncated picker, a name, a free-text field and a delete button
/// all fighting for the same row — which read as a pile of controls rather than a
/// sentence about two people. Now the claim is the first line and the author's own
/// words are the second, indented under the name they are about.
private struct RelationshipRow: View {
    let relationship: StoryRelationship
    let subject: StoryEntity
    @EnvironmentObject private var workspace: WorkspaceModel

    private let kindWidth: CGFloat = 132

    var body: some View {
        VStack(alignment: .leading, spacing: Space.tight) {
            HStack(spacing: Space.medium) {
                Picker("", selection: Binding(
                    get: { relationship.kind },
                    set: { workspace.updateRelationship(relationship.id, kind: $0) }
                )) {
                    ForEach(RelationshipKind.allCases, id: \.self) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .labelsHidden()
                .controlSize(.small)
                .frame(width: kindWidth)

                Button {
                    workspace.navigate(to: .entity(relationship.other(than: subject.id)))
                } label: {
                    Text(workspace.entityName(relationship.other(than: subject.id)))
                        .font(Chrome.textStrong)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)

                Spacer(minLength: Space.medium)

                Button {
                    workspace.deleteRelationship(relationship.id)
                } label: {
                    GlyphIcon(glyph: .remove, size: Icon.control)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .help("Remove relationship")
            }

            QuietField(
                placeholder: "in your words — “hides the ledger from”",
                text: Binding(
                    get: { relationship.label },
                    set: { workspace.updateRelationship(relationship.id, label: $0) }
                ),
                font: Chrome.meta
            )
            .foregroundStyle(.secondary)
            .padding(.leading, kindWidth + Space.medium)
        }
        .padding(.vertical, Space.medium)
        .hairlineBorder(.bottom)
    }
}

// MARK: - Timeline: list

struct EventList: View {
    @EnvironmentObject private var workspace: WorkspaceModel
    @State private var filter = ""

    private var events: [StoryEvent] {
        guard !filter.isEmpty else { return workspace.project.story.events }
        return workspace.project.story.events.filter {
            $0.title.localizedCaseInsensitiveContains(filter)
                || $0.chronologyLabel.localizedCaseInsensitiveContains(filter)
                || $0.summary.localizedCaseInsensitiveContains(filter)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigatorBar(filter: $filter, prompt: "Filter events") {
                Button {
                    workspace.createEvent()
                } label: {
                    GlyphIcon(glyph: .plus, size: Icon.control)
                }
                .help("New event")
            }

            if events.isEmpty {
                EmptyStateView(
                    glyph: .chronology,
                    title: workspace.project.story.events.isEmpty ? "No events yet" : "Nothing matches",
                    message: workspace.project.story.events.isEmpty
                        ? "Add events when chronology starts to matter. Dates are never required — “the night before” is a perfectly good time."
                        : "Try another word, or clear the filter.",
                    actionTitle: workspace.project.story.events.isEmpty ? "New Event" : nil,
                    action: workspace.project.story.events.isEmpty ? { workspace.createEvent() } : nil
                )
            } else {
                List(selection: $workspace.selectedEventID) {
                    ForEach(events) { event in
                        EventRow(event: event)
                            .tag(event.id)
                            .contextMenu {
                                Button("Move Earlier") { workspace.moveEvent(event.id, by: -1) }
                                Button("Move Later") { workspace.moveEvent(event.id, by: 1) }
                                Divider()
                                Button("Delete", role: .destructive) { workspace.deleteEvent(event.id) }
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
}

/// The list is the chronology, so the list does not also need to draw a line down
/// its own side saying so. The glyph is kept because it carries something the order
/// cannot: how sure the author is that this happened when they think it did.
///
/// The *when* is shown only when it fits whole. Two texts sharing one row of a
/// navigator will always fight, and every way of settling the fight by priority
/// loses: split them evenly and every event in the book reads "Alder writes Mara…"
/// beside "Years before, in…"; give the title priority and the date is crushed to a
/// single stray character. So the row asks whether both fit, and if they do not, the
/// date simply is not there — which costs nothing, because it is two clicks away and
/// the list is already in the order it describes.
private struct EventRow: View {
    let event: StoryEvent

    var body: some View {
        HStack(spacing: Space.snug) {
            GlyphIcon(glyph: event.certainty.glyph, size: Icon.inline)
                .font(.system(size: Icon.inline))
                .foregroundStyle(event.certainty.tint)
                .frame(width: 11)

            ViewThatFits(in: .horizontal) {
                titled
                title
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.displayTitle), \(event.certainty.title)")
    }

    private var titled: some View {
        HStack(spacing: Space.small) {
            title
                .fixedSize()
            Spacer(minLength: Space.small)
            Text(event.chronologyLabel)
                .font(Chrome.small)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .fixedSize()
        }
    }

    private var title: some View {
        Text(event.displayTitle)
            .font(Chrome.body)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Timeline: detail

struct EventDetail: View {
    @EnvironmentObject private var workspace: WorkspaceModel

    var body: some View {
        Group {
            if let event = workspace.selectedEvent {
                VStack(spacing: 0) {
                    Strip {
                        Picker("", selection: Binding(
                            get: { event.certainty },
                            set: { workspace.updateEvent(event.id, certainty: $0) }
                        )) {
                            ForEach(EventCertainty.allCases, id: \.self) { certainty in
                                Text(certainty.title).tag(certainty)
                            }
                        }
                        .labelsHidden()
                        .controlSize(.small)
                        .fixedSize()

                        Text(event.certainty.detail)
                            .font(Chrome.small)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)

                        Spacer(minLength: Space.small)

                        Button("Delete Event", role: .destructive) { workspace.deleteEvent(event.id) }
                            .buttonStyle(.link)
                            .font(Chrome.small)
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: Space.section) {
                            VStack(alignment: .leading, spacing: Space.regular) {
                                QuietField(
                                    placeholder: "What happens",
                                    text: Binding(
                                        get: { event.title },
                                        set: { workspace.updateEvent(event.id, title: $0) }
                                    ),
                                    font: Chrome.display
                                )

                                QuietText(
                                    placeholder: "What happens, and why it matters.",
                                    text: Binding(
                                        get: { event.summary },
                                        set: { workspace.updateEvent(event.id, summary: $0) }
                                    ),
                                    size: 14
                                )
                            }

                            Facts {
                                Fact("When") {
                                    QuietField(
                                        placeholder: "“Night one, before high tide”",
                                        text: Binding(
                                            get: { event.chronologyLabel },
                                            set: { workspace.updateEvent(event.id, chronologyLabel: $0) }
                                        ),
                                        font: Chrome.text
                                    )
                                }

                                Fact("Where the reader meets it") {
                                    Picker("", selection: Binding(
                                        get: { event.narrativeDocumentID },
                                        set: { workspace.updateEvent(event.id, narrativeDocumentID: .some($0)) }
                                    )) {
                                        Text("Not shown on the page").tag(UUID?.none)
                                        ForEach(workspace.project.scenes) { document in
                                            Text("\(document.chapterTitle) — \(document.displayTitle)")
                                                .tag(UUID?.some(document.id))
                                        }
                                    }
                                    .labelsHidden()
                                    .controlSize(.small)
                                    .help("Narrative placement is a separate fact from chronology.")
                                }
                            }

                            Block("Who is there") {
                                FlowLayout(spacing: Space.snug, lineSpacing: Space.snug) {
                                    ForEach(workspace.project.story.entities) { entity in
                                        let isParticipant = event.participantIDs.contains(entity.id)
                                        Chip(
                                            text: entity.displayName,
                                            icon: isParticipant ? .glyph(.saved) : entity.kind.icon,
                                            tint: isParticipant ? entity.kind.tint : .secondary
                                        ) {
                                            workspace.toggleParticipant(entity.id, in: event.id)
                                        }
                                        .opacity(isParticipant ? 1 : 0.5)
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
            } else {
                EmptyStateView(
                    glyph: .chronology,
                    title: "No event selected",
                    message: "Chronology lives here, separately from the order you reveal it in."
                )
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - Notes

struct NoteList: View {
    @EnvironmentObject private var workspace: WorkspaceModel
    @State private var filter = ""

    private var notes: [StoryNote] {
        guard !filter.isEmpty else { return workspace.project.story.notes }
        return workspace.project.story.notes.filter {
            $0.title.localizedCaseInsensitiveContains(filter)
                || $0.body.localizedCaseInsensitiveContains(filter)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigatorBar(filter: $filter, prompt: "Filter notes") {
                Button {
                    workspace.createNote()
                } label: {
                    GlyphIcon(glyph: .plus, size: Icon.control)
                }
                .help("New note")
            }

            if notes.isEmpty {
                EmptyStateView(
                    glyph: .note,
                    title: workspace.project.story.notes.isEmpty ? "No notes" : "Nothing matches",
                    message: workspace.project.story.notes.isEmpty
                        ? "For the questions you are protecting, the voice you are chasing, the thing you must not explain."
                        : "Try another word, or clear the filter.",
                    actionTitle: workspace.project.story.notes.isEmpty ? "New Note" : nil,
                    action: workspace.project.story.notes.isEmpty ? { workspace.createNote() } : nil
                )
            } else {
                List(selection: $workspace.selectedNoteID) {
                    ForEach(notes) { note in
                        HStack(spacing: Space.snug) {
                            Text(note.displayTitle)
                                .font(Chrome.body)
                                .lineLimit(1)
                            Spacer(minLength: Space.tight)
                            Text(note.updatedAt, style: .relative)
                                .font(Chrome.small)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        .tag(note.id)
                        .contextMenu {
                            Button("Delete", role: .destructive) { workspace.deleteNote(note.id) }
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
}

struct NoteEditor: View {
    @EnvironmentObject private var workspace: WorkspaceModel

    var body: some View {
        Group {
            if let note = workspace.selectedNote {
                VStack(alignment: .leading, spacing: 0) {
                    Strip {
                        QuietField(
                            placeholder: "Note title",
                            text: Binding(
                                get: { note.title },
                                set: { workspace.updateNote(note.id, title: $0) }
                            ),
                            font: Chrome.strong
                        )

                        Spacer(minLength: Space.small)

                        Button("Delete", role: .destructive) { workspace.deleteNote(note.id) }
                            .buttonStyle(.link)
                            .font(Chrome.small)
                    }

                    // A note is prose, so it gets a measure. Left the full width of the
                    // column, a line of it would run to a hundred and eighty characters.
                    TextEditor(text: Binding(
                        get: { note.body },
                        set: { workspace.updateNote(note.id, body: $0) }
                    ))
                    .font(.system(size: 14, design: .serif))
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: Metrics.readingWidth, alignment: .leading)
                    .padding(.horizontal, Space.page)
                    .padding(.vertical, Space.wide)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                EmptyStateView(
                    glyph: .note,
                    title: "No note selected",
                    message: "Notes stay with the project and never reach an export."
                )
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

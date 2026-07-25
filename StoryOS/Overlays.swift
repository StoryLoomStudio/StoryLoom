//
//  Overlays.swift
//  StoryLoom
//
//  The command palette, project search, and the export sheet.
//
//  The palette is the primary keyboard interface (12-UI): it navigates to any
//  scene, record, event, or note by name, and runs the actions that matter. It is
//  not a second navigation model — everything it does is reachable another way.
//

import SwiftUI

// MARK: - Command palette

struct CommandPalette: View {
    @Binding var sheet: WorkspaceSheet?
    @EnvironmentObject private var workspace: WorkspaceModel
    @EnvironmentObject private var settings: AppSettings

    @State private var query = ""
    @State private var highlighted = 0
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Space.small) {
                Image(systemName: "command")
                    .font(.system(size: Icon.control))
                    .foregroundStyle(.tertiary)

                TextField("Search everything, or run a command", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($focused)
                    .onSubmit(run)
                    .onChange(of: query) { _, _ in highlighted = 0 }

                KeyCap(keys: "esc")
            }
            .padding(.horizontal, Space.regular)
            .frame(height: 38)

            Divider()

            if entries.isEmpty {
                EmptyStateView(
                    symbol: "magnifyingglass",
                    title: "Nothing matches",
                    message: "Try a name, a line of prose, or in:dialogue to search speech only."
                )
                .frame(height: 240)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { position, entry in
                                PaletteRow(entry: entry, isHighlighted: position == highlighted)
                                    .id(position)
                                    .onTapGesture { execute(entry) }
                                    .onHover { if $0 { highlighted = position } }
                            }
                        }
                        .padding(.horizontal, Space.tight)
                        .padding(.vertical, Space.tight)
                    }
                    .onChange(of: highlighted) { _, value in
                        withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(value, anchor: .center) }
                    }
                }
            }
        }
        .frame(width: 560, height: 400)
        .background(KeyMonitor(onMove: move, onRun: run, onCancel: { sheet = nil }))
        .task { focused = true }
    }

    // MARK: Entries

    private var entries: [PaletteEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        var results: [PaletteEntry] = []

        // Actions first when the query is empty: the palette's job at rest is to
        // remind you what it can do.
        //
        // Title and keywords are scored separately, and the title is worth double.
        // Matching them as one string lets a query scattered across the keywords
        // outrank a real title match — "ti" would offer New Scene ahead of Go to
        // Timeline, which is the opposite of what the author asked for.
        for action in actions {
            guard !trimmed.isEmpty else {
                results.append(PaletteEntry(action: action, score: 6))
                continue
            }
            let title = Fuzzy.score(action.title, query: trimmed).map { $0 * 2 }
            let keywords = Fuzzy.score(action.keywords, query: trimmed)
            guard let best = [title, keywords].compactMap({ $0 }).max() else { continue }
            results.append(PaletteEntry(action: action, score: best + 6))
        }

        guard !trimmed.isEmpty else { return results }

        /// Subjects already offered by name, so the content pass below does not
        /// offer them a second time.
        var named: Set<UUID> = []

        for document in workspace.project.documents {
            guard let score = Fuzzy.score(document.displayTitle, query: trimmed) else { continue }
            named.insert(document.id)
            results.append(PaletteEntry(
                id: "doc-\(document.id)",
                title: document.displayTitle,
                subtitle: document.chapterTitle,
                icon: .system(document.kind.symbolName),
                tint: document.kind.tint,
                score: score + 4,
                run: { workspace.navigate(to: .document(document.id, nil)) }
            ))
        }
        for entity in workspace.project.story.entities {
            guard let score = Fuzzy.score(entity.displayName, query: trimmed) else { continue }
            named.insert(entity.id)
            results.append(PaletteEntry(
                id: "entity-\(entity.id)",
                title: entity.displayName,
                subtitle: entity.kind.title,
                icon: .system(entity.kind.symbolName),
                tint: entity.kind.tint,
                score: score + 2,
                run: { workspace.navigate(to: .entity(entity.id)) }
            ))
        }
        for event in workspace.project.story.events {
            guard let score = Fuzzy.score(event.displayTitle, query: trimmed) else { continue }
            named.insert(event.id)
            results.append(PaletteEntry(
                id: "event-\(event.id)",
                title: event.displayTitle,
                subtitle: event.chronologyLabel.isEmpty ? "Event" : event.chronologyLabel,
                icon: .system("calendar"),
                tint: event.certainty.tint,
                score: score,
                run: { workspace.navigate(to: .event(event.id)) }
            ))
        }
        for note in workspace.project.story.notes {
            guard let score = Fuzzy.score(note.displayTitle, query: trimmed) else { continue }
            named.insert(note.id)
            results.append(PaletteEntry(
                id: "note-\(note.id)",
                title: note.displayTitle,
                subtitle: "Note",
                icon: .system("note.text"),
                tint: .orange,
                score: score,
                run: { workspace.navigate(to: .note(note.id)) }
            ))
        }

        // Everything above matches *names*. This matches the book.
        //
        // The palette used to stop at titles, which meant the fastest way into
        // the application could not find a line of prose — the author had to know
        // that ⌘K searched one thing and ⇧⌘F another, and pick correctly before
        // typing. One surface, and the full-text engine answers the same query:
        // scene bodies, the private craft fields, threads, records,
        // relationships, events, notes, and `in:dialogue` for speech alone.
        //
        // A single letter is not a full-text query — it would return the whole
        // book ranked by nothing — so content joins in at two.
        if trimmed.count >= 2 {
            for hit in SearchEngine.search(trimmed, in: workspace.project, limit: 30) {
                // Deduplicated on the subject, not the row id. A scene called
                // "The Ledger" that also says "ledger" in its prose matches twice
                // — once by name above, once by body here — and the two rows
                // carry different ids for the same scene.
                guard !named.contains(hit.destination.subjectID) else { continue }
                results.append(PaletteEntry(
                    id: "hit-\(hit.id)",
                    title: hit.title,
                    // The matching line, not the category: seeing the sentence is
                    // most of why the author opened the palette at all.
                    subtitle: hit.snippet.isEmpty ? hit.category : hit.snippet,
                    icon: hit.icon,
                    tint: hit.tint,
                    // Normalised well below a name match. A scene called "The
                    // Ledger" must outrank four hundred scenes that mention one.
                    score: min(hit.score / 20, 3),
                    run: { workspace.navigate(to: hit.destination) }
                ))
            }
        }

        return Array(results.sorted { $0.score > $1.score }.prefix(40))
    }

    private var actions: [PaletteAction] {
        [
            PaletteAction("New Scene", "create insert write", .system("square.and.pencil"), "⇧⌘N") { workspace.createScene() },
            PaletteAction("Find in Project", "search text", .system("magnifyingglass"), "⇧⌘F") { sheet = .search },
            PaletteAction("Save Project", "write persist", .system("arrow.down.doc"), "⌘S") { workspace.save() },
            PaletteAction("Save a Point", "snapshot history recover", .system("clock.badge.checkmark"), nil) { workspace.createSnapshot() },
            PaletteAction("Export…", "docx pdf markdown", .system("square.and.arrow.up"), "⇧⌘E") { sheet = .export },
            PaletteAction(
                workspace.isFocusMode ? "Leave Focus" : "Enter Focus",
                "distraction free zen",
                .system("arrow.up.left.and.arrow.down.right"),
                "⌥⌘F"
            ) { workspace.isFocusMode.toggle() },
            PaletteAction(
                settings.typewriter ? "Turn Off Typewriter" : "Typewriter Scrolling",
                "centre line",
                .system("text.aligncenter"),
                nil
            ) { settings.typewriter.toggle() },
            PaletteAction(
                settings.focusDepth == .off ? "Dim Everything But This Paragraph" : "Stop Dimming",
                "focus concentrate",
                .system("scope"),
                nil
            ) { settings.focusDepth = settings.focusDepth == .off ? .paragraph : .off },
            PaletteAction(
                workspace.isInspectorVisible ? "Hide Inspector" : "Show Inspector",
                "context sidebar",
                .system("sidebar.trailing"),
                "⌥⌘I"
            ) { workspace.isInspectorVisible.toggle() },
        ]
        // Derived, not transcribed. The palette used to keep its own copy of this
        // list — with its own hand-written shortcuts — and the moment a room was
        // added, every shortcut below it silently pointed at the wrong room.
        + LibraryItem.navigable.enumerated().map { position, item in
            PaletteAction(
                "Go to \(item.title)",
                item.question,
                item.icon,
                "⌘\(position + 1)"
            ) { workspace.library = item }
        }
    }

    // MARK: Behaviour

    private func move(_ delta: Int) {
        guard !entries.isEmpty else { return }
        highlighted = min(max(0, highlighted + delta), entries.count - 1)
    }

    private func run() {
        guard entries.indices.contains(highlighted) else { return }
        execute(entries[highlighted])
    }

    private func execute(_ entry: PaletteEntry) {
        sheet = nil
        // Let the sheet finish dismissing before a command opens another one.
        DispatchQueue.main.async { entry.run() }
    }
}

private struct PaletteAction {
    let title: String
    let keywords: String
    let icon: IconSource
    let shortcut: String?
    let run: () -> Void

    init(_ title: String, _ keywords: String, _ icon: IconSource, _ shortcut: String?, run: @escaping () -> Void) {
        self.title = title
        self.keywords = keywords
        self.icon = icon
        self.shortcut = shortcut
        self.run = run
    }
}

private struct PaletteEntry: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: IconSource
    let tint: Color
    let shortcut: String?
    let score: Double
    let run: () -> Void

    init(
        id: String,
        title: String,
        subtitle: String,
        icon: IconSource,
        tint: Color,
        shortcut: String? = nil,
        score: Double,
        run: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.shortcut = shortcut
        self.score = score
        self.run = run
    }

    init(action: PaletteAction, score: Double) {
        self.init(
            id: "action-\(action.title)",
            title: action.title,
            subtitle: "Action",
            icon: action.icon,
            tint: .secondary,
            shortcut: action.shortcut,
            score: score,
            run: action.run
        )
    }
}

private struct PaletteRow: View {
    let entry: PaletteEntry
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: Space.small) {
            IconView(entry.icon, size: Icon.control)
                .foregroundStyle(entry.tint)
                .frame(width: 16)

            Text(entry.title)
                .font(Chrome.body)
                .lineLimit(1)

            Text(entry.subtitle)
                .font(Chrome.small)
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            Spacer(minLength: Space.small)

            if let shortcut = entry.shortcut {
                KeyCap(keys: shortcut)
            }
        }
        .padding(.horizontal, Space.small)
        .frame(height: 24)
        .background {
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .fill(isHighlighted ? Color.accentColor.opacity(0.16) : .clear)
        }
        .contentShape(Rectangle())
    }
}

/// Arrow keys and Return, without stealing them from the text field.
private struct KeyMonitor: NSViewRepresentable {
    let onMove: (Int) -> Void
    let onRun: () -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> NSView {
        context.coordinator.install(onMove: onMove, onRun: onRun, onCancel: onCancel)
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.install(onMove: onMove, onRun: onRun, onCancel: onCancel)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.remove()
    }

    @MainActor
    final class Coordinator {
        private var monitor: Any?

        func install(onMove: @escaping (Int) -> Void, onRun: @escaping () -> Void, onCancel: @escaping () -> Void) {
            remove()
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                switch event.keyCode {
                case 125: onMove(1); return nil    // down
                case 126: onMove(-1); return nil   // up
                case 36, 76: onRun(); return nil   // return, enter
                case 53: onCancel(); return nil    // escape
                default: return event
                }
            }
        }

        func remove() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}

// MARK: - Search

struct SearchPanel: View {
    @Binding var sheet: WorkspaceSheet?
    @EnvironmentObject private var workspace: WorkspaceModel

    @State private var query = ""
    @FocusState private var focused: Bool

    private var hits: [SearchHit] {
        workspace.search(query)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Space.small) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: Icon.control))
                    .foregroundStyle(.tertiary)

                TextField("Search the manuscript and the story", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($focused)

                if !hits.isEmpty {
                    Text("\(hits.count)")
                        .font(Chrome.small)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }

                Button { sheet = nil } label: { KeyCap(keys: "esc") }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    .help("Close")
            }
            .padding(.horizontal, Space.regular)
            .frame(height: 38)

            Divider()

            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                SearchHelp()
            } else if hits.isEmpty {
                EmptyStateView(
                    symbol: "magnifyingglass",
                    title: "No results",
                    message: "Nothing in the prose, the records, or the history matches that."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(hits) { hit in
                            HoverRow(action: { open(hit) }) {
                                SearchRow(hit: hit)
                            }
                        }
                    }
                    .padding(.horizontal, Space.tight)
                    .padding(.vertical, Space.tight)
                }
            }
        }
        .frame(width: 680, height: 480)
        .task { focused = true }
    }

    private func open(_ hit: SearchHit) {
        sheet = nil
        DispatchQueue.main.async { workspace.navigate(to: hit.destination) }
    }
}

private struct SearchRow: View {
    let hit: SearchHit

    var body: some View {
        HStack(alignment: .top, spacing: Space.small) {
            IconView(hit.icon, size: Icon.control)
                .foregroundStyle(hit.tint)
                .frame(width: 16)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: Space.snug) {
                    Text(hit.title)
                        .font(Chrome.strong)
                        .lineLimit(1)
                    Text(hit.category)
                        .font(Chrome.small)
                        .foregroundStyle(.tertiary)
                    Spacer(minLength: Space.small)
                    // The reason this ranked where it did. A ranking you cannot
                    // see is a ranking you cannot argue with (13-Search).
                    Text(hit.reason)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                HighlightedText(text: hit.snippet, ranges: hit.highlights, font: .system(size: 11, design: .serif))
            }
        }
        .padding(.vertical, 1)
    }
}

private struct SearchHelp: View {
    private let examples: [(String, String)] = [
        ("the tide turns", "words anywhere in the prose"),
        ("\"before high tide\"", "an exact phrase"),
        ("pov:mara status:draft", "scenes she narrates that are still drafts"),
        ("thread:lands", "the scenes that pay something off"),
        ("kind:location", "every place you have named")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.snug) {
            SectionLabel("Search can take")
                .padding(.bottom, Space.tight)

            ForEach(examples, id: \.0) { example in
                HStack(alignment: .firstTextBaseline, spacing: Space.small) {
                    Text(example.0)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, Space.snug)
                        .padding(.vertical, 1)
                        .background(Palette.subtleFill, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    Text(example.1)
                        .font(Chrome.small)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(Space.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Export

struct ExportPanel: View {
    @Binding var sheet: WorkspaceSheet?
    @EnvironmentObject private var workspace: WorkspaceModel
    @EnvironmentObject private var settings: AppSettings

    @State private var profile = ExportProfile()

    private var preview: ExportPreview {
        ExportService.preview(workspace.project, profile: profile)
    }

    var body: some View {
        VStack(spacing: 0) {
            Strip {
                Text("Export")
                    .font(Chrome.strong)
                Spacer(minLength: Space.small)
                Button("Cancel") { sheet = nil }
                    .buttonStyle(.link)
                    .font(Chrome.small)
                    .keyboardShortcut(.cancelAction)
            }

            HSplitView {
                options
                    .frame(minWidth: 260, idealWidth: 280, maxWidth: 320)
                summary
                    .frame(minWidth: 300, idealWidth: 380)
            }

            Strip(height: 38, divides: false) {
                Text("\(preview.wordCount.formatted()) words · \(preview.includedDocuments.count) documents")
                    .font(Chrome.small)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer(minLength: Space.small)
                Button("Export…") {
                    workspace.export(profile: profile)
                    sheet = nil
                }
                .buttonStyle(.borderedProminent)
                .disabled(preview.isEmpty)
            }
            .overlay(alignment: .top) {
                Rectangle().fill(Palette.hairline).frame(height: 1)
            }
        }
        .frame(width: 680, height: 480)
        .onAppear {
            profile.proseFace = settings.proseFace
        }
    }

    private var options: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaneSection("Format", divides: false) {
                    VStack(alignment: .leading, spacing: Space.snug) {
                        Picker("", selection: $profile.format) {
                            ForEach(ExportFormat.allCases) { format in
                                Label(format.title, systemImage: format.symbolName).tag(format)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.radioGroup)
                        .controlSize(.small)

                        Text(profile.format.detail)
                            .font(Chrome.small)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                PaneSection("Contents") {
                    VStack(alignment: .leading, spacing: Space.tight) {
                        Toggle("Title page", isOn: $profile.includesTitlePage)
                        Toggle("Chapter headings", isOn: $profile.includesChapterHeadings)
                        Toggle("Scene titles", isOn: $profile.includesSceneTitles)
                        Toggle("Notes", isOn: $profile.includesNotes)
                        Toggle("Skip outline scenes", isOn: $profile.excludesOutlines)
                    }
                    .controlSize(.small)
                }

                PaneSection("Scene break") {
                    Picker("", selection: $profile.separator) {
                        ForEach(SceneSeparator.allCases) { separator in
                            Text(separator.title).tag(separator)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }

                if profile.format.isRich {
                    PaneSection("Page") {
                        VStack(alignment: .leading, spacing: Space.tight) {
                            Picker("Face", selection: $profile.proseFace) {
                                ForEach(ProseFace.available) { face in
                                    Text(face.title).tag(face)
                                }
                            }
                            Toggle("Double-spaced", isOn: $profile.doubleSpaced)
                        }
                        .controlSize(.small)
                    }
                }
            }
            .padding(.horizontal, Space.regular)
            .padding(.bottom, Space.regular)
        }
    }

    /// Nothing is written until the author has seen what will be left out.
    private var summary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !preview.transformations.isEmpty {
                    PaneSection("What changes", divides: false) {
                        VStack(alignment: .leading, spacing: Space.snug) {
                            ForEach(preview.transformations) { warning in
                                WarningRow(warning: warning, tint: Palette.question)
                            }
                        }
                    }
                }

                if !preview.omissions.isEmpty {
                    PaneSection("What will not be there", divides: preview.transformations.isEmpty ? false : true) {
                        VStack(alignment: .leading, spacing: Space.snug) {
                            ForEach(preview.omissions) { warning in
                                WarningRow(warning: warning, tint: Palette.caution)
                            }
                        }
                    }
                }

                if !preview.hasConcerns {
                    HStack(spacing: Space.snug) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: Icon.control))
                            .foregroundStyle(Palette.confirmed)
                        Text("Everything in the manuscript will be exported.")
                            .font(Chrome.body)
                    }
                    .padding(.top, Space.regular)
                }
            }
            .padding(.horizontal, Space.regular)
            .padding(.bottom, Space.regular)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.subtleFill)
    }
}

private struct WarningRow: View {
    let warning: ExportWarning
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: Space.snug) {
            Circle()
                .fill(tint)
                .frame(width: 5, height: 5)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 0) {
                Text(warning.title)
                    .font(Chrome.strong)
                Text(warning.detail)
                    .font(Chrome.small)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

//
//  ManuscriptViews.swift
//  StoryLoom
//
//  Navigator, page, and inspector. The page is the point; the other two exist
//  only to get you back to it.
//

import SwiftUI

// MARK: - Sidebar

struct LibrarySidebar: View {
    @EnvironmentObject private var workspace: WorkspaceModel

    /// The List is the root of the column, not a child of a VStack: the split view
    /// hands its title-bar inset to the scrollable view it finds there, and a VStack
    /// in between swallows it. The project's name and the save state arrive as
    /// safe-area insets instead.
    var body: some View {
        List(selection: $workspace.library) {
            ForEach(LibraryItem.rooms) { row($0) }
        }
        .listStyle(.sidebar)
        .denseList()
        .safeAreaInset(edge: .top, spacing: 0) { ProjectHeader() }
        .safeAreaInset(edge: .bottom, spacing: 0) { floor }
    }

    /// Trash is pinned to the actual bottom of the sidebar, not merely placed
    /// last in the list. As a trailing `Section` it floated directly under Notes
    /// and rose with the rooms; on the floor it sits where the Finder, Mail and
    /// every other Mac application put it, and therefore where the author's eye
    /// already goes.
    private var floor: some View {
        VStack(spacing: 0) {
            Divider()
            SidebarTrashButton()
        }
    }

    private func row(_ item: LibraryItem) -> some View {
        Label {
            Text(item.title)
        } icon: {
            IconView(item.icon, size: Icon.room)
        }
        .badge(count(for: item))
        .tag(item)
        .help(item.question)
    }

    /// A count, not a badge. Nothing here is a red dot demanding to be cleared: an
    /// unwritten scene is not a notification, and an open question is the *point* of
    /// a story rather than a chore (11-UX, "Avoid red badges for creative
    /// incompleteness"). Threads count what the reader is still owed, which is the
    /// only number in this application a novelist should feel anything about.
    private func count(for item: LibraryItem) -> Int {
        switch item {
        case .manuscript: 0
        case .threads: workspace.owedThreads.count
        case .story: workspace.project.story.entities.count
        case .timeline: workspace.project.story.events.count
        case .notes: workspace.project.story.notes.count
        case .trash: workspace.project.story.trash.count
        case .history: 0
        }
    }
}

/// The only room that lives on the sidebar floor gets a full-width target rather
/// than inheriting a list row's small label hit area. It remains visually quiet
/// until the pointer reaches it, then gives the same broad, easy-to-aim feedback
/// as the rest of the sidebar.
private struct SidebarTrashButton: View {
    @EnvironmentObject private var workspace: WorkspaceModel
    @State private var isHovering = false
    @State private var isTrashTargeted = false

    private var isSelected: Bool { workspace.library == .trash }
    private var count: Int { workspace.project.story.trash.count }

    var body: some View {
        Button { workspace.library = .trash } label: {
            HStack(spacing: Space.medium) {
                IconView(LibraryItem.trash.icon, size: Icon.room)
                    .frame(width: Icon.room)
                    .foregroundStyle(isTrashTargeted ? .red : .primary)

                Text(isTrashTargeted ? "Move to Trash" : LibraryItem.trash.title)
                    .lineLimit(1)

                Spacer(minLength: Space.small)

                if count > 0 {
                    Text(count.formatted())
                        .font(Chrome.small)
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            .padding(.horizontal, Space.medium)
            .contentShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .fill(background)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Space.small)
        .padding(.vertical, Space.tight)
        .onHover { isHovering = $0 }
        .onDrop(
            of: [.storyLoomBinderItem],
            delegate: BinderTrashDrop(isTargeted: $isTrashTargeted, workspace: workspace)
        )
        .help(LibraryItem.trash.question)
        .accessibilityLabel(isTrashTargeted ? "Move item to Trash" : "Trash\(count > 0 ? ", \(count) items" : "")")
    }

    private var background: Color {
        if isTrashTargeted { return .red.opacity(0.14) }
        if isSelected { return Color.accentColor.opacity(0.18) }
        return isHovering ? Color.primary.opacity(0.08) : .clear
    }
}

/// Reuses the binder's in-process drag payload. Dropping a group preserves its
/// descendants as one trash item, while dropping a scene preserves just that
/// scene — both are reversible from the Trash room.
private struct BinderTrashDrop: DropDelegate {
    @Binding var isTargeted: Bool
    let workspace: WorkspaceModel

    func validateDrop(info: DropInfo) -> Bool { workspace.draggingBinderID != nil }

    func dropEntered(info: DropInfo) { isTargeted = true }
    func dropExited(info: DropInfo) { isTargeted = false }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: workspace.draggingBinderID == nil ? .forbidden : .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let id = workspace.draggingBinderID else { return false }
        isTargeted = false
        workspace.draggingBinderID = nil
        return workspace.trashBinderItem(id)
    }
}

/// The project's name, evicted from the title bar where a split-view divider was
/// cutting it in half. It reads better here anyway: it sits above the rooms of the
/// project rather than floating over all of them.
private struct ProjectHeader: View {
    @EnvironmentObject private var workspace: WorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(workspace.project.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)

            Text(subtitle)
                .font(Chrome.small)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 46)
        .padding(.horizontal, Space.medium)
        .padding(.bottom, Space.small)
        .accessibilityElement(children: .combine)
    }

    /// Words written today, when there are any. Not a goal, not a streak, not a
    /// ring — the author asked the question by opening the app, and this answers it
    /// once and then stops talking.
    private var subtitle: String {
        let total = workspace.project.totalWordCount.formatted()
        let session = workspace.sessionWords
        return session > 0 ? "\(total) words · \(session.formatted()) today" : "\(total) words"
    }
}

// MARK: - Navigator

struct ManuscriptNavigator: View {
    @EnvironmentObject private var workspace: WorkspaceModel
    @State private var filter = ""

    /// The manuscript with the filter applied, still grouped.
    ///
    /// Filtering builds a throwaway project and asks *it* for the grouping, so
    /// a filtered outline is derived by exactly the same code as the real one.
    /// A second grouping routine for the filtered case is how the two drift.
    private var filtered: StoryProject {
        guard !filter.isEmpty else { return workspace.project }
        var project = workspace.project
        project.documents = project.documents.filter { document in
            document.title.localizedCaseInsensitiveContains(filter)
                || document.text.localizedCaseInsensitiveContains(filter)
                || document.chapter.localizedCaseInsensitiveContains(filter)
                || document.volume.localizedCaseInsensitiveContains(filter)
        }
        return project
    }

    /// Dragging is off while a filter is on. The rows on screen are a subset, so
    /// "move this above that" has no defined meaning against the real running
    /// order — and guessing at one would quietly reorder scenes the author
    /// cannot see. Clear the filter and the handles come back.
    private var canReorder: Bool { filter.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            NavigatorBar(filter: $filter, prompt: "Filter manuscript") {
                // Scene first and alone, because it is what the author is
                // here to make. The three structural groups are one step down;
                // Folder is last, on its own, because it is the one that means
                // nothing about the book.
                Menu {
                    Button("New Scene") { workspace.createScene() }
                    Divider()
                    Button("New Chapter") { workspace.createGroup(.chapter) }
                    Button("New Part") { workspace.createGroup(.part) }
                    Button("New Volume") { workspace.createGroup(.volume) }
                    Divider()
                    Button("New Folder") { workspace.createGroup(.folder) }
                } label: {
                    // Baked, not laid out: a menu's label is drawn by AppKit,
                    // which honours an `NSImage`'s size and ignores a frame.
                    Glyph.plus.menuImage(size: Icon.navigatorAction)
                }
                .help("Add to the manuscript (⇧⌘N for a scene)")
            }

            if filtered.documents.isEmpty {
                EmptyStateView(
                    glyph: filter.isEmpty ? .manuscript : .search,
                    title: filter.isEmpty ? "No scenes yet" : "Nothing matches \u{201C}\(filter)\u{201D}",
                    message: filter.isEmpty
                        ? "A manuscript starts with one scene. It does not have to be the first one."
                        : "Try another word, or clear the filter.",
                    actionTitle: filter.isEmpty ? "Write the first scene" : nil,
                    action: filter.isEmpty ? { workspace.createScene() } : nil
                )
            } else {
                BinderOutline(items: outline)
            }
        }
    }

    /// The tree, filtered.
    ///
    /// Filtering prunes rather than flattens: a scene that matches keeps the
    /// folders above it, so a hit still tells you *where in the book* it is,
    /// which is most of what the author was asking. Folders that end up empty
    /// drop out — a filter should not leave a column of headings with nothing
    /// underneath them.
    private var outline: [BinderItem] {
        guard !filter.isEmpty else { return workspace.project.binder }
        let matching = Set(
            workspace.project.documents
                .filter {
                    $0.title.localizedCaseInsensitiveContains(filter)
                        || $0.text.localizedCaseInsensitiveContains(filter)
                }
                .map(\.id)
        )
        // A group whose own name matches keeps everything under it: searching
        // for "Part Two" means "show me Part Two", not "show me the nothing
        // inside it that happens to contain the words Part Two".
        func prune(_ items: [BinderItem]) -> [BinderItem] {
            items.compactMap { item in
                switch item.kind {
                case .document:
                    return matching.contains(item.id) ? item : nil
                case .folder:
                    if item.name.localizedCaseInsensitiveContains(filter) { return item }
                    let kept = prune(item.children)
                    if kept.isEmpty { return nil }
                    var copy = item
                    copy.children = kept
                    return copy
                }
            }
        }
        return prune(workspace.project.binder)
    }
}

// The derived outline that used to live here — `sceneMenu`, `VolumeSection`,
// `ChapterSection` — is gone with the two-string hierarchy it drew. The
// navigator is `BinderOutline` now, and the row menus belong to the rows.

/// A scene, on one line.
///
/// It used to be two, and the second one carried the point of view and the word
/// count. Both are true; neither was worth halving the number of scenes a novelist
/// can see at once. What survives is what you actually scan a manuscript *for*:
/// where you are (the title), how far along it is (the dot), how much is there (the
/// count), and whether the scene is load-bearing.
///
/// That last one is why the payoff mark exists. Scrolling a long manuscript, the
/// scenes that land a promise are the ones you must not move and must not cut, and
/// you are always hunting for them. They earn a mark in the margin; nothing else does.
struct SceneRow: View {
    let document: StoryDocument
    let lands: Int

    var body: some View {
        HStack(spacing: Space.snug) {
            if document.kind == .note {
                GlyphIcon(glyph: .note, size: Icon.inline)
                    .foregroundStyle(.tertiary)
                    .frame(width: 6)
            } else {
                StatusDot(color: document.status.tint, filled: document.status.isFilled)
            }

            Text(document.displayTitle)
                .font(Chrome.body)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: Space.tight)

            if lands > 0 {
                GlyphIcon(glyph: ThreadRole.lands.glyph, size: Icon.inline)
                    .font(.system(size: Icon.hint))
                    .foregroundStyle(Palette.confirmed)
                    .help(lands == 1 ? "Lands a thread" : "Lands \(lands) threads")
            }

            if !document.isEmpty {
                Text(document.wordCount.formatted())
                    .font(Chrome.small)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    private var label: String {
        var parts = ["\(document.displayTitle), \(document.status.title), \(document.wordCount) words"]
        if !document.pov.isEmpty { parts.append("point of view \(document.pov)") }
        if lands > 0 { parts.append(lands == 1 ? "lands a thread" : "lands \(lands) threads") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Editor canvas

struct EditorCanvas: View {
    @EnvironmentObject private var workspace: WorkspaceModel
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.proseStyle) private var style

    var body: some View {
        Group {
            if let document = workspace.selectedDocument {
                page(document)
            } else {
                EmptyStateView(
                    glyph: .manuscript,
                    title: "No scene selected",
                    message: "Choose a scene on the left, or start a new one.",
                    actionTitle: "New Scene",
                    action: { workspace.createScene() }
                )
                .background(Color(nsColor: style.pageColor))
            }
        }
    }

    private func page(_ document: StoryDocument) -> some View {
        VStack(spacing: 0) {
            if !workspace.isFocusMode {
                JumpBar(document: document)

                if settings.showsFormatBar {
                    FormatBar()
                }
            }

            if settings.viewMode == .page {
                PageRulerView()
            }

            ZStack(alignment: .topLeading) {
                ManuscriptEditor(
                    text: Binding(
                        get: { workspace.selectedDocument?.text ?? "" },
                        set: { workspace.updateText($0) }
                    ),
                    selection: $workspace.editorSelection,
                    documentID: document.id,
                    style: style,
                    commentAnchors: workspace.comments.filter { !$0.isResolved }.map(\.anchor),
                    mentionNames: workspace.mentionNames,
                    reveal: workspace.reveal,
                    command: workspace.editorCommand,
                    behaviour: TextBehaviour(
                        checksSpelling: settings.checksSpelling,
                        checksGrammar: settings.checksGrammar,
                        smartQuotes: settings.smartQuotes,
                        smartDashes: settings.smartDashes
                    ),
                    onCommentRequest: { workspace.addComment(range: $0) },
                    onFormat: { workspace.toggleFormat($0) },
                    onCreateRecord: { workspace.createEntity(kind: .character, name: $0) },
                    presentation: workspace.selectedPresentation,
                    onPresentationChange: { workspace.updatePresentation($0) }
                )

                if document.isEmpty {
                    EmptyPagePrompt(intention: document.intention)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !workspace.isFocusMode {
                EditorStatusBar(document: document)
            }
        }
        .background(Color(nsColor: settings.viewMode == .page ? NSColor.controlBackgroundColor : style.pageColor))
    }
}

/// Where you are, and what state it is in. A jump bar, in the sense Xcode means:
/// chrome that spans the pane, tells you your position in the project, and lets you
/// change it without leaving the page.
///
/// It used to be a fifty-point block centred over the text column, trying to look
/// like part of the manuscript. It is not part of the manuscript — it is a control
/// strip, and pretending otherwise cost twenty-two points of every page.
private struct JumpBar: View {
    let document: StoryDocument
    @EnvironmentObject private var workspace: WorkspaceModel
    @Environment(\.proseStyle) private var style

    var body: some View {
        Strip {
            QuietField(
                placeholder: "Chapter",
                text: Binding(
                    get: { workspace.selectedDocument?.chapter ?? "" },
                    set: { workspace.updateChapter($0) }
                ),
                font: Chrome.small
            )
            .foregroundStyle(.secondary)
            .frame(width: 104)

            GlyphIcon(glyph: .chevronRight, size: Icon.hint)
                .foregroundStyle(.quaternary)

            QuietField(
                placeholder: "Scene title",
                text: Binding(
                    get: { workspace.selectedDocument?.title ?? "" },
                    set: { workspace.renameSelectedDocument($0) }
                ),
                font: Chrome.body,
                weight: .medium
            )

            Spacer(minLength: Space.small)

            StatusPicker(status: document.status) { workspace.updateStatus($0) }
        }
        .background(Color(nsColor: style.pageColor))
    }
}

// MARK: - Status

/// Which draft this scene is in.
///
/// It was a `Menu`, and a menu could not do the job. AppKit draws the items, and
/// it draws them from a `Label` — text and a symbol, nothing else. Hand it a
/// `Circle` and it is quietly dropped, so the four statuses appeared as four
/// bare words with a tick beside one of them. The colours were on screen in the
/// binder, on every row, and nowhere at all in the list that assigns them: an
/// author could see three colours of dot down the outline and had no way to find
/// out which was which except by changing a scene and watching what happened.
///
/// A popover is drawn by SwiftUI, so the list can say the thing it is for. Each
/// status carries its own dot, the current one is marked by being drawn in the
/// accent colour rather than by a tick in a column, and the legend and the
/// control are the same object.
private struct StatusPicker: View {
    let status: DocumentStatus
    let select: (DocumentStatus) -> Void

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: Space.tight) {
                StatusDot(color: status.tint, filled: status.isFilled)
                Text(status.title)
                    .font(Chrome.small)
                GlyphIcon(glyph: .chevronDown, size: Icon.hint)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Scene status")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(DocumentStatus.allCases, id: \.self) { option in
                    StatusOption(option: option, isCurrent: option == status) {
                        select(option)
                        isPresented = false
                    }
                }
            }
            .padding(Space.tight)
            .frame(width: 132)
        }
    }
}

private struct StatusOption: View {
    let option: DocumentStatus
    let isCurrent: Bool
    let choose: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: choose) {
            HStack(spacing: Space.snug) {
                StatusDot(color: option.tint, filled: option.isFilled, size: 7)
                Text(option.title)
                    .font(isCurrent ? Chrome.strong : Chrome.body)
                    .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.snug)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .fill(fill)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    /// The current row keeps its tint whether or not the pointer is over it —
    /// a highlight that disappears under the pointer is a highlight the author
    /// has to move the mouse away to read.
    private var fill: Color {
        if isCurrent { return Color.accentColor.opacity(0.14) }
        return isHovering ? Color.primary.opacity(0.07) : .clear
    }
}

// MARK: - Format bar

/// The head of the page, in page view: where the column starts and stops.
///
/// It used to be a ruler numbered 0 to 8, which was three separate untruths. The
/// numbers were not inches — each division was a *ninth* of the measure laid out in
/// eighths, so the strip overflowed its own width by one whole division and the
/// last number sat outside the rule. The triangles looked like the margin handles
/// every ruler has and could not be dragged. And nothing on it was in the units the
/// measure is actually set in, which is characters per line, not distance.
///
/// What an author wants to know here is the one thing the old ruler could not say:
/// how wide this column is set. So it says that, once, quietly, and stops.
private struct PageRulerView: View {
    @Environment(\.proseStyle) private var style

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(spacing: Space.tight) {
                edgeMark
                Spacer(minLength: 0)
                Text("\(Int(style.measure.characters)) characters")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                Spacer(minLength: 0)
                edgeMark
            }
            .frame(width: style.measureWidth)
            Spacer(minLength: 0)
        }
        .frame(height: 16)
        .background(Palette.subtleFill)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.hairline).frame(height: 1)
        }
        .accessibilityElement()
        .accessibilityLabel("Column measure: \(Int(style.measure.characters)) characters per line")
    }

    /// Where the column begins and ends, marked on the rule itself.
    private var edgeMark: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.45))
            .frame(width: 1, height: 7)
    }
}

private struct FormatBar: View {
    @EnvironmentObject private var workspace: WorkspaceModel
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.proseStyle) private var style

    private var active: Set<InlineFormat> { workspace.editorSelection.formats }
    private var layer: PresentationLayer { workspace.selectedPresentation }
    private var worn: (underline: Bool, highlight: HighlightColour?, fontName: String?, fontSize: Double?) {
        layer.attributes(at: workspace.editorSelection.range)
    }

    var body: some View {
        Strip {
            // Emphasis, in the order every word processor puts it.
            FormatButton(glyph: InlineFormat.strong.glyph, help: "Bold (⌘B)",
                         isActive: active.contains(.strong)) { workspace.toggleFormat(.strong) }

            FormatButton(glyph: InlineFormat.emphasis.glyph, help: "Italic (⌘I)",
                         isActive: active.contains(.emphasis)) { workspace.toggleFormat(.emphasis) }

            FormatButton(glyph: .underline, help: "Underline (⌘U)",
                         isActive: worn.underline) { workspace.toggleUnderline() }

            FormatButton(glyph: InlineFormat.strikethrough.glyph, help: "Strikethrough (⇧⌘X)",
                         isActive: active.contains(.strikethrough)) { workspace.toggleFormat(.strikethrough) }

            BarDivider()

            // Structure. All of this is real Markdown in the file.
            Menu {
                Button("Body Text") { workspace.setHeading(0) }
                Divider()
                Button("Heading 1") { workspace.setHeading(1) }
                Button("Heading 2") { workspace.setHeading(2) }
                Button("Heading 3") { workspace.setHeading(3) }
            } label: {
                Label { Text("Paragraph style") } icon: { Glyph.heading.menuImage(size: Icon.formatter) }
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Paragraph style")

            FormatButton(glyph: .list, help: "Bulleted list") {
                workspace.toggleList(ordered: false)
            }
            FormatButton(glyph: .listOrdered, help: "Numbered list") {
                workspace.toggleList(ordered: true)
            }
            FormatButton(glyph: .textQuote, help: "Quote") { workspace.toggleBlockquote() }
            FormatButton(glyph: .asterisk, help: "Scene break (⇧⌘−)") { workspace.insertSceneBreak() }

            BarDivider()

            // Alignment.
            ForEach(TextAlignmentChoice.allCases) { choice in
                FormatButton(glyph: choice.glyph, help: choice.title,
                             isActive: layer.alignment(at: workspace.editorSelection.range) == choice) {
                    workspace.setAlignment(choice)
                }
            }

            BarDivider()

            // Highlighter: four colours, plus the Markdown `==` one that survives
            // the file. The swatches are presentation; `==` is text.
            Menu {
                Button("Marked (==, saved in the file)") { workspace.toggleHighlight() }
                Divider()
                ForEach(HighlightColour.allCases) { colour in
                    Button(colour.title) { workspace.setHighlightColour(colour) }
                }
                Divider()
                Button("None") { workspace.setHighlightColour(nil) }
            } label: {
                Label { Text("Highlight") } icon: { InlineFormat.highlight.glyph.menuImage(size: Icon.formatter) }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(worn.highlight?.swatch ?? Color.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Highlight")

            BarDivider()

            // Face and size for this passage only.
            Menu {
                Button("Match the page") { workspace.setFace(nil) }
                Divider()
                ForEach(ProseFace.available) { face in
                    Button(face.title) { workspace.setFace(face.font(size: 12).fontName) }
                }
            } label: {
                Label { Text("Font") } icon: { Glyph.fontFace.menuImage(size: Icon.formatter) }
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Font for the selection")

            Menu {
                Button("Match the page") { workspace.setFontSize(nil) }
                Divider()
                ForEach([11, 12, 13, 14, 16, 18, 20, 24, 30, 36], id: \.self) { size in
                    Button("\(size) pt") { workspace.setFontSize(Double(size)) }
                }
            } label: {
                HStack(spacing: Space.hair) {
                    Label { Text("Size") } icon: { Glyph.fontSize.menuImage(size: Icon.formatter) }
                        .labelStyle(.iconOnly)
                    Text(worn.fontSize.map { "\(Int($0))" } ?? "—")
                        .font(Chrome.small)
                        .monospacedDigit()
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Size for the selection")

            BarDivider()

            FormatButton(glyph: .comment, help: "Add comment (⌥⌘C)",
                         isEnabled: !workspace.editorSelection.isEmpty) {
                workspace.addComment(range: workspace.editorSelection.range)
            }

            Spacer(minLength: Space.small)

            FormatButton(
                glyph: settings.viewMode == .page ? .pageView : .continuousView,
                help: settings.viewMode == .page ? "Switch to continuous view" : "Switch to page view",
                isActive: settings.viewMode == .page
            ) {
                settings.viewMode = settings.viewMode == .page ? .continuous : .page
            }

            FormatButton(
                glyph: settings.appearance.glyph,
                help: "Appearance: \(settings.appearance.title) — click for \(settings.appearance.next.title)",
                isActive: settings.appearance != .system
            ) {
                settings.appearance = settings.appearance.next
            }
        }
        .background(Color(nsColor: style.pageColor))
    }
}

private struct FormatButton: View {
    let glyph: Glyph
    let help: String
    var isActive = false
    var isEnabled = true
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            GlyphIcon(glyph: glyph, size: Icon.formatter)
                .frame(width: Icon.controlHit.width, height: Icon.controlHit.height)
                .background {
                    RoundedRectangle(cornerRadius: Radius.control - 1, style: .continuous)
                        .fill(isActive ? AnyShapeStyle(.selection) : AnyShapeStyle(hovering ? Palette.subtleFill : .clear))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .foregroundStyle(isActive ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}

private struct BarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Palette.hairline)
            .frame(width: 1, height: 12)
            .padding(.horizontal, Space.hair)
    }
}

/// Everything about how the page is *shown*. None of it reaches the file.
private struct TypeMenu: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var open = false

    var body: some View {
        Button { open.toggle() } label: {
            HStack(spacing: Space.tight) {
                Label { Text("Font") } icon: { Glyph.fontFace.menuImage(size: Icon.formatter) }
                    .labelStyle(.iconOnly)
                Text(settings.proseFace.title)
                    .font(Chrome.small)
                Text("\(Int(settings.proseSize))")
                    .font(Chrome.small)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                GlyphIcon(glyph: .chevronDown, size: Icon.hint)
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Type and page")
        .popover(isPresented: $open, arrowEdge: .bottom) {
            TypePanel().frame(width: 268)
        }
    }
}

private struct TypePanel: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneSection("Type", note: "not part of the novel", divides: false) {
                VStack(alignment: .leading, spacing: Space.snug) {
                    FieldRow("Face") {
                        Picker("", selection: $settings.proseFace) {
                            ForEach(ProseFace.available) { face in
                                Text(face.title).tag(face)
                            }
                        }
                        .labelsHidden()
                    }

                    FieldRow("Size") {
                        HStack(spacing: Space.snug) {
                            Slider(value: $settings.proseSize, in: 13...24, step: 1)
                            Text("\(Int(settings.proseSize))")
                                .font(Chrome.small)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 16, alignment: .trailing)
                        }
                    }

                    FieldRow("Leading") {
                        Picker("", selection: $settings.lineHeight) {
                            ForEach(LineHeight.allCases) { height in
                                Text(height.title).tag(height)
                            }
                        }
                        .labelsHidden()
                    }

                    FieldRow("Paragraphs") {
                        Picker("", selection: $settings.paragraphLayout) {
                            ForEach(ParagraphLayout.allCases) { layout in
                                Text(layout.title).tag(layout)
                            }
                        }
                        .labelsHidden()
                    }
                }
            }

            PaneSection("Page") {
                VStack(alignment: .leading, spacing: Space.snug) {
                    FieldRow("Measure") {
                        Picker("", selection: $settings.measure) {
                            ForEach(Measure.allCases) { measure in
                                Text(measure.title).tag(measure)
                            }
                        }
                        .labelsHidden()
                    }

                    FieldRow("Paper") {
                        Picker("", selection: $settings.readingTheme) {
                            ForEach(ReadingTheme.allCases) { theme in
                                Text(theme.title).tag(theme)
                            }
                        }
                        .labelsHidden()
                    }

                    FieldRow("Theme") {
                        Picker("", selection: $settings.appearance) {
                            ForEach(AppAppearance.allCases) { app in
                                Text(app.title).tag(app)
                            }
                        }
                        .labelsHidden()
                    }
                }
            }

            PaneSection("While writing") {
                VStack(alignment: .leading, spacing: Space.tight) {
                    Picker("Dim everything but", selection: $settings.focusDepth) {
                        ForEach(FocusDepth.allCases) { depth in
                            Text(depth.title).tag(depth)
                        }
                    }
                    .pickerStyle(.menu)

                    Toggle("Typewriter scrolling", isOn: $settings.typewriter)
                    Toggle("Tint dialogue", isOn: $settings.highlightsDialogue)
                }
            }

            HStack {
                Spacer()
                Button("Reset") { settings.resetPage() }
                    .buttonStyle(.link)
                    .font(Chrome.small)
            }
            .padding(.top, Space.regular)
        }
        .controlSize(.small)
        .padding(Space.regular)
    }
}

/// The page is empty. That is not an error state and it is not a tutorial — it is
/// an invitation, and it repeats back the author's own stated intention, on the
/// line where the first sentence will go.
private struct EmptyPagePrompt: View {
    let intention: String
    @Environment(\.proseStyle) private var style

    var body: some View {
        VStack(alignment: .leading, spacing: Space.tight) {
            if intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Begin.")
                    .font(.system(size: 15, design: .serif))
                    .italic()
            } else {
                SectionLabel("What this scene is for")
                Text(intention)
                    .font(.system(size: 14, design: .serif))
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(Color(nsColor: style.mutedColor))
        .frame(maxWidth: style.measureWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, style.firstLineOffset)
        .accessibilityHidden(true)
    }
}

/// What the author might want to know, and nothing else. No streak, no goal, no
/// ring, and no reading time — a novel is not an article and nobody has ever moved
/// a scene because it was four minutes long.
private struct ProjectTargetPopover: View {
    @EnvironmentObject private var workspace: WorkspaceModel
    @State private var projectTarget: String

    init(projectTarget: Int) {
        _projectTarget = State(initialValue: "\(projectTarget)")
    }

    /// The book target commits as it is typed, not only on Return.
    ///
    /// They used to commit in `onSubmit` alone, which meant the overwhelmingly
    /// common way to leave a popover — clicking back onto the page — threw the
    /// number away without saying so. A field that quietly discards what you typed
    /// is worse than one that refuses it.
    var body: some View {
        VStack(alignment: .leading, spacing: Space.regular) {
            SectionLabel("Book word target")

            Text("A direction for the manuscript, not a quota for each scene.")
                .font(Chrome.small)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Space.small) {
                TextField("50000", text: $projectTarget)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 96)
                    .monospacedDigit()
                    .onChange(of: projectTarget) { _, new in
                        if let value = Int(new.trimmingCharacters(in: .whitespaces)) {
                            workspace.updateProjectWordTarget(value)
                        }
                    }

                Text("words")
                    .font(Chrome.small)
                    .foregroundStyle(.secondary)
            }

            let total = workspace.project.totalWordCount
            let target = workspace.project.story.projectWordTarget
            if target > 0 {
                ProgressView(value: min(1, Double(total) / Double(target)))
                    .progressViewStyle(.linear)

                Text("\(total.formatted()) written · \(max(0, target - total).formatted()) remaining")
                    .font(Chrome.small)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(Space.medium)
        .frame(width: 260)
    }
}

private struct EditorStatusBar: View {
    let document: StoryDocument
    @EnvironmentObject private var workspace: WorkspaceModel
    @EnvironmentObject private var settings: AppSettings
    @State private var showingTargetPopover = false

    /// The book, not the page.
    ///
    /// A book target is the useful number: it says how much manuscript exists
    /// without asking every scene to fill an arbitrary quota.
    private var projectProgress: Double {
        let target = workspace.project.story.projectWordTarget
        guard target > 0 else { return 0 }
        return min(1.0, Double(workspace.project.totalWordCount) / Double(target))
    }

    var body: some View {
        Strip(height: 22, divides: false) {
            Text("\(document.wordCount.formatted()) words")
                .monospacedDigit()

            if !workspace.editorSelection.isEmpty {
                Text("·")
                    .foregroundStyle(.quaternary)
                Text("\(selectedWords.formatted()) selected")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Text("·")
                .foregroundStyle(.quaternary)

            Button {
                showingTargetPopover.toggle()
            } label: {
                HStack(spacing: Space.snug) {
                    GlyphIcon(glyph: .goal, size: Icon.status)
                    Text("Book")
                    Text("\(workspace.project.totalWordCount.formatted()) / \(workspace.project.story.projectWordTarget.formatted())")
                        .monospacedDigit()
                    ProgressView(value: projectProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 52)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Book word target — click to change it")
            .popover(isPresented: $showingTargetPopover, arrowEdge: .bottom) {
                ProjectTargetPopover(projectTarget: workspace.project.story.projectWordTarget)
            }

            Spacer(minLength: Space.small)

            if settings.typewriter {
                GlyphIcon(glyph: .alignCentre, size: Icon.control)
                    .foregroundStyle(.secondary)
                    .help("Typewriter scrolling")
            }
            if settings.focusDepth != .off {
                GlyphIcon(glyph: .focusDepth, size: Icon.control)
                    .foregroundStyle(.secondary)
                    .help("Dimming everything but the \(settings.focusDepth.title.lowercased())")
            }

            let open = workspace.comments.filter { !$0.isResolved }.count
            if open > 0 {
                Button {
                    workspace.isInspectorVisible = true
                } label: {
                    Label { Text("\(open)") } icon: { GlyphIcon(glyph: .comment, size: Icon.inline) }
                        .monospacedDigit()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(open == 1 ? "1 comment" : "\(open) comments")
            }
        }
        .font(Chrome.small)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.hairline)
                .frame(height: 1)
        }
        .background(.bar)
    }

    private var selectedWords: Int {
        workspace.editorSelection.text
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .count
    }
}

// MARK: - Inspector

/// What this scene is *for*.
///
/// This pane used to be a form: status, point of view, where, tags, word count,
/// reading time, each in its own bordered card. All true, none of it useful — a
/// novelist stuck at 2 p.m. on a scene that will not move is not stuck because they
/// cannot remember the word count. They are stuck because the scene has no turn in
/// it, or because they are about to give away the thing that was supposed to hurt in
/// chapter nineteen.
///
/// So it asks instead. Four questions, in the order a scene is built: what is it
/// for, what changes, what must not get out, what should the reader still be feeling
/// on the next page. Every answer is private and every one is optional — but a scene
/// that can answer all four survives revision, and one that cannot is worth knowing
/// about now rather than in nine months.
///
/// The boxes are gone with the cards. A bordered field says *fill me in*; a
/// question with a rule under it says *answer me if you can*. They are not the same
/// instruction, and a novelist can feel the difference at four in the afternoon.
struct InspectorPane: View {
    @EnvironmentObject private var workspace: WorkspaceModel

    var body: some View {
        Group {
            if let document = workspace.selectedDocument {
                VStack(spacing: 0) {
                    SceneStrip(document: document)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            placement(document)
                            questions
                            ThreadLinks(document: document)
                            named(document)
                            comments
                        }
                        .padding(.horizontal, Space.regular)
                        .padding(.bottom, Space.section)
                    }
                }
            } else {
                EmptyStateView(
                    glyph: .inspector,
                    title: "Nothing selected",
                    message: "The inspector describes whatever scene you are in."
                )
            }
        }
        .inspectorColumnWidth(min: 250, ideal: Metrics.inspectorWidth, max: 400)
    }

    /// How the author finds this scene again. Real, but small — it is not how they
    /// write it, so it does not get a section of its own.
    private func placement(_ document: StoryDocument) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            FieldRow("POV") {
                QuietField(
                    placeholder: "Whose eyes?",
                    text: Binding(get: { document.pov }, set: { workspace.updatePOV($0) })
                )
            }
            FieldRow("Where") {
                QuietField(
                    placeholder: "Where does it happen?",
                    text: Binding(get: { document.location }, set: { workspace.updateLocation($0) })
                )
            }
        }
        .padding(.top, Space.snug)
    }

    private var questions: some View {
        PaneSection("The scene", note: "never exported") {
            VStack(alignment: .leading, spacing: Space.medium) {
                Question(
                    "Why does this scene exist?",
                    prompt: "What must be true by the end.",
                    text: Binding(
                        get: { workspace.selectedDocument?.intention ?? "" },
                        set: { workspace.updateIntention($0) }
                    )
                )

                Question(
                    "What changes?",
                    prompt: "The turn. No turn, no scene.",
                    text: Binding(
                        get: { workspace.selectedDocument?.turn ?? "" },
                        set: { workspace.updateTurn($0) }
                    )
                )

                Question(
                    "What must not be revealed?",
                    prompt: "Not here. Not yet.",
                    text: Binding(
                        get: { workspace.selectedDocument?.withheld ?? "" },
                        set: { workspace.updateWithheld($0) }
                    )
                )

                Question(
                    "What should remain?",
                    prompt: "What the reader carries out.",
                    text: Binding(
                        get: { workspace.selectedDocument?.residue ?? "" },
                        set: { workspace.updateResidue($0) }
                    )
                )
            }
        }
    }

    /// Evidence, not inference: these are the records whose name or alias literally
    /// appears in this scene, and StoryLoom can point at every one.
    private func named(_ document: StoryDocument) -> some View {
        PaneSection("Named in the prose") {
            let mentioned = workspace.entitiesMentioned(in: document)
            if mentioned.isEmpty {
                Text("Nothing yet. Type “@” on the page.")
                    .font(Chrome.small)
                    .foregroundStyle(.tertiary)
            } else {
                FlowLayout {
                    ForEach(mentioned) { entity in
                        Chip(
                            text: entity.displayName,
                            icon: entity.kind.icon,
                            tint: entity.kind.tint
                        ) {
                            workspace.navigate(to: .entity(entity.id))
                        }
                    }
                }
            }
        }
    }

    private var comments: some View {
        PaneSection("Comments") {
            let comments = workspace.comments
            if comments.isEmpty {
                Text("Select a passage and press ⌥⌘C.")
                    .font(Chrome.small)
                    .foregroundStyle(.tertiary)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(comments) { comment in
                        CommentRow(comment: comment)
                    }
                }
            }
        }
    }
}

/// One of the four. The label is the question, verbatim — not a noun the author has
/// to translate back into a question every time they look at it.
private struct Question: View {
    let title: String
    let prompt: String
    @Binding var text: String

    init(_ title: String, prompt: String, text: Binding<String>) {
        self.title = title
        self.prompt = prompt
        self._text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(Chrome.small)
                .foregroundStyle(.secondary)
            QuietText(placeholder: prompt, text: $text)
        }
    }
}

/// Status and size, in the one place the eye already goes for them.
private struct SceneStrip: View {
    let document: StoryDocument
    @EnvironmentObject private var workspace: WorkspaceModel

    var body: some View {
        Strip {
            // The same control as the scene header, so status is set one way in
            // the application and the colours are explained wherever it appears.
            StatusPicker(status: document.status) { workspace.updateStatus($0) }

            Spacer(minLength: Space.small)

            Text("\(document.wordCount.formatted()) words")
                .font(Chrome.small)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
    }
}

/// Which questions this scene puts in the reader's head, moves, and answers.
///
/// This is the one piece of metadata in StoryLoom that earns its keep at a million
/// words, because it is the only one the author cannot reconstruct by reading. A
/// scene remembers what happens in it. Nothing remembers what it *promised*.
private struct ThreadLinks: View {
    let document: StoryDocument
    @EnvironmentObject private var workspace: WorkspaceModel

    var body: some View {
        PaneSection("Threads") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(ThreadRole.allCases, id: \.self) { role in
                    ForEach(document.threadIDs(for: role), id: \.self) { id in
                        FieldRow(role.arcTitle) {
                            threadRow(id, role: role)
                        }
                    }
                }

                HStack(spacing: Space.medium) {
                    Menu {
                        if available.isEmpty {
                            Text("Every thread is already linked here.")
                        }
                        ForEach(available) { thread in
                            Menu(thread.displayQuestion) {
                                ForEach(ThreadRole.allCases, id: \.self) { role in
                                    Button(role.arcTitle) {
                                        workspace.setThreadRole(role, forThread: thread.id, in: document.id)
                                    }
                                }
                            }
                        }
                    } label: {
                        Label { Text("Link") } icon: { Glyph.link.menuImage(size: Icon.formatter) }
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()

                    Button {
                        workspace.openThreadHere()
                    } label: {
                        Label { Text("Open a new one") } icon: { Glyph.plus.menuImage(size: Icon.formatter) }
                    }
                    .buttonStyle(.link)
                    .help("Create a thread this scene opens (⇧⌘T)")

                    Spacer(minLength: 0)
                }
                .font(Chrome.small)
                .padding(.top, document.touchesAnyThread ? Space.snug : 0)
            }
        }
    }

    private var available: [StoryThread] {
        workspace.project.story.threads.filter { document.roles(for: $0.id).isEmpty }
    }

    private func threadRow(_ id: StoryThread.ID, role: ThreadRole) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.tight) {
            Button {
                workspace.navigate(to: .thread(id))
            } label: {
                Text(workspace.threadName(id))
                    .font(Chrome.body)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Menu {
                ForEach(ThreadRole.allCases, id: \.self) { option in
                    Button {
                        workspace.setThreadRole(option, forThread: id, in: document.id)
                    } label: {
                        Label(option.arcTitle, systemImage: option == role ? "checkmark" : "")
                    }
                }
                Divider()
                Button("Unlink", role: .destructive) {
                    workspace.setThreadRole(nil, forThread: id, in: document.id)
                }
            } label: {
                GlyphIcon(glyph: .ellipsis, size: Icon.inline)
                    .foregroundStyle(.tertiary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}

private struct CommentRow: View {
    let comment: StoryComment
    @EnvironmentObject private var workspace: WorkspaceModel

    private var isOrphaned: Bool {
        guard let document = workspace.project.document(comment.documentID) else { return true }
        return comment.anchor.isOrphaned(in: document.text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: Space.tight) {
                Button {
                    workspace.reveal(comment)
                } label: {
                    Text(comment.anchor.excerpt)
                        .font(.system(size: 11, design: .serif))
                        .italic()
                        .foregroundStyle(isOrphaned ? .tertiary : .secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(isOrphaned)

                if isOrphaned {
                    GlyphIcon(glyph: .linkAdd, size: Icon.inline)
                        .foregroundStyle(Palette.caution)
                        .help("The words this was attached to are gone")
                }

                Menu {
                    Button("Go to Passage") { workspace.reveal(comment) }
                        .disabled(isOrphaned)
                    Button("Resolve") { workspace.resolveComment(comment.id) }
                    Divider()
                    Button("Delete", role: .destructive) { workspace.deleteComment(comment.id) }
                } label: {
                    GlyphIcon(glyph: .ellipsis, size: Icon.inline)
                        .foregroundStyle(.tertiary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }

            QuietText(
                placeholder: "What about it?",
                text: Binding(
                    get: { comment.body },
                    set: { workspace.updateComment(comment.id, body: $0) }
                ),
                size: 11
            )
        }
        .padding(.vertical, Space.snug)
    }
}

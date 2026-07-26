//
//  BinderViews.swift
//  StoryLoom
//
//  The manuscript outline.
//
//  This is a list of a book's parts, not a list of files, and three decisions
//  follow from that.
//
//  A group carries a *semantic* type — Volume, Part, Chapter, Folder — and the
//  type constrains nothing. A Part may sit at the root; a Chapter need not be
//  inside anything; a lone Scene is a legal manuscript. Novels are not shaped
//  alike, and an outline that insists on Volume → Part → Chapter → Scene spends
//  its first five minutes making a writer decline two tiers they do not want.
//  The type changes the word and the drawing; the tree stays free.
//
//  The tree is drawn by hand rather than with `OutlineGroup`, because reordering
//  needs three drop zones on every row — above, below, and *inside* — and "drop
//  between these two rows" is not something a disclosure group models.
//
//  And it stays inside `List` with `.listStyle(.sidebar)`. A hand-rolled stack
//  would give more control over the row and would immediately owe the author a
//  reimplementation of selection: the focus ring, the inactive-window grey, the
//  system accent. That is a debt worth refusing.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Geometry

private enum Outline {
    /// One tier of nesting. Enough that three levels are unmistakable at a
    /// glance, small enough that a scene five deep still has room for its name.
    static let indent: CGFloat = 22
    /// The column the chevron sits in. Scenes reserve the same width so their
    /// titles line up with the group titles above them.
    static let chevronColumn: CGFloat = 20
}

// MARK: - The outline

struct BinderOutline: View {
    let items: [BinderItem]

    @EnvironmentObject private var workspace: WorkspaceModel
    @State private var drop: DropTarget?

    /// Word counts by document id, resolved once per redraw. A group's count is
    /// the sum of its descendants, and walking back into the project for every
    /// row would be quadratic on a long book.
    private var counts: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: workspace.project.documents.map { ($0.id, $0.wordCount) })
    }

    var body: some View {
        List(selection: selection) {
            BinderRows(items: items, depth: 0, counts: counts, drop: $drop)

            // The last few points of the outline, so an item can be dragged out
            // of a folder without having to find a root-level row to aim below.
            BinderTailDrop(drop: $drop)

            if !workspace.project.archivedDocuments.isEmpty {
                Section {
                    ForEach(workspace.project.archivedDocuments) { document in
                        HStack(spacing: Space.snug) {
                            GlyphIcon(glyph: .archive, size: Icon.navigatorRow)
                                .foregroundStyle(.tertiary)
                            Text(document.displayTitle)
                                .font(Chrome.body)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer(minLength: Space.tight)
                            Button("Restore") { workspace.restore(document) }
                                .buttonStyle(.link)
                                .font(Chrome.small)
                        }
                    }
                } header: {
                    GroupHeader(title: "Archived", count: workspace.project.archivedDocuments.count)
                }
            }
        }
        .listStyle(.sidebar)
        .denseList()
        // The navigator is a high-density outline. Its position is already
        // evident from the visible tree, so a persistent wide scroller is noise;
        // scrolling still works normally with the mouse, trackpad, and keyboard.
        .scrollIndicators(.hidden)
        // Return renames whatever is selected — the shortcut every Mac outline
        // has had since the Finder. It lives on the List because an unfocused
        // row never sees the key.
        .onKeyPress(.return) {
            guard let id = workspace.selectedBinderID else { return .ignored }
            workspace.renamingBinderID = id
            return .handled
        }
    }

    /// One selection for both kinds of row.
    ///
    /// A folder is a row an author clicks — to rename it, to make a scene inside
    /// it, to see it highlighted while they drag something at it — and until now
    /// only scenes carried a tag, so clicking a chapter did nothing at all. The
    /// binding routes through the workspace rather than at `selectedDocumentID`
    /// directly because selecting a folder must *not* change which scene is open:
    /// collapsing the book's shape is not a request to stop editing.
    private var selection: Binding<UUID?> {
        Binding(
            get: { workspace.selectedBinderID },
            set: { workspace.selectBinderRow($0) }
        )
    }
}

/// One tier. Recurses into groups.
private struct BinderRows: View {
    let items: [BinderItem]
    let depth: Int
    let counts: [UUID: Int]
    @Binding var drop: DropTarget?

    @EnvironmentObject private var workspace: WorkspaceModel

    var body: some View {
        ForEach(items) { item in
            switch item.kind {
            case .folder:
                GroupRow(item: item, depth: depth, counts: counts, drop: $drop)
            case .document:
                if let document = workspace.project.documents.first(where: { $0.id == item.id }) {
                    SceneBinderRow(document: document, depth: depth, drop: $drop)
                }
            }
        }
    }
}

// MARK: - Group row

private struct GroupRow: View {
    let item: BinderItem
    let depth: Int
    let counts: [UUID: Int]
    @Binding var drop: DropTarget?

    @EnvironmentObject private var workspace: WorkspaceModel
    @State private var isExpanded = true
    @State private var height: CGFloat = 0

    var body: some View {
        row
        if isExpanded {
            BinderRows(items: item.children, depth: depth + 1, counts: counts, drop: $drop)
        }
    }

    private var row: some View {
        HStack(spacing: Space.snug) {
            // The chevron has its own comfortable hit target. Selecting its
            // group still leaves the scene on screen alone, so collapsing a
            // part to see the shape of the book never interrupts writing.
            Button {
                withAnimation(.easeOut(duration: 0.12)) { isExpanded.toggle() }
            } label: {
                GlyphIcon(glyph: isExpanded ? .chevronDown : .chevronRight, size: Icon.chevron)
                    .foregroundStyle(.secondary)
                    .frame(width: Outline.chevronColumn, height: 24, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            GlyphIcon(glyph: item.group.glyph, size: Icon.folder)
                .foregroundStyle(.secondary)

            BinderName(id: item.id, text: item.displayName, font: Chrome.textStrong)

            Spacer(minLength: Space.small)

            CountLabel(words)
        }
        // A tagged `List` row normally supplies its own selection hit target,
        // but the drag/drop and AppKit context-menu bridges make that target
        // unreliable in the middle of a group row. State selection explicitly
        // on the complete row; a drag still wins over a tap, and a double-click
        // still arrives at the rename gesture below.
        .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
        .padding(.leading, CGFloat(depth) * Outline.indent)
        .tag(item.id)
        .binderRow(
            id: item.id,
            acceptsInside: true,
            height: $height,
            drop: $drop,
            workspace: workspace
        )
        .binderContextMenu(onOpen: { workspace.selectBinderRow(item.id) }) { menu }
        // A folder that is dropped on while collapsed opens, so the author can
        // see where the thing they just dragged has landed.
        .onChange(of: drop) { _, target in
            if target == DropTarget(id: item.id, edge: .inside) { isExpanded = true }
        }
        .renameOnDoubleClick(id: item.id, workspace: workspace)
    }

    private var words: Int {
        item.children.documentIDs.reduce(0) { $0 + (counts[$1] ?? 0) }
    }

    private var menu: [BinderMenuEntry] {
        [
            .item("New Scene") { workspace.createScene(inFolder: item.id) },
            .submenu("New Group", GroupKind.allCases.map { kind in
                .item(kind.title) { workspace.createGroup(kind, inside: item.id) }
            }),

            .separator,

            .item("Rename") { workspace.renamingBinderID = item.id },
            .item("Duplicate") { workspace.duplicateGroup(item.id) },
            .submenu("Change Type", GroupKind.allCases.map { kind in
                .item(kind.title, isEnabled: kind != item.group) {
                    workspace.changeGroupType(item.id, to: kind)
                }
            }),
            .moveTo(item.id, in: workspace),

            .separator,

            .destructive("Move to Trash") { workspace.deleteFolder(item.id) },
        ]
    }
}

// MARK: - Scene row

private struct SceneBinderRow: View {
    let document: StoryDocument
    let depth: Int
    @Binding var drop: DropTarget?

    @EnvironmentObject private var workspace: WorkspaceModel
    @State private var height: CGFloat = 0

    var body: some View {
        HStack(spacing: Space.snug) {
            // No chevron, but the same column, so titles align down a tier
            // instead of stepping in and out with whatever has children.
            Color.clear.frame(width: Outline.chevronColumn, height: 1)

            StatusDot(color: document.status.tint)

            BinderName(id: document.id, text: document.displayTitle, font: Chrome.body)

            Spacer(minLength: Space.small)

            if !document.landsThreadIDs.isEmpty {
                GlyphIcon(glyph: .circleDot, size: Icon.hint)
                    .foregroundStyle(.tertiary)
                    .help("Lands a thread")
            }

            CountLabel(document.wordCount)
        }
        .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
        .padding(.leading, CGFloat(depth) * Outline.indent)
        .tag(document.id)
        .binderRow(
            id: document.id,
            acceptsInside: false,
            height: $height,
            drop: $drop,
            workspace: workspace
        )
        .binderContextMenu(onOpen: { workspace.selectBinderRow(document.id) }) { menu }
        .renameOnDoubleClick(id: document.id, workspace: workspace)
    }

    private var menu: [BinderMenuEntry] {
        [
            .item("Rename") { workspace.renamingBinderID = document.id },
            .item("Duplicate") { workspace.duplicate(document) },
            .moveTo(document.id, in: workspace),
            .submenu("Change Status", DocumentStatus.allCases.map { status in
                .item(status.title, isEnabled: status != document.status) {
                    workspace.selectedDocumentID = document.id
                    workspace.updateStatus(status)
                }
            }),

            .separator,

            .destructive("Move to Trash") { workspace.deleteDocument(document) },
        ]
    }
}

// MARK: - Pieces

/// A title that becomes a field in place.
///
/// Rename is never a sheet. Naming a chapter is a half-second thought, and a
/// modal turns it into a decision with an OK button on the end of it.
private struct BinderName: View {
    let id: UUID
    let text: String
    let font: Font

    @EnvironmentObject private var workspace: WorkspaceModel
    @State private var draft = ""
    @FocusState private var editing: Bool

    private var isRenaming: Bool { workspace.renamingBinderID == id }

    var body: some View {
        Group {
            if isRenaming {
                TextField("", text: $draft)
                    .textFieldStyle(.plain)
                    .font(font)
                    .focused($editing)
                    .onSubmit { commit() }
                    // Escape abandons the edit. The draft is a copy, so the real
                    // name is never touched until Return.
                    .onExitCommand { workspace.renamingBinderID = nil }
                    .onAppear { draft = text; editing = true }
                    .onChange(of: editing) { _, focused in if !focused { commit() } }
            } else {
                Text(text)
                    .font(font)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    private func commit() {
        guard isRenaming else { return }
        workspace.renameBinderItem(id, to: draft)
        workspace.renamingBinderID = nil
    }
}

/// A word count, or nothing at all.
///
/// Zero is not information. A folder made ten seconds ago has no words in it,
/// and saying so in the same column that carries "78,230" teaches the eye to
/// skip a number it should be reading.
private struct CountLabel: View {
    let words: Int

    init(_ words: Int) { self.words = words }

    var body: some View {
        if words > 0 {
            Text(words.formatted(.number))
                .font(Chrome.small)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
        }
    }
}

// MARK: - Dragging

/// Where a drop would land.
nonisolated struct DropTarget: Equatable, Sendable {
    enum Edge: Sendable { case above, inside, below }
    let id: UUID
    let edge: Edge
}

/// What travels on the pasteboard: an id, and nothing else.
///
/// Deliberately not the item. A drag carrying a copy of the subtree can be
/// dropped after the tree has moved on underneath it and put a stale branch
/// back; an id can only ever move the thing that is actually there.
///
/// The id is also held on the workspace for the length of the drag, and *that*
/// is what a drop reads. Pulling it off the provider means an asynchronous load
/// on the way in, so the row under the pointer cannot say whether it would
/// accept the thing being dragged until after the author has let go — which is
/// how a drag ends up with no indicator and a drop that does nothing.
nonisolated struct BinderDrag: Sendable {
    static func provider(for id: UUID) -> NSItemProvider {
        let provider = NSItemProvider()
        // `.ownProcess`: this identifier means nothing outside StoryLoom, and a
        // row dragged onto the Desktop should not leave a file behind.
        provider.registerDataRepresentation(for: .storyLoomBinderItem, visibility: .ownProcess) { completion in
            completion(Data(id.uuidString.utf8), nil)
            return nil
        }
        return provider
    }
}

private extension View {
    /// Makes a row draggable, droppable, and able to say where a drop would land.
    ///
    /// The zones used to be four transparent views laid over the row. They did
    /// their job and took the row's clicks with them: `Color.clear` is a hit
    /// target like any other, so the overlay swallowed the press that selects a
    /// row and the press-and-drag that starts a drag — the whole outline was
    /// covered by something invisible standing in front of it.
    ///
    /// A `DropDelegate` reports the pointer's position instead, so the same
    /// three zones are computed from one number and nothing sits on top of the
    /// row at all.
    func binderRow(
        id: UUID,
        acceptsInside: Bool,
        height: Binding<CGFloat>,
        drop: Binding<DropTarget?>,
        workspace: WorkspaceModel
    ) -> some View {
        contentShape(Rectangle())
            // Do not leave selection to the table cell's sparse hit regions.
            // A chapter is a row, not just its title: clicking its count,
            // whitespace, or icon should select it every time.
            .simultaneousGesture(
                TapGesture().onEnded { workspace.selectBinderRow(id) }
            )
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height.wrappedValue = $0 }
            .onDrag {
                workspace.draggingBinderID = id
                return BinderDrag.provider(for: id)
            }
            .onDrop(
                of: [.storyLoomBinderItem],
                delegate: BinderRowDrop(
                    id: id,
                    acceptsInside: acceptsInside,
                    height: height.wrappedValue,
                    drop: drop,
                    workspace: workspace
                )
            )
            .overlay(alignment: .top) {
                if drop.wrappedValue == DropTarget(id: id, edge: .above) { InsertionLine() }
            }
            .overlay(alignment: .bottom) {
                if drop.wrappedValue == DropTarget(id: id, edge: .below) { InsertionLine() }
            }
            .background {
                if drop.wrappedValue == DropTarget(id: id, edge: .inside) {
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .fill(Color.accentColor.opacity(0.18))
                }
            }
            // `.scrollIndicators(.hidden)` is advisory for a macOS `List` and
            // is ignored when the user's system preference requests permanent
            // scrollbars. This row lives inside the list's actual scroll view,
            // so the small AppKit helper below can hide that scroller without
            // touching the editor or any other scrollable surface.
            .background(BinderScrollerHider())
    }

    /// Double-click renames, and single-click still selects.
    ///
    /// `onTapGesture(count: 2)` claims the press outright, and a row inside a
    /// `List` never sees it — which is why clicking a scene stopped selecting it.
    /// A simultaneous gesture runs beside the table's own click handling instead
    /// of in place of it.
    func renameOnDoubleClick(id: UUID, workspace: WorkspaceModel) -> some View {
        simultaneousGesture(
            TapGesture(count: 2).onEnded { workspace.renamingBinderID = id }
        )
    }
}

/// Hides the binder's AppKit scroller even when macOS is configured to always
/// show scrollbars. This is deliberately attached inside each row: from there
/// the nearest enclosing scroll view is the binder's, not the editor's.
private struct BinderScrollerHider: NSViewRepresentable {
    func makeNSView(context: Context) -> BinderScrollerHiderView {
        BinderScrollerHiderView()
    }

    func updateNSView(_ view: BinderScrollerHiderView, context: Context) {
        view.hideScroller()
    }
}

private final class BinderScrollerHiderView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        hideScrollerSoon()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        hideScrollerSoon()
    }

    func hideScroller() {
        guard let scroller = enclosingScrollView else { return }
        scroller.hasVerticalScroller = false
        scroller.autohidesScrollers = true
    }

    private func hideScrollerSoon() {
        DispatchQueue.main.async { [weak self] in self?.hideScroller() }
    }
}

/// Which third of a row the pointer is over, and what that means.
///
/// A group gets three zones: the top quarter inserts above, the bottom quarter
/// below, and the middle half drops *inside*. A scene has no inside, so it
/// splits in half. The proportions are what make the gesture predictable —
/// aiming between two chapters should not require hitting two points.
private struct BinderRowDrop: DropDelegate {
    let id: UUID
    let acceptsInside: Bool
    let height: CGFloat
    @Binding var drop: DropTarget?
    let workspace: WorkspaceModel

    func validateDrop(info: DropInfo) -> Bool { dragged != nil }

    func dropEntered(info: DropInfo) {
        drop = target(at: info.location)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        drop = target(at: info.location)
        return DropProposal(operation: drop == nil ? .forbidden : .move)
    }

    func dropExited(info: DropInfo) {
        if drop?.id == id { drop = nil }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let dragged, let target = target(at: info.location) else { return false }
        drop = nil
        workspace.draggingBinderID = nil

        switch target.edge {
        case .inside: return workspace.moveBinderItem(dragged, into: id, at: nil)
        case .above: return workspace.moveBinderItem(dragged, beside: id, below: false)
        case .below: return workspace.moveBinderItem(dragged, beside: id, below: true)
        }
    }

    private var dragged: UUID? { workspace.draggingBinderID }

    /// Nil when the drop would be refused, so the indicator never promises a
    /// move that `WorkspaceModel` is about to turn down.
    private func target(at point: CGPoint) -> DropTarget? {
        guard let dragged, dragged != id else { return nil }
        // A folder cannot be dropped into its own subtree: the branch would come
        // away from the root and take half a book with it.
        if workspace.project.binder.contains(id, under: dragged) { return nil }

        let span = max(height, 1)
        guard acceptsInside else {
            return DropTarget(id: id, edge: point.y < span * 0.5 ? .above : .below)
        }
        if point.y < span * 0.25 { return DropTarget(id: id, edge: .above) }
        if point.y > span * 0.75 { return DropTarget(id: id, edge: .below) }
        return DropTarget(id: id, edge: .inside)
    }
}

/// The strip of nothing under the last row: a drop here means the top level.
///
/// Without it, the only way to lift a scene out of the last folder in the book
/// is to find a root-level row above it and aim below — and in a manuscript
/// whose last row *is* inside that folder, there is no such row to aim at.
private struct BinderTailDrop: View {
    @Binding var drop: DropTarget?

    @EnvironmentObject private var workspace: WorkspaceModel
    @State private var isTargeted = false

    var body: some View {
        Color.clear
            .frame(height: 24)
            .listRowSeparator(.hidden)
            .overlay(alignment: .top) { if isTargeted { InsertionLine() } }
            .onDrop(of: [.storyLoomBinderItem], delegate: RootDrop(isTargeted: $isTargeted, workspace: workspace))
            .onChange(of: drop) { _, target in
                // Two indicators at once would be a lie about where the thing is
                // going. Whichever was entered last wins.
                if target != nil { isTargeted = false }
            }
    }

    private struct RootDrop: DropDelegate {
        @Binding var isTargeted: Bool
        let workspace: WorkspaceModel

        func validateDrop(info: DropInfo) -> Bool { workspace.draggingBinderID != nil }
        func dropEntered(info: DropInfo) { isTargeted = true }
        func dropExited(info: DropInfo) { isTargeted = false }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            DropProposal(operation: .move)
        }

        func performDrop(info: DropInfo) -> Bool {
            guard let dragged = workspace.draggingBinderID else { return false }
            isTargeted = false
            workspace.draggingBinderID = nil
            return workspace.moveBinderItem(dragged, into: nil, at: nil)
        }
    }
}

/// The line between two rows: two points, the accent colour, nothing else —
/// the mark AppKit draws, which a novelist has already seen a thousand times.
private struct InsertionLine: View {
    var body: some View {
        Rectangle()
            .fill(Color.accentColor)
            .frame(height: 2)
            .allowsHitTesting(false)
    }
}

nonisolated extension UTType {
    static let storyLoomBinderItem = UTType(exportedAs: "io.storyloom.binder-item")
}

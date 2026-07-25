//
//  WorkspaceView.swift
//  StoryLoom
//
//  The window. Three collapsible regions exactly as 12-UI specifies: a navigator
//  to find a place, a canvas to do the work, and an inspector to understand the
//  selected thing. The canvas never becomes a dashboard, and the toolbar carries
//  four controls, because a writing application that needs a fifth has already
//  lost the argument.
//

import SwiftUI

struct WorkspaceView: View {
    @EnvironmentObject private var workspace: WorkspaceModel
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var recents: RecentProjects
    @Environment(\.undoManager) private var undoManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var columns: NavigationSplitViewVisibility = .all
    @State private var sheet: WorkspaceSheet?

    var body: some View {
        Group {
            if !workspace.hasProject {
                // A remembered project is still being read: hold the window empty
                // for the moment it takes rather than showing a start screen in
                // front of a book that is about to arrive.
                if workspace.isRestoring {
                    Color(nsColor: .windowBackgroundColor)
                } else {
                    StartScreen()
                }
            } else if workspace.isFocusMode {
                focusMode
            } else {
                split
            }
        }
        .environment(\.proseStyle, settings.proseStyle(appearance: colorScheme))
        .preferredColorScheme(settings.appearance.colorScheme)
        .sheet(item: $sheet) { destination in
            switch destination {
            case .search: SearchPanel(sheet: $sheet)
            case .palette: CommandPalette(sheet: $sheet)
            case .export: ExportPanel(sheet: $sheet)
            }
        }
        .alert(item: $workspace.error) { error in
            Alert(title: Text("StoryLoom"), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            workspace.undoManager = undoManager
            workspace.resumeLastSession(enabled: settings.reopensLastProject)
        }
        .onChange(of: undoManager) { _, manager in
            workspace.undoManager = manager
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            workspace.checkForExternalChanges()
        }
        .onReceive(NotificationCenter.default.publisher(for: .storyLoomCommand)) { note in
            handle(note)
        }
        .background(WindowConfigurator(
            title: workspace.hasProject ? workspace.project.title : "StoryLoom",
            isDialog: !workspace.hasProject,
            dialogSize: StartScreen.preferredSize(recentCount: recents.entries.filter(\.exists).count)
        ))
    }

    // MARK: Layouts

    private var split: some View {
        NavigationSplitView(columnVisibility: $columns) {
            LibrarySidebar()
                .navigationSplitViewColumnWidth(min: 168, ideal: Metrics.sidebarWidth, max: 240)
        } content: {
            navigator
                .navigationSplitViewColumnWidth(min: 210, ideal: Metrics.navigatorWidth, max: 340)
        } detail: {
            canvas
                // Without this the detail column reports an ideal width derived
                // from its content, SwiftUI sizes the whole window to that ideal,
                // and every attempt to open the window full-screen was quietly
                // clawed back to it. The canvas should take whatever is going.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .inspector(isPresented: inspectorBinding) {
                    InspectorPane()
                        .inspectorColumnWidth(min: 250, ideal: Metrics.inspectorWidth, max: 400)
                }
                // The toolbar goes on the *detail*, and the title on the *split view*,
                // and each has to be where it is.
                //
                // On the split view, the toolbar's controls packed against the sidebar
                // toggle on the first layout pass — opening on top of the navigator and
                // snapping right only when something else forced a re-layout, so the
                // window opened wrong and fixed itself the instant the author touched
                // anything. Declared here they land in the detail column's own toolbar
                // region and are right the first time.
                //
                // The title cannot come with them: `.navigationTitle` on the detail
                // never reaches the window, AppKit falls back to the application's own
                // name, and the window says "StoryLoom" — bisected by the sidebar divider,
                // which is the original bug wearing a different hat (ADR-024).
                .toolbar { toolbar }
        }
        // Empty, not removed. `.toolbar(removing: .title)` hides the title but takes
        // the toolbar's layout with it; an empty title draws nothing and leaves the
        // layout intact. The window's real name is set on the NSWindow, so the Window
        // menu, Mission Control, and the proxy icon still know what this is.
        .navigationTitle("")
        .safeAreaInset(edge: .top, spacing: 0) { banners }
    }

    /// Focus strips the application to a page. Nothing is lost — every pane comes
    /// back exactly as it was, because leaving is as important as arriving.
    private var focusMode: some View {
        EditorCanvas()
            .toolbar(.hidden, for: .windowToolbar)
            .overlay(alignment: .topTrailing) {
                Button {
                    workspace.isFocusMode = false
                } label: {
                    Label { Text("Leave Focus") } icon: { GlyphIcon(glyph: .leaveFocus, size: Icon.toolbar) }
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                .padding(Space.regular)
                .foregroundStyle(.tertiary)
                .help("Leave focus (⌥⌘F)")
                .keyboardShortcut(.escape, modifiers: [])
            }
    }

    @ViewBuilder
    private var navigator: some View {
        Group {
            switch workspace.library {
            case .manuscript: ManuscriptNavigator()
            case .threads: ThreadList()
            case .story: EntityList()
            case .timeline: EventList()
            case .notes: NoteList()
            case .trash: TrashList()
            case .history: SnapshotList()
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var canvas: some View {
        switch workspace.library {
        case .manuscript: EditorCanvas()
        case .threads: ThreadCanvas()
        case .story: EntityDossier()
        case .timeline: EventDetail()
        case .notes: NoteEditor()
        case .trash: TrashDetail()
        case .history: SnapshotDetail()
        }
    }

    // MARK: Toolbar

    /// The spacer is load-bearing, and so is the *absence* of `.primaryAction`.
    ///
    /// The window's title is empty — it is drawn in the sidebar, because a
    /// split-view divider was cutting it in half (ADR-024). With no title item to sit
    /// beside, SwiftUI laid `.primaryAction` out at the leading edge of the toolbar on
    /// the first pass, so the four controls opened *on top of the navigator* and
    /// snapped to the trailing edge only when something else forced a re-layout — the
    /// application opened wrong and then fixed itself the instant the author touched
    /// anything, which is the kind of bug people stop reporting and start working
    /// around. A `ToolbarSpacer` could not reach them either: `.primaryAction` puts
    /// its items in their own section, and a spacer in another section has nothing to
    /// push. One section, one flexible space, and the trailing edge stops being a
    /// consequence of layout order and becomes a fact.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarSpacer(.flexible)

        ToolbarItemGroup {
            Button {
                sheet = .search
            } label: {
                Label { Text("Find in Project") } icon: { GlyphIcon(glyph: .search, size: Icon.toolbar) }
            }
            .help("Find in project (⇧⌘F)")

            Button {
                workspace.createScene()
            } label: {
                Label { Text("New Scene") } icon: { GlyphIcon(glyph: .newScene, size: Icon.toolbar) }
            }
            .help("New scene (⇧⌘N)")

            Button {
                workspace.isInspectorVisible.toggle()
            } label: {
                Label { Text("Inspector") } icon: { GlyphIcon(glyph: .inspector, size: Icon.toolbar) }
            }
            .help("Show or hide the inspector (⌥⌘I)")
            .disabled(workspace.library != .manuscript)

            Menu {
                Button("Command Palette…") { sheet = .palette }
                Button("Enter Focus") { workspace.isFocusMode = true }
                Divider()
                Button("Save Snapshot") { workspace.createSnapshot() }
                Button("Export…") { sheet = .export }
                Divider()
                Button("Reveal in Finder") { revealInFinder() }
                    .disabled(workspace.projectURL == nil)
            } label: {
                Label { Text("More") } icon: { GlyphIcon(glyph: .more, size: Icon.toolbar) }
            }
        }
    }

    // MARK: Banners

    /// The two things that must interrupt: someone else changed the file, and the
    /// last save may not have finished. Everything else waits its turn.
    @ViewBuilder
    private var banners: some View {
        VStack(spacing: 0) {
            if workspace.externalChange != nil {
                Banner(
                    glyph: .saving,
                    tint: Palette.caution,
                    title: "This project changed on disk",
                    message: "Something outside StoryLoom edited these files. Nothing has been overwritten."
                ) {
                    Button("Reload from Disk") { workspace.reloadFromDisk() }
                    Button("Keep My Version") { workspace.keepMyVersion() }
                        .buttonStyle(.borderedProminent)
                }
            }
            if let notice = workspace.recoveryNotice {
                Banner(
                    glyph: .interrupted,
                    tint: Palette.question,
                    title: "A previous save was interrupted",
                    message: notice
                ) {
                    Button("Open History") {
                        workspace.library = .history
                        workspace.recoveryNotice = nil
                    }
                    Button("Dismiss") { workspace.recoveryNotice = nil }
                }
            }
        }
    }

    // MARK: Plumbing

    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: { workspace.isInspectorVisible && workspace.library == .manuscript },
            set: { workspace.isInspectorVisible = $0 }
        )
    }

    private func revealInFinder() {
        guard let url = workspace.projectURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func handle(_ note: Notification) {
        guard let command = note.object as? StoryLoomCommand else { return }
        switch command {
        case .search: sheet = .search
        case .palette: sheet = .palette
        case .export: sheet = .export
        }
    }
}

// MARK: - Sheets

enum WorkspaceSheet: String, Identifiable {
    case search
    case palette
    case export

    var id: String { rawValue }
}

/// Menu-bar commands cannot reach view state directly, so they post instead.
enum StoryLoomCommand {
    case search
    case palette
    case export
}

extension Notification.Name {
    static let storyLoomCommand = Notification.Name("storyloom.command")
}

// MARK: - Banner

private struct Banner<Actions: View>: View {
    let glyph: Glyph
    let tint: Color
    let title: String
    let message: String
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.snug) {
            GlyphIcon(glyph: glyph, size: Icon.banner)
                .foregroundStyle(tint)

            Text(title)
                .font(Chrome.strong)

            Text(message)
                .font(Chrome.small)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: Space.small)

            HStack(spacing: Space.snug) {
                actions
            }
            .controlSize(.small)
        }
        .padding(.horizontal, Space.regular)
        .padding(.vertical, Space.snug)
        .background(.bar)
        .hairlineBorder(.bottom)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Window

/// The window's name, and the fact that it is not drawn.
///
/// A unified toolbar lays the title out from the leading edge — which, in a
/// `NavigationSplitView`, is exactly where the sidebar's divider runs. The divider
/// wins, and the project's name is served cut in half. Nothing in AppKit moves that
/// title, so the answer is to stop asking the title bar to carry the project's
/// identity at all and give it to the sidebar, which has room for it and is where
/// the author is already looking.
///
/// The title itself is set here rather than through `.navigationTitle`, because
/// SwiftUI re-asserts `titleVisibility` every time that modifier's value is
/// re-evaluated — so the title stayed hidden until the author changed rooms, and
/// then reappeared, bisected, exactly as before. The window keeps its name for the
/// Window menu, for Mission Control, and for the proxy icon. It is only not drawn.
/// Also decides what *kind* of window this is.
///
/// The launcher and the workspace share one window, and they want opposite things
/// from it: the workspace wants to be resized and filled, the launcher wants to be
/// a dialog you cannot stretch. So the style mask is set from the mode on every
/// pass rather than once at creation — a window that was locked for the launcher
/// and never unlocked would leave the author unable to resize their manuscript,
/// which is a far worse bug than the one being fixed.
private struct WindowConfigurator: NSViewRepresentable {
    let title: String
    var isDialog = false
    var dialogSize = NSSize(width: 520, height: 430)

    /// Remembers which mode was last applied.
    ///
    /// The mode cannot be inferred from the window itself. Checking whether the
    /// window is resizable looked like it would work and did not: by the time this
    /// runs for the workspace, SwiftUI has already put `.resizable` back, so a
    /// guard on it was always false and the whole branch — including opening the
    /// manuscript full-screen — silently never ran.
    final class Coordinator {
        var applied: Bool?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        configure(later: view, context.coordinator)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        configure(later: view, context.coordinator)
    }

    /// After the current pass, not during it. SwiftUI rebuilds the title bar as part
    /// of the same layout that runs `updateNSView`, and whichever of us goes last
    /// wins — so setting the title synchronously here left it hidden on launch and
    /// visible again the first time the author changed rooms, which is a worse bug
    /// than the one being fixed because it looks like it works.
    private func configure(later view: NSView, _ coordinator: Coordinator) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titlebarSeparatorStyle = .automatic
            window.toolbarStyle = .unified
            window.titleVisibility = .hidden
            if window.title != title { window.title = title }

            guard coordinator.applied != isDialog else { return }
            coordinator.applied = isDialog
            isDialog ? lock(window) : unlock(window)
        }
    }

    /// A launcher is a question, not a window to arrange: fixed size, centred, and
    /// it cannot be dragged off-centre or resized.
    private func lock(_ window: NSWindow) {
        window.styleMask.remove([.resizable, .miniaturizable])
        window.contentMinSize = dialogSize
        window.contentMaxSize = dialogSize
        window.setContentSize(dialogSize)
        window.isMovable = false
        window.isMovableByWindowBackground = false
        window.center()
    }

    /// The book gets the whole screen. Arriving from a 520pt dialog into a merely
    /// adequate window reads as the application having failed to open properly.
    private func unlock(_ window: NSWindow) {
        window.styleMask.insert([.resizable, .miniaturizable])
        window.contentMinSize = NSSize(width: 900, height: 620)
        window.contentMaxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                       height: CGFloat.greatestFiniteMagnitude)
        window.isMovable = true

        guard let screen = window.screen ?? NSScreen.main else { return }
        let full = screen.visibleFrame
        window.setFrame(full, display: true, animate: true)
        // SwiftUI sizes the window from its content after this pass and pulls it
        // back to the split view's ideal width. Re-assert until it stops.
        for delay in [0.05, 0.25, 0.6] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if window.frame.width < full.width - 1 || window.frame.height < full.height - 1 {
                    window.setFrame(full, display: true, animate: false)
                }
            }
        }
    }
}

// MARK: - Prose style environment

private struct ProseStyleKey: EnvironmentKey {
    static let defaultValue = ProseStyle()
}

extension EnvironmentValues {
    var proseStyle: ProseStyle {
        get { self[ProseStyleKey.self] }
        set { self[ProseStyleKey.self] = newValue }
    }
}

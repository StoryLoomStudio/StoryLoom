//
//  StoryLoomApp.swift
//  StoryLoom
//
//  The application. A single window, a real menu bar, and a Settings scene —
//  because "native behavior is product quality" (01-Manifesto) and a writing app
//  that reinvents ⌘Z, ⌘F, or the File menu has made the author's twenty years of
//  muscle memory into a liability.
//

import SwiftUI

@main
struct StoryLoomApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    @StateObject private var settings = AppSettings.shared
    @StateObject private var recents = RecentProjects()
    @StateObject private var workspace: WorkspaceModel

    init() {
        let recents = RecentProjects()
        _recents = StateObject(wrappedValue: recents)
        _workspace = StateObject(wrappedValue: WorkspaceModel(recents: recents))
    }

    var body: some Scene {
        WindowGroup {
            WorkspaceView()
                .environmentObject(workspace)
                .environmentObject(settings)
                .environmentObject(recents)
                .onAppear { delegate.workspace = workspace }
        }
        .defaultSize(width: 1_380, height: 900)
        .commands { AppCommands(workspace: workspace, settings: settings) }

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(recents)
        }
    }
}

/// Autosave debounces by design. Termination does not wait for a debounce, so the
/// last few hundred milliseconds of typing are flushed here — the difference
/// between "no confirmed loss of acknowledged edits" and a promise we broke.
final class AppDelegate: NSObject, NSApplicationDelegate {
    var workspace: WorkspaceModel?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            workspace?.flush()
        }
    }

    /// Handle opening .storyloom files from Finder (double-click or drag-and-drop).
    /// The .storyloom file is the manifest inside a project folder, so we open
    /// the parent directory as the project.
    func application(_ application: NSApplication, open urls: [URL]) {
        MainActor.assumeIsolated {
            guard let url = urls.first, let workspace else { return }
            if url.pathExtension.lowercased() == "storyloom" {
                // The .storyloom file lives inside the project folder.
                workspace.open(url.deletingLastPathComponent())
            } else {
                workspace.open(url)
            }
        }
    }
}

// MARK: - Menu bar

struct AppCommands: Commands {
    @ObservedObject var workspace: WorkspaceModel
    @ObservedObject var settings: AppSettings

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Project…") { workspace.newProject() }
                .keyboardShortcut("n", modifiers: [.command, .shift, .option])

            Button("New Scene") { workspace.createScene() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(!workspace.hasProject)

            Button("New Thread") { workspace.openThreadHere() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                .disabled(!workspace.hasProject)

            Button("New Note") { workspace.createScene(kind: .note) }
                .disabled(!workspace.hasProject)

            Divider()

            Button("Open Project…") { workspace.openProject() }
                .keyboardShortcut("o", modifiers: .command)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") { workspace.save() }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!workspace.hasProject)

            Button("Save a Point in History") { workspace.createSnapshot() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!workspace.hasProject)

            Divider()

            Button("Export…") { post(.export) }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(!workspace.hasProject)
        }

        // Emphasis has a menu item and a shortcut because it is an edit, and every
        // edit in a Mac application is reachable from the menu bar. It was reachable
        // only from a bar that floats over a selection, which meant an author with
        // the caret in a word — the overwhelmingly common case — could not reach it
        // at all.
        CommandMenu("Format") {
            Button("Strong") { workspace.toggleFormat(.strong) }
                .keyboardShortcut("b", modifiers: .command)
                .disabled(!isWriting)

            Button("Emphasis") { workspace.toggleFormat(.emphasis) }
                .keyboardShortcut("i", modifiers: .command)
                .disabled(!isWriting)

            Button("Highlight") { workspace.toggleHighlight() }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                .disabled(!isWriting)

            Button("Underline") { workspace.toggleUnderline() }
                .keyboardShortcut("u", modifiers: .command)
                .disabled(!isWriting)

            Button("Strikethrough") { workspace.toggleFormat(.strikethrough) }
                .keyboardShortcut("x", modifiers: [.command, .shift])
                .disabled(!isWriting)

            Divider()

            Button("Quote") { workspace.toggleBlockquote() }
                .keyboardShortcut("'", modifiers: [.command, .control])
                .disabled(!isWriting)

            Button("Insert Scene Break") { workspace.insertSceneBreak() }
                .keyboardShortcut("-", modifiers: [.command, .shift])
                .disabled(!isWriting)

            Divider()

        }

        // The find bar belongs to the text view. These items just reach it.
        CommandGroup(after: .textEditing) {
            Divider()

            // A comment is an edit to the author's own thinking, so it is in the Edit
            // menu with a shortcut, not only under the right button.
            Button("Add Comment") { workspace.addComment(range: workspace.editorSelection.range) }
                .keyboardShortcut("c", modifiers: [.command, .option])
                .disabled(!isWriting || workspace.editorSelection.isEmpty)

            Divider()

            Button("Find in Scene…") { TextFinder.perform(.showFindInterface) }
                .keyboardShortcut("f", modifiers: .command)

            Button("Find Next") { TextFinder.perform(.nextMatch) }
                .keyboardShortcut("g", modifiers: .command)

            Button("Find Previous") { TextFinder.perform(.previousMatch) }
                .keyboardShortcut("g", modifiers: [.command, .shift])

            Divider()

            Button("Find in Project…") { post(.search) }
                .keyboardShortcut("f", modifiers: [.command, .shift])

            Button("Command Palette…") { post(.palette) }
                .keyboardShortcut("k", modifiers: .command)
        }

        CommandGroup(after: .toolbar) {
            Button(workspace.isFocusMode ? "Leave Focus" : "Enter Focus") {
                workspace.isFocusMode.toggle()
            }
            .keyboardShortcut("f", modifiers: [.command, .option])

            Button(workspace.isInspectorVisible ? "Hide Inspector" : "Show Inspector") {
                workspace.isInspectorVisible.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .option])

            Divider()

            Toggle("Format Bar", isOn: $settings.showsFormatBar)

            Divider()

            Menu("Page") {
                Picker("Paper", selection: $settings.readingTheme) {
                    ForEach(ReadingTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                Picker("Dim Everything But", selection: $settings.focusDepth) {
                    ForEach(FocusDepth.allCases) { depth in
                        Text(depth.title).tag(depth)
                    }
                }
                Toggle("Typewriter Scrolling", isOn: $settings.typewriter)
                Toggle("Tint Dialogue", isOn: $settings.highlightsDialogue)

                Divider()

                Button("Larger Text") { settings.proseSize = min(24, settings.proseSize + 1) }
                    .keyboardShortcut("+", modifiers: .command)
                Button("Smaller Text") { settings.proseSize = max(13, settings.proseSize - 1) }
                    .keyboardShortcut("-", modifiers: .command)
            }

            Divider()

            ForEach(Array(LibraryItem.navigable.enumerated()), id: \.element) { position, item in
                Button("Go to \(item.title)") { workspace.library = item }
                    .keyboardShortcut(KeyEquivalent(Character("\(position + 1)")), modifiers: .command)
            }
        }

        CommandGroup(replacing: .help) {
            Button("StoryLoom Project Format") { revealFormatDocumentation() }
        }
    }

    /// Formatting is an edit to a page, so it is only live when there is a page.
    private var isWriting: Bool {
        workspace.hasProject && workspace.library == .manuscript && workspace.selectedDocumentID != nil
    }

    private func post(_ command: StoryLoomCommand) {
        NotificationCenter.default.post(name: .storyLoomCommand, object: command)
    }

    /// The escape hatch is the product (01-Manifesto). Showing the author their
    /// own Markdown, in Finder, is the most honest help this app can offer.
    private func revealFormatDocumentation() {
        guard let url = workspace.projectURL else {
            NSWorkspace.shared.open(URL(string: "https://commonmark.org")!)
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url.appending(path: "manuscript")])
    }
}

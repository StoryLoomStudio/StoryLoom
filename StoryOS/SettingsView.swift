//
//  SettingsView.swift
//  StoryLoom
//
//  How the page looks is the author's decision, not the project's: none of this
//  is written into the .storyloom package (12-UI). Typography, contrast, measure,
//  and distraction reduction are all configurable "without changing the project's
//  authored formatting" (11-UX, accessibility).
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            PageSettings()
                .tabItem { Label { Text("Page") } icon: { Glyph.richTextFile.menuImage(size: Icon.control) } }
            CompositionSettings()
                .tabItem { Label { Text("Writing") } icon: { Glyph.annotate.menuImage(size: Icon.control) } }
            GeneralSettings()
                .tabItem { Label { Text("General") } icon: { Glyph.settings.menuImage(size: Icon.control) } }
        }
        .frame(width: 560, height: 460)
    }
}

// MARK: - Page

private struct PageSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Picker("Face", selection: $settings.proseFace) {
                        ForEach(ProseFace.available) { face in
                            Text(face.title).tag(face)
                        }
                    }

                    LabeledContent("Size") {
                        HStack {
                            Slider(value: $settings.proseSize, in: 13...24, step: 1)
                            Text("\(Int(settings.proseSize))")
                                .font(.system(size: 11))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                        }
                    }

                    Picker("Line height", selection: $settings.lineHeight) {
                        ForEach(LineHeight.allCases) { height in
                            Text(height.title).tag(height)
                        }
                    }

                    Picker("Paragraphs", selection: $settings.paragraphLayout) {
                        ForEach(ParagraphLayout.allCases) { layout in
                            Text(layout.title).tag(layout)
                        }
                    }

                    Picker("Line length", selection: $settings.measure) {
                        ForEach(Measure.allCases) { measure in
                            Text(measure.title).tag(measure)
                        }
                    }
                    Picker("Canvas view", selection: $settings.viewMode) {
                        ForEach(PageViewMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                } header: {
                    Text("Typography")
                } footer: {
                    Text("These change how you see the manuscript. They never change what is in it.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Section("Colour") {
                    Picker("Paper", selection: $settings.readingTheme) {
                        ForEach(ReadingTheme.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
                    Picker("Application", selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.title).tag(appearance)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            PagePreview()
                .frame(height: 132)
        }
    }
}

/// A real sample of the real page. Choosing a typeface from a dropdown label is
/// choosing blind.
private struct PagePreview: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var colorScheme

    private var style: ProseStyle { settings.proseStyle(appearance: colorScheme) }

    var body: some View {
        let font = style.face.font(size: style.size)

        ScrollView {
            Text("She kept one hand on the wet stones of the quay. Behind her the town had already decided the storm was over.")
                .font(Font(font))
                .lineSpacing((style.lineHeight.multiple - 1) * style.size)
                .foregroundStyle(Color(nsColor: style.inkColor))
                .frame(maxWidth: 420, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(Space.regular)
        }
        .background(Color(nsColor: style.pageColor))
    }
}

// MARK: - Writing

private struct CompositionSettings: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("Dim everything but", selection: $settings.focusDepth) {
                    ForEach(FocusDepth.allCases) { depth in
                        Text(depth.title).tag(depth)
                    }
                }
                Toggle("Typewriter scrolling", isOn: $settings.typewriter)
                Toggle("Tint dialogue", isOn: $settings.highlightsDialogue)
            } header: {
                Text("Concentration")
            } footer: {
                Text("Typewriter scrolling keeps the line you are writing in the same place on screen. Dialogue tinting makes the shape of a scene's speech visible at a glance.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Check spelling", isOn: $settings.checksSpelling)
                Toggle("Check grammar", isOn: $settings.checksGrammar)
                Toggle("Smart quotes", isOn: $settings.smartQuotes)
                Toggle("Smart dashes", isOn: $settings.smartDashes)
            } header: {
                Text("Text")
            } footer: {
                Text("Autocorrect is never on. A novelist invents words, and a tool that quietly fixes them is working against the book.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var recents: RecentProjects

    var body: some View {
        Form {
            Section("On launch") {
                Toggle("Reopen the last project", isOn: $settings.reopensLastProject)
            }

            Section {
                if recents.entries.isEmpty {
                    Text("No recent projects.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recents.entries) { entry in
                        HStack(alignment: .center, spacing: Space.medium) {
                            GlyphIcon(glyph: .folder, size: Icon.control)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.name)
                                    .font(.system(size: 12, weight: .medium))
                                Text(entry.path)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .truncationMode(.head)
                            }
                            Spacer()
                            Button {
                                recents.forget(entry)
                            } label: {
                                GlyphIcon(glyph: .clear, size: Icon.control)
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                            .help("Forget project")
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                Text("Recent projects")
            } footer: {
                Text("Forgetting a project revokes StoryLoom's permission to open it without asking you again. It does not touch the files.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Reset page to defaults") { settings.resetPage() }
            }
        }
        .formStyle(.grouped)
    }
}

//
//  StartScreen.swift
//  StoryLoom
//
//  What the application is before it is holding a book.
//
//  It used to launch straight into a sample manuscript. That is a demo, not a
//  first run: the first thing an author saw was somebody else's novel, the first
//  decision they had to make was how to get rid of it, and there was no moment
//  at which the application asked what they actually wanted to do.
//
//  So it opens on nothing, and says so — two choices, and the work they had open
//  last time. Everything here is a door; none of it is a tour.
//

import SwiftUI

struct StartScreen: View {
    @EnvironmentObject private var workspace: WorkspaceModel
    @EnvironmentObject private var recents: RecentProjects
    @EnvironmentObject private var settings: AppSettings

    /// The mark's own two colours, lifted from `storyloom.svg` so the launcher and
    /// the app icon are demonstrably the same green rather than approximately it.
    private static let brandDeep = Color(hex: 0x02AAB0)
    private static let brandLit = Color(hex: 0x00CDAC)

    /// How big the window should be to hold this without dead space below the
    /// buttons. A launcher with nothing to reopen is two choices and no list, and
    /// should not pretend otherwise by leaving a third of itself empty.
    static func preferredSize(recentCount: Int) -> NSSize {
        let width: CGFloat = 520
        guard recentCount > 0 else { return NSSize(width: width, height: 430) }
        let rows = CGFloat(min(recentCount, 5))
        return NSSize(width: width, height: 430 + 64 + rows * 44)
    }

    var body: some View {
        VStack(spacing: 0) {
            masthead

            VStack(spacing: Space.small) {
                StartAction(
                    title: "New Project…",
                    detail: "A folder of Markdown, readable in twenty years.",
                    symbol: "plus.rectangle.on.folder",
                    isProminent: true
                ) { workspace.newProject() }

                StartAction(
                    title: "Open Project…",
                    detail: "An existing StoryLoom project folder.",
                    symbol: "folder"
                ) { workspace.openProject() }
            }
            .padding(.top, Space.section)
            .padding(.horizontal, Space.section)

            if openable.isEmpty {
                Spacer(minLength: 0)
            } else {
                recent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(backdrop)
    }

    /// A wash of the brand green, strongest behind the mark and gone by the time it
    /// reaches the buttons. It is the only colour on the surface, which is what
    /// lets it carry the identity without anything else having to shout.
    private var backdrop: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [Self.brandLit.opacity(0.10), Self.brandDeep.opacity(0.03), .clear],
                startPoint: .top,
                endPoint: .center
            )
        }
        .ignoresSafeArea()
    }

    // MARK: The mark

    private var masthead: some View {
        VStack(spacing: 0) {
            ZStack {
                // A bloom behind the icon rather than a border around it: the mark
                // is already a rounded square, and ringing it would draw a second
                // edge a few points outside the first.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Self.brandLit.opacity(0.38), Self.brandDeep.opacity(0.10), .clear],
                            center: .center,
                            startRadius: 2,
                            endRadius: 104
                        )
                    )
                    .frame(width: 232, height: 232)
                    .blur(radius: 18)

                Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 92, height: 92)
                    .shadow(color: Self.brandDeep.opacity(0.42), radius: 22, y: 10)
                    .shadow(color: .black.opacity(0.10), radius: 3, y: 1)
            }
            .frame(height: 150)
            .accessibilityHidden(true)

            // Serif, because the thing being made here is a book. The chrome
            // elsewhere is the system face; this is the one surface that is
            // allowed to say what the application is for.
            Text("StoryLoom")
                .font(.system(size: 33, weight: .semibold, design: .serif))
                .kerning(0.4)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.primary, Color.primary.opacity(0.78)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text("A place to keep a long story straight.")
                .font(.system(size: 12.5))
                .kerning(0.1)
                .foregroundStyle(.secondary)
                .padding(.top, Space.snug)

            // A short rule instead of a full-width divider — it closes the
            // masthead without cutting the dialog in two.
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.clear, Self.brandDeep.opacity(0.45), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 148, height: 1)
                .padding(.top, Space.large)
        }
        .padding(.top, Space.large)
    }

    // MARK: What you had open

    private var openable: [RecentProjects.Entry] {
        recents.entries.filter(\.exists)
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionLabel("Recent")
                Spacer()
                Button("Clear") { recents.clear() }
                    .buttonStyle(.link)
                    .font(Chrome.small)
            }
            .padding(.horizontal, Space.section)
            .padding(.bottom, Space.snug)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(openable) { entry in
                        RecentRow(entry: entry) { workspace.openRecent(entry) }
                    }
                }
                .padding(.horizontal, Space.wide)
            }
            .frame(maxHeight: .infinity)

            Divider()

            Toggle("Reopen on launch", isOn: $settings.reopensLastProject)
                .toggleStyle(.checkbox)
                .font(Chrome.small)
                .padding(.horizontal, Space.section)
                .padding(.vertical, Space.medium)
        }
        .padding(.top, Space.wide)
    }
}

/// One of the two doors. Big enough to be the answer to "what now?".
private struct StartAction: View {
    let title: String
    let detail: String
    let symbol: String
    var isProminent = false
    let action: () -> Void

    @State private var hovering = false

    /// The mark's green, so hovering the primary door feels like the app rather
    /// than like the system accent colour of whoever is using it.
    private var tint: Color { Color(hex: 0x02AAB0) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.regular) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(isProminent ? AnyShapeStyle(tint) : AnyShapeStyle(.secondary))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Chrome.textStrong)
                    Text(detail)
                        .font(Chrome.small)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: Icon.hint, weight: .semibold))
                    .foregroundStyle(hovering ? AnyShapeStyle(.secondary) : AnyShapeStyle(.quaternary))
            }
            .padding(.vertical, Space.regular + 2)
            .padding(.horizontal, Space.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Radius.panel + 2, style: .continuous)
                    .fill(hovering
                          ? AnyShapeStyle(tint.opacity(0.10))
                          : AnyShapeStyle(Palette.subtleFill))
            }
            .overlay {
                RoundedRectangle(cornerRadius: Radius.panel + 2, style: .continuous)
                    .strokeBorder(hovering ? tint.opacity(0.38) : Palette.hairline, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel("\(title). \(detail)")
    }
}

private struct RecentRow: View {
    let entry: RecentProjects.Entry
    let action: () -> Void

    @EnvironmentObject private var recents: RecentProjects
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.name)
                    .font(Chrome.body)
                    .lineLimit(1)
                Text(entry.url.deletingLastPathComponent().path.abbreviatingHome)
                    .font(Chrome.small)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Space.snug)
            .padding(.horizontal, Space.small)
            .background {
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .fill(hovering ? Palette.subtleFill : .clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([entry.url])
            }
            Divider()
            Button("Remove from Recent") { recents.forget(entry) }
        }
    }
}

private extension String {
    var abbreviatingHome: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return hasPrefix(home) ? "~" + dropFirst(home.count) : self
    }
}

//
//  Theme.swift
//  StoryLoom
//
//  The visual system.
//
//  StoryLoom is a tool somebody sits inside for eight hours. That single fact
//  decides everything below it. An application used for eight minutes can afford
//  to be spacious, because its job is to explain itself; an application used for
//  eight hours must be *dense*, because its job is to get out of the way and the
//  author has long since stopped needing the explanation. Padding that reads as
//  generous on a landing page reads, on the four hundredth scene, as a list that
//  will not show you your own book.
//
//  So: chrome is small, rows are short, containers have no edges, and colour is
//  reserved for durable categories (12-UI). The one thing that is *not* compressed
//  is the page — the measure, the leading, and the prose face are reading
//  decisions, and a novelist's eyes are the resource being protected there.
//

import AppKit
import SwiftUI

// MARK: - Metrics

/// Spacing scale. Every gap in the application comes from here, so density is a
/// property of the system rather than of whoever wrote the view last.
///
/// These are desktop numbers, not web numbers. The largest gap in the application
/// is 24pt and it is used between the sections of a full canvas; the gap between
/// two fields is 6.
enum Space {
    static let hair: CGFloat = 2
    static let tight: CGFloat = 4
    static let snug: CGFloat = 6
    static let small: CGFloat = 8
    static let medium: CGFloat = 10
    static let regular: CGFloat = 12
    static let large: CGFloat = 16
    static let wide: CGFloat = 20
    /// Between the sections of a canvas. A canvas is *read*, and the gap is what
    /// tells the eye that one group has ended and another has begun.
    static let section: CGFloat = 26
    /// A canvas's own margins.
    static let page: CGFloat = 32
}

enum Radius {
    static let control: CGFloat = 5
    static let panel: CGFloat = 8
}

/// Symbol sizes.
///
/// Density is the point of this application, but density is about *rows* — how
/// many scenes fit on a screen — and a symbol is not a row. Drawn at the same
/// size as the caption beside it, a symbol reads as punctuation: it stops being
/// something you can aim at and starts being something you have to look for. So
/// the type scale stays where it is and symbols sit a step above it, which is
/// also what every Mac toolbar does.
///
/// Three sizes, and they exist so there is one place to change this again.
enum Icon {
    /// A control the pointer aims at: a format-bar button, a strip's action.
    static let control: CGFloat = 14
    /// Beside a row's text — a status mark, a thread symbol, a kind.
    static let inline: CGFloat = 12
    /// A chevron or a hairline indicator; the smallest symbol drawn.
    static let hint: CGFloat = 10
    /// The symbol on an empty state, which is the only decorative one.
    static let display: CGFloat = 26

    /// The square a `control` symbol is centred in. Comfortably past the 24pt
    /// the HIG asks of a pointer target.
    static let controlHit = CGSize(width: 28, height: 24)

    /// The room symbols in the sidebar, which are aimed at rather than read.
    static let room: CGFloat = 18

    /// A thread's kind, wherever it appears — the list row, the header button,
    /// and the menus that change it.
    ///
    /// Smaller than `inline`, and deliberately. These nine glyphs are the most
    /// detailed drawings in the application — crossed swords, a sprout, two hands
    /// — so at a size that suits a status dot they read as illustrations sitting
    /// next to the text rather than as marks belonging to it.
    static let threadKind: CGFloat = 14

    /// Lucide draws on a 24pt grid and fills nearly all of it, where an SF Symbol
    /// leaves optical margin inside its own box. Set to the same point size the
    /// two are not the same weight — the Lucide glyph reads a size larger and a
    /// shade heavier. This is the correction, applied in one place so the type
    /// scale above never has to be bent around whichever icon set is in use.
    static let lucideScale: CGFloat = 0.88
}

/// A vendored Lucide icon.
///
/// The raw value does three jobs at once: it is the file this was taken from in
/// `icons/`, the imageset in `Assets.xcassets`, and the name Lucide itself uses.
/// One name for all three means there is no lookup table to drift out of date,
/// and re-vendoring an icon is a file copy rather than an edit.
///
/// The case names are the application's vocabulary, not Lucide's, so call sites
/// read as what they mean — `.foreshadowing`, not `.eclipse`.
enum Glyph: String, Hashable, Sendable {
    // The rooms
    case manuscript = "book"
    case story = "library"
    case timeline = "chart-no-axes-gantt"
    case threads = "workflow"
    case notes = "list-plus"
    case trash = "trash-2"
    case history = "rotate-ccw-clock"

    // What kind of pull a thread exerts
    case mystery = "circle-question-mark"
    case promise = "handshake"
    case threat = "triangle-alert"
    case goal = "target"
    case relationship = "heart-handshake"
    case characterArc = "sprout"
    case foreshadowing = "eclipse"
    case conflict = "swords"
    case theme = "lightbulb"

    case search
}

/// Where an icon comes from: the system's symbol set, or ours.
///
/// This exists because the alternative was in the codebase and was rotting. Any
/// view that could show either kind carried a copy of the same predicate —
/// `symbol == "timeline" || symbol == "notes" || symbol == "history"` — written
/// out longhand in three files. Adding a vendored icon meant remembering all
/// three, and renaming one silently turned it back into a missing SF Symbol,
/// which fails by drawing nothing rather than by failing to compile.
///
/// A value that knows which it is cannot be got wrong.
nonisolated enum IconSource: Hashable, Sendable {
    case system(String)
    case glyph(Glyph)
}

/// Draws either kind at one size, correcting for Lucide's heavier grid.
struct IconView: View {
    let source: IconSource
    var size: CGFloat = Icon.control

    init(_ source: IconSource, size: CGFloat = Icon.control) {
        self.source = source
        self.size = size
    }

    var body: some View {
        switch source {
        case .system(let name):
            Image(systemName: name).font(.system(size: size))
        case .glyph(let glyph):
            GlyphIcon(glyph: glyph, size: size)
        }
    }
}

/// A `Glyph` drawn at a size from the `Icon` scale.
///
/// An asset-catalog image has an intrinsic size and ignores `.font`, which is
/// how these first landed in the sidebar at their full 24pt while the SF Symbols
/// beside them sat at 14. Sizing therefore has to be explicit, and belongs here
/// rather than at every call site.
struct GlyphIcon: View {
    let glyph: Glyph
    var size: CGFloat = Icon.control

    var body: some View {
        Image(glyph.rawValue)
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size * Icon.lucideScale, height: size * Icon.lucideScale)
    }
}

extension Glyph {
    /// The same glyph, for a menu.
    ///
    /// `GlyphIcon` is laid out by SwiftUI and obeys its frame everywhere except
    /// inside a `Menu`, where AppKit does the drawing: it rasterises the icon and
    /// scales it to the menu's own image size, and a `.frame` is simply ignored.
    /// Measured, that put these glyphs at 22pt beside 11pt text — twice the size
    /// asked for, which is what made the kind menu look wrong.
    ///
    /// An `NSImage` carries its size as a property rather than as a layout
    /// constraint, and `NSMenuItem` honours it. So in menus the icon has to be
    /// *built* at the right size instead of being asked to lay out at one.
    func menuImage(size: CGFloat = Icon.threadKind) -> Image {
        let side = size * Icon.lucideScale
        guard let named = NSImage(named: rawValue) else { return Image(rawValue) }

        // Setting `.size` on the catalog image is not enough — it keeps a vector
        // representation and re-renders from that at whatever size the menu
        // decides, which measured 22pt: the SVG's intrinsic 24pt, not the 9.7pt
        // asked for. Drawing it into a new image of the right size bakes the
        // dimension into the artwork, leaving the menu nothing to override.
        let sized = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            named.draw(in: rect)
            return true
        }
        sized.isTemplate = true
        return Image(nsImage: sized)
    }
}

enum Metrics {
    /// Fixed utility-pane widths. Stable geometry is calmer than elastic panes.
    static let sidebarWidth: CGFloat = 196
    static let navigatorWidth: CGFloat = 258
    static let inspectorWidth: CGFloat = 288
    static let minimumCanvasWidth: CGFloat = 480

    /// One line of text and its metadata. A novelist scanning five hundred scenes
    /// should see thirty at a time, not fourteen — so a row is a row, not a card,
    /// and everything that does not fit on one line was not worth a second one.
    static let row: CGFloat = 24
    /// A strip of chrome: the filter bar, the scene's jump bar, the status line.
    /// Tall enough to hold `Icon.controlHit` with air around it.
    static let strip: CGFloat = 32
    /// The label column of an inspector grid, right-aligned against its values,
    /// which is how every professional Mac inspector has been built for twenty years.
    /// Wide enough for the longest label the application actually uses — "Also
    /// called" — because a label that wraps is a column that has stopped being one.
    static let labelColumn: CGFloat = 66
    /// A canvas that is mostly prose rather than controls.
    static let readingWidth: CGFloat = 640
    /// A canvas that is a record — a name, a table of facts, sections of evidence.
    /// Wider than a reading measure, because it has columns to lay out and the
    /// alternative is three of them stacked down one side of an empty page.
    static let canvasWidth: CGFloat = 780
}

// MARK: - Chrome typography

/// Two scales, because there are two kinds of surface and they are not the same job.
///
/// **Furniture** — navigators, strips, the inspector — is *scanned*. The eye finds a
/// scene by the shape of a row and looks straight past everything else, so the type
/// is small, there is a lot of it on screen, and every extra size is one more shape
/// to learn before you can skip.
///
/// **A canvas** — a character, an event, a thread, a finding — is *read*. It is the
/// thing the author came to the room for, it has the whole width of the window, and
/// squeezing it to the furniture's measurements does not make it dense. It makes it
/// a heap. So a canvas gets a step up in size, air between its groups, and a rule to
/// say where one ends.
///
/// The manuscript itself is in neither scale: the prose face is the author's, and it
/// lives in `ProseFace`.
enum Chrome {

    // Furniture.

    /// A row, a value, a field. The default.
    static let body = Font.system(size: 12)
    /// A row that needs to win over the one beside it.
    static let strong = Font.system(size: 12, weight: .semibold)
    /// Everything secondary: counts, timestamps, the left column of a grid.
    static let small = Font.system(size: 11)
    /// Group labels, set in caps. The smallest thing StoryLoom will draw.
    static let micro = Font.system(size: 10, weight: .medium)

    // A canvas.

    /// The subject of the page: a character's name, an event, a note.
    static let display = Font.system(size: 26, weight: .semibold)
    /// A section of it.
    static let heading = Font.system(size: 13, weight: .semibold)
    /// What the author wrote, on a surface built to be read.
    static let text = Font.system(size: 13)
    static let textStrong = Font.system(size: 13, weight: .medium)
    /// Beside it: a chapter, a count, a date.
    static let meta = Font.system(size: 11.5)
}

// MARK: - Motion

/// Restrained animation preserves spatial continuity (12-UI). Every animation in
/// the app routes through here so Reduce Motion is honoured in exactly one place.
enum Motion {
    static let quick = Animation.easeOut(duration: 0.14)
    static let standard = Animation.easeInOut(duration: 0.2)
    static let emphasized = Animation.spring(response: 0.34, dampingFraction: 0.86)

    /// Returns `nil` when the system asks for reduced motion, which makes
    /// `withAnimation(Motion.respecting(.standard, reduceMotion))` a no-op.
    static func respecting(_ animation: Animation, _ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}

// MARK: - Semantic colour

/// Colour is reserved for durable categories and is always paired with a label
/// or symbol, never used as the sole status cue (10-Editor, 12-UI).
///
/// `nonisolated` because the model layer owns these categories: a finding's
/// severity and a scene's status carry their own tint, and both are computed off
/// the main actor while the index is rebuilt.
nonisolated enum Palette {
    /// A question worth the author's attention. Never an error.
    static let question = Color(nsColor: .systemTeal)
    /// A caution: the system sees tension but the author may have meant it.
    static let caution = Color(nsColor: .systemOrange)
    /// A hard contradiction between two author-confirmed records.
    static let conflict = Color(nsColor: .systemRed)
    /// Author-confirmed and settled.
    static let confirmed = Color(nsColor: .systemGreen)
    /// Deliberate ambiguity: the author has told the system to stop asking.
    static let intentional = Color(nsColor: .systemPurple)

    static let hairline = Color.primary.opacity(0.07)
    static let subtleFill = Color.primary.opacity(0.045)
    static let hoverFill = Color.primary.opacity(0.06)
    /// The chronology thread on the timeline. Heavier than a hairline because it
    /// carries meaning — it is the sequence itself — rather than dividing a pane.
    static let thread = Color.primary.opacity(0.16)
}

// MARK: - Surfaces

extension View {
    /// The chrome surface used by navigator/inspector utility panes.
    func utilitySurface() -> some View {
        background(Color(nsColor: .underPageBackgroundColor))
    }

    /// A hairline rule that reads as structure rather than decoration.
    func hairlineBorder(_ edges: Edge.Set = .all, radius: CGFloat = 0) -> some View {
        overlay {
            if radius > 0 {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 1)
            }
        }
        .overlay(alignment: .leading) { rule(if: edges.contains(.leading), vertical: true) }
        .overlay(alignment: .trailing) { rule(if: edges.contains(.trailing), vertical: true) }
        .overlay(alignment: .top) { rule(if: edges.contains(.top), vertical: false) }
        .overlay(alignment: .bottom) { rule(if: edges.contains(.bottom), vertical: false) }
    }

    @ViewBuilder
    private func rule(if condition: Bool, vertical: Bool) -> some View {
        if condition {
            Rectangle()
                .fill(Palette.hairline)
                .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
        }
    }
}

// MARK: - Reading themes

/// The paper the author writes on. This is deliberately separate from the app's
/// appearance: a writer may want a warm page inside a dark application.
nonisolated enum ReadingTheme: String, CaseIterable, Identifiable, Sendable {
    case system
    case paper
    case sepia
    case night
    case ink

    nonisolated var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Match System"
        case .paper: "Paper"
        case .sepia: "Sepia"
        case .night: "Night"
        case .ink: "Ink"
        }
    }

    /// The writing surface. AppKit colours are canonical here because the editor
    /// is an NSTextView; SwiftUI surfaces wrap these rather than redefining them.
    func pageColor(for appearance: ColorScheme) -> NSColor {
        switch self {
        case .system: NSColor.textBackgroundColor.resolved(for: appearance)
        case .paper: appearance == .dark ? NSColor(hex: 0x1B1A17) : NSColor(hex: 0xFCFBF8)
        case .sepia: appearance == .dark ? NSColor(hex: 0x211C15) : NSColor(hex: 0xF4ECD9)
        case .night: NSColor(hex: 0x1C1D1F)
        case .ink: NSColor(hex: 0x0B0B0C)
        }
    }

    /// Prose colour. Pure black on pure white is harsher than any printed book.
    func inkColor(for appearance: ColorScheme) -> NSColor {
        switch self {
        case .system: NSColor.textColor.resolved(for: appearance)
        case .paper: appearance == .dark ? NSColor(hex: 0xE6E1D6) : NSColor(hex: 0x25221C)
        case .sepia: appearance == .dark ? NSColor(hex: 0xE0D3B8) : NSColor(hex: 0x453923)
        case .night: NSColor(hex: 0xD7D4CE)
        case .ink: NSColor(hex: 0xC8C6C1)
        }
    }

    /// Markdown markers, dimmed passages in focus mode, and secondary page text.
    func mutedInkColor(for appearance: ColorScheme) -> NSColor {
        inkColor(for: appearance).withAlphaComponent(0.36)
    }

    /// The caret. It should read as the author's own presence on the page.
    func caretColor(for appearance: ColorScheme) -> NSColor {
        switch self {
        case .system: NSColor.textColor.resolved(for: appearance)
        default: NSColor.controlAccentColor.resolved(for: appearance)
        }
    }

    func page(for appearance: ColorScheme) -> Color { Color(nsColor: pageColor(for: appearance)) }
    func ink(for appearance: ColorScheme) -> Color { Color(nsColor: inkColor(for: appearance)) }
    func mutedInk(for appearance: ColorScheme) -> Color { Color(nsColor: mutedInkColor(for: appearance)) }

    /// Whether the theme forces a dark page regardless of application appearance.
    /// A writer may legitimately want a dark page inside a light app, or the reverse.
    var forcesDarkPage: Bool {
        self == .night || self == .ink
    }

    /// The appearance the page should be evaluated against.
    func effectiveAppearance(_ system: ColorScheme) -> ColorScheme {
        forcesDarkPage ? .dark : system
    }
}

// MARK: - Prose typography

/// Faces offered for the manuscript. Chrome always uses the system face; only
/// the page is the author's to choose (12-UI).
nonisolated enum ProseFace: String, CaseIterable, Identifiable, Sendable {
    case newYork
    case iowan
    case palatino
    case baskerville
    case georgia
    case system
    case mono

    nonisolated var id: String { rawValue }

    var title: String {
        switch self {
        case .newYork: "New York"
        case .iowan: "Iowan Old Style"
        case .palatino: "Palatino"
        case .baskerville: "Baskerville"
        case .georgia: "Georgia"
        case .system: "System Sans"
        case .mono: "Monospace"
        }
    }

    /// Named faces are not guaranteed to exist on every machine; fall back to a
    /// designed system font rather than letting AppKit substitute silently.
    func font(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        switch self {
        case .newYork:
            return Self.designedSystemFont(size: size, weight: weight, design: .serif)
        case .system:
            return NSFont.systemFont(ofSize: size, weight: weight)
        case .mono:
            return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        case .iowan, .palatino, .baskerville, .georgia:
            if let named = NSFont(name: postScriptName(weight: weight), size: size) {
                return named
            }
            return Self.designedSystemFont(size: size, weight: weight, design: .serif)
        }
    }

    private func postScriptName(weight: NSFont.Weight) -> String {
        let bold = weight >= .semibold
        switch self {
        case .iowan: return bold ? "IowanOldStyle-Bold" : "IowanOldStyle-Roman"
        case .palatino: return bold ? "Palatino-Bold" : "Palatino-Roman"
        case .baskerville: return bold ? "Baskerville-Bold" : "Baskerville"
        case .georgia: return bold ? "Georgia-Bold" : "Georgia"
        default: return ""
        }
    }

    private static func designedSystemFont(size: CGFloat, weight: NSFont.Weight, design: NSFontDescriptor.SystemDesign) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(design) else { return base }
        return NSFont(descriptor: descriptor, size: size) ?? base
    }

    /// True when the face is installed, so Settings can hide what will not render.
    var isAvailable: Bool {
        switch self {
        case .newYork, .system, .mono: return true
        case .iowan, .palatino, .baskerville, .georgia:
            return NSFont(name: postScriptName(weight: .regular), size: 12) != nil
        }
    }

    static var available: [ProseFace] { allCases.filter(\.isAvailable) }
}

/// How much of the page a paragraph is allowed to cross. Long lines are the most
/// common typographic failure in writing apps; the measure is capped in characters.
nonisolated enum Measure: String, CaseIterable, Identifiable, Sendable {
    case narrow
    case comfortable
    case wide

    nonisolated var id: String { rawValue }

    var title: String {
        switch self {
        case .narrow: "Narrow"
        case .comfortable: "Comfortable"
        case .wide: "Wide"
        }
    }

    /// Target characters per line. 60–75 is the readable band for continuous prose.
    var characters: CGFloat {
        switch self {
        case .narrow: 58
        case .comfortable: 68
        case .wide: 82
        }
    }

    /// Points of text width for a given face, derived from the font's own metrics
    /// rather than a guessed multiplier.
    ///
    /// The sample is running prose, not an alphabet: capitals are rare in a novel
    /// and an A–Z sample overstates the average advance by around a quarter, which
    /// is the difference between a comfortable measure and a punishing one.
    func width(for font: NSFont) -> CGFloat {
        let sample = "She kept one hand on the wet stones of the quay, and the quick brown fox jumped over the lazy dog."
        let advance = (sample as NSString).size(withAttributes: [.font: font]).width / CGFloat(sample.count)
        return (advance * characters).rounded()
    }
}

/// Dimming everything but the passage in play. Off by default: the manifesto
/// prefers quiet defaults, and dimming is a deliberate act of concentration.
nonisolated enum FocusDepth: String, CaseIterable, Identifiable, Sendable {
    case off
    case paragraph
    case sentence

    nonisolated var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "Off"
        case .paragraph: "Paragraph"
        case .sentence: "Sentence"
        }
    }
}

// MARK: - Colour helpers

extension Color {
    nonisolated init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension NSColor {
    nonisolated convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    /// This colour, made concrete against the appearance the *page* is using.
    ///
    /// System colours are dynamic: `NSColor.textColor` is a catalog entry that is
    /// still undecided when you hold it, and becomes black or white only at the
    /// moment it is drawn, against whatever appearance is current then. Left alone
    /// that is exactly right — body prose is written with the catalog colour and
    /// resolves correctly inside the text view.
    ///
    /// Reading one *here* is what breaks. Taking 36% of it for a dimmed marker, or
    /// blending it for dialogue, forces it to decide early — and it decides against
    /// the appearance current on the application, which is not the appearance of
    /// this page. On a light page inside a system running Dark Mode it answers
    /// white, and the styler then writes white text onto white paper: the
    /// blockquote in the sample project rendered as an empty gap, present in the
    /// word count and absent from the page.
    ///
    /// It is also why `blended(withFraction:of:)` returned nil for dialogue tinting
    /// and silently did nothing — a catalog colour has no components to blend until
    /// it has been resolved.
    ///
    /// The page's appearance is not always the window's (Night paper is dark inside
    /// a light app), so this resolves against a stated appearance rather than the
    /// ambient one.
    nonisolated func resolved(for appearance: ColorScheme) -> NSColor {
        let name: NSAppearance.Name = appearance == .dark ? .darkAqua : .aqua
        guard let target = NSAppearance(named: name) else { return self }
        var resolved = self
        target.performAsCurrentDrawingAppearance {
            resolved = self.usingColorSpace(.sRGB) ?? self
        }
        return resolved
    }
}

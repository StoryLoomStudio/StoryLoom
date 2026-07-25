//
//  ProseStyler.swift
//  StoryLoom
//
//  Turns Markdown-backed prose into a page. 10-Editor asks the editor to
//  "protect the author from markup noise during composition" while keeping the
//  source exact: so the markers stay in the text and are merely dimmed, the
//  emphasis renders as emphasis, and nothing is rewritten on open or save.
//
//  Styling is split deliberately:
//    * Real attributes  — typography and Markdown. Recomputed per paragraph.
//    * Temporary attrs  — focus dimming and highlights. Display-only, never
//                         touch the text storage, never dirty the document.
//

import AppKit
import SwiftUI

// MARK: - Attributes the page keeps to itself

extension NSAttributedString.Key {
    /// A Markdown marker with no glyph. The layout manager reads this and draws
    /// nothing for those characters — they stay in the text, which is the file, but
    /// they leave the page. The value is a `MarkerSide`.
    nonisolated static let marker = NSAttributedString.Key("StoryLoomMarker")
    /// The emphasis a run of prose is carrying, as a bitmask of `InlineFormat.bit`.
    /// It is how the format bar knows whether B is lit without parsing anything.
    nonisolated static let inlineFormat = NSAttributedString.Key("StoryLoomInlineFormat")
    /// Flags a paragraph run as a blockquote for layout accent drawing.
    nonisolated static let blockquote = NSAttributedString.Key("StoryLoomBlockquote")
}

// MARK: - Configuration

/// How paragraphs sit on the page. Both are legitimate; novelists disagree.
nonisolated enum ParagraphLayout: String, CaseIterable, Identifiable, Sendable {
    /// Indented first line, no gap — how a printed novel sets prose.
    case indented
    /// No indent, a gap between paragraphs — how a screen sets prose.
    case spaced

    nonisolated var id: String { rawValue }

    var title: String {
        switch self {
        case .indented: "Indented"
        case .spaced: "Spaced"
        }
    }
}

nonisolated enum LineHeight: String, CaseIterable, Identifiable, Sendable {
    case tight
    case normal
    case relaxed
    case double

    nonisolated var id: String { rawValue }

    var title: String {
        switch self {
        case .tight: "Tight"
        case .normal: "Normal"
        case .relaxed: "Relaxed"
        case .double: "Double"
        }
    }

    var multiple: CGFloat {
        switch self {
        case .tight: 1.2
        case .normal: 1.45
        case .relaxed: 1.7
        case .double: 2.0
        }
    }
}

/// Everything the page needs to render itself. Resolved once, then handed to the
/// text view, so the view never reaches back into app settings.
nonisolated struct ProseStyle: Equatable, Sendable {
    var face: ProseFace = .newYork
    var size: CGFloat = 17
    var lineHeight: LineHeight = .normal
    var paragraphLayout: ParagraphLayout = .spaced
    var theme: ReadingTheme = .paper
    var appearance: ColorScheme = .light
    var measure: Measure = .comfortable
    var focus: FocusDepth = .off
    var typewriter = false
    var highlightsDialogue = false
    var viewMode: PageViewMode = .continuous

    // MARK: Resolved values

    var pageAppearance: ColorScheme { theme.effectiveAppearance(appearance) }
    var pageColor: NSColor { theme.pageColor(for: pageAppearance) }
    var inkColor: NSColor { theme.inkColor(for: pageAppearance) }
    var mutedColor: NSColor { theme.mutedInkColor(for: pageAppearance) }
    var caretColor: NSColor { theme.caretColor(for: pageAppearance) }

    var bodyFont: NSFont { face.font(size: size) }
    var measureWidth: CGFloat { measure.width(for: bodyFont) }

    /// The editor's vertical breathing room, above the text container.
    static let restingPadding: CGFloat = 56

    /// From the top of the text container to the first line of prose.
    var topTextInset: CGFloat { viewMode == .page ? 48 : 24 }

    /// Where the first line of prose actually begins inside the editor.
    ///
    /// The empty-page prompt stands in for the first sentence, so it has to land on
    /// the line that sentence will occupy. It was positioned with a bare `56`, which
    /// is only the scroll view's inset and misses the text container's own — so the
    /// invitation floated a line or two above the line it was inviting you to write.
    /// Both halves live here now, and the editor and the prompt read the same ones.
    var firstLineOffset: CGFloat { Self.restingPadding + topTextInset }

    /// Selection needs to read on a warm page as well as a system one.
    ///
    /// Every colour below takes a fraction of a system colour, so every one of them
    /// has to be resolved against the page's appearance first — see
    /// `NSColor.resolved(for:)` for what happens when they are not.
    var selectionColor: NSColor {
        NSColor.selectedTextBackgroundColor
            .resolved(for: pageAppearance)
            .withAlphaComponent(pageAppearance == .dark ? 0.5 : 0.35)
    }

    /// A very light wash marking an anchored comment. Underlines would fight the
    /// prose; a wash sits behind it.
    var commentWashColor: NSColor {
        NSColor.systemYellow
            .resolved(for: pageAppearance)
            .withAlphaComponent(pageAppearance == .dark ? 0.16 : 0.18)
    }

    /// The transient wash used when navigation lands on a passage.
    var revealWashColor: NSColor {
        NSColor.controlAccentColor
            .resolved(for: pageAppearance)
            .withAlphaComponent(pageAppearance == .dark ? 0.28 : 0.20)
    }

    /// A marked passage. Warm enough to find while scrolling, weak enough to read
    /// through — an author highlights a sentence to come back to it, not to stop
    /// being able to see it.
    var highlightColor: NSColor {
        NSColor.systemYellow
            .resolved(for: pageAppearance)
            .withAlphaComponent(pageAppearance == .dark ? 0.28 : 0.34)
    }

    var dialogueColor: NSColor {
        guard highlightsDialogue else { return inkColor }
        let accent = NSColor.controlAccentColor.resolved(for: pageAppearance)
        return inkColor.blended(withFraction: 0.32, of: accent) ?? inkColor
    }

    /// A link's text. Reads as a link without shouting on a warm page.
    var linkColor: NSColor {
        let accent = NSColor.controlAccentColor.resolved(for: pageAppearance)
        return inkColor.blended(withFraction: 0.55, of: accent) ?? accent
    }

    /// A finished task.
    var confirmedColor: NSColor {
        NSColor.systemGreen.resolved(for: pageAppearance)
    }

    /// The surface a fenced block sits on. Barely there — enough to read as a
    /// block on a warm page without turning the manuscript into a code editor.
    var codeBackgroundColor: NSColor {
        inkColor.withAlphaComponent(pageAppearance == .dark ? 0.07 : 0.045)
    }

    /// The face a hidden marker is set in.
    ///
    /// A marker leaves the page by being set at a size nothing can read and then
    /// having even that width kerned away. It is not the only way to do it — under
    /// TextKit 1 the marker could be denied a glyph outright, which is cleaner —
    /// but that hook does not exist in TextKit 2, and this does. The characters
    /// stay in the text either way, which is the part that matters: the file is
    /// still Markdown.
    var markerFont: NSFont { NSFont.systemFont(ofSize: 0.1) }
}

// MARK: - Styler

nonisolated enum ProseStyler {

    // MARK: Paragraph styles

    /// Markdown separates paragraphs with a blank line, and that blank line is a
    /// real, empty paragraph in the text storage. So the gap between paragraphs is
    /// already there — piling a generous `paragraphSpacing` on top of it is what
    /// makes a Markdown editor look like a spreadsheet. The blank line is styled
    /// short (see `blankParagraphStyle`) and the spacing here stays modest, which
    /// also keeps prose readable for an author who never leaves blank lines.
    static func bodyParagraphStyle(_ style: ProseStyle) -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = style.lineHeight.multiple
        switch style.paragraphLayout {
        case .indented:
            paragraph.firstLineHeadIndent = style.size * 1.6
            paragraph.paragraphSpacing = 0
        case .spaced:
            paragraph.firstLineHeadIndent = 0
            paragraph.paragraphSpacing = style.size * 0.3
        }
        return paragraph
    }

    /// The blank line between paragraphs. It exists in the source, so it must
    /// exist on the page — but as a breath, not as a hole.
    private static func blankParagraphStyle(_ style: ProseStyle) -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = style.paragraphLayout == .indented ? 0.3 : 0.5
        paragraph.paragraphSpacing = 0
        paragraph.paragraphSpacingBefore = 0
        return paragraph
    }

    private static func headingParagraphStyle(_ style: ProseStyle) -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = 1.15
        paragraph.paragraphSpacingBefore = style.size * 0.9
        paragraph.paragraphSpacing = style.size * 0.4
        return paragraph
    }

    private static func quoteParagraphStyle(_ style: ProseStyle) -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = style.lineHeight.multiple
        paragraph.firstLineHeadIndent = style.size * 1.8
        paragraph.headIndent = style.size * 1.8
        paragraph.paragraphSpacing = style.size * 0.6
        return paragraph
    }

    /// Code and tables. Tight leading, because a fenced block is a grid rather
    /// than prose and the body measure makes it look like it has come apart.
    private static func monospacedBlockParagraphStyle(_ style: ProseStyle) -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = 1.15
        paragraph.firstLineHeadIndent = style.size * 0.6
        paragraph.headIndent = style.size * 0.6
        paragraph.paragraphSpacing = 0
        return paragraph
    }

    private static func breakParagraphStyle(_ style: ProseStyle) -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.paragraphSpacingBefore = style.size * 0.7
        paragraph.paragraphSpacing = style.size * 0.7
        return paragraph
    }

    /// The attributes newly typed text inherits.
    static func typingAttributes(_ style: ProseStyle) -> [NSAttributedString.Key: Any] {
        [
            .font: style.bodyFont,
            .foregroundColor: style.inkColor,
            .paragraphStyle: bodyParagraphStyle(style)
        ]
    }

    // MARK: Styling

    /// Applies real attributes to `range`, which the caller has already expanded
    /// to whole paragraphs.
    ///
    /// `wrapInEditing` must be false when called from inside
    /// `textStorage(_:didProcessEditing:range:changeInLength:)`: an edit
    /// transaction is already open there, and nesting another one is a crash.
    /// Changing attributes at that point is explicitly allowed; changing
    /// characters is not, and this method never does.
    static func applyAttributes(
        to storage: NSTextStorage,
        range: NSRange,
        style: ProseStyle,
        presentation: PresentationLayer = PresentationLayer(),
        wrapInEditing: Bool = true
    ) {
        let text = storage.string as NSString
        let safe = range.clamped(to: text.length)
        guard safe.length > 0 else { return }

        if wrapInEditing { storage.beginEditing() }
        defer { if wrapInEditing { storage.endEditing() } }

        // Ask the parser what this text *is*, scoped to the edit. Blocks tile the
        // document by whole lines, so a paragraph-expanded range can still land
        // inside something larger — a list, a fenced block, a table. Those come
        // back whole, and the repaint has to cover whatever came back or a
        // half-restyled construct keeps the attributes of the shape it used to be.
        let blocks = DocumentAST.parse(storage.string, scopedRanges: [safe], registry: .manuscript)
        var effective = safe
        for block in blocks { effective = NSUnionRange(effective, block.range) }
        effective = effective.clamped(to: text.length)

        // Reset to plain body prose, then let the parse speak.
        storage.setAttributes(typingAttributes(style), range: effective)
        for block in blocks {
            apply(block: block, storage: storage, text: text, style: style)
        }

        // Appearance the Markdown could not spell goes on last, on purpose. The
        // reset above is what used to wipe it — an attribute the text does not
        // spell cannot survive a restyle unless something re-applies it, and this
        // is that something.
        apply(presentation: presentation, storage: storage, range: effective, style: style)
    }

    /// Underline, highlight colour, face and size, and paragraph alignment.
    private static func apply(
        presentation: PresentationLayer,
        storage: NSTextStorage,
        range: NSRange,
        style: ProseStyle
    ) {
        guard !presentation.isEmpty else { return }

        for block in presentation.blocks {
            let target = NSIntersectionRange(block.range, range)
            guard target.length > 0 else { continue }
            storage.enumerateAttribute(.paragraphStyle, in: target) { value, subrange, _ in
                let base = (value as? NSParagraphStyle) ?? bodyParagraphStyle(style)
                guard let mutable = base.mutableCopy() as? NSMutableParagraphStyle else { return }
                mutable.alignment = block.alignment.nsAlignment
                storage.addAttribute(.paragraphStyle, value: mutable, range: subrange)
            }
        }

        for run in presentation.runs {
            let target = NSIntersectionRange(run.range, range)
            guard target.length > 0 else { continue }

            if run.underline {
                add(storage, [
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .underlineColor: style.inkColor.withAlphaComponent(0.6)
                ], target)
            }
            if let highlight = run.highlight {
                add(storage, [.backgroundColor: highlight.wash(for: style.pageAppearance)], target)
            }
            // A face or size chosen for one sentence has to keep whatever the
            // Markdown made of it — bold inside a resized run stays bold — so the
            // existing font is modified rather than replaced.
            if run.fontName != nil || run.fontSize != nil {
                storage.enumerateAttribute(.font, in: target) { value, subrange, _ in
                    let current = (value as? NSFont) ?? style.bodyFont
                    let size = run.fontSize.map { CGFloat($0) } ?? current.pointSize
                    var resolved = current
                    if let name = run.fontName, let named = NSFont(name: name, size: size) {
                        // Carry the traits across; a renamed bold run stays bold.
                        let traits = NSFontManager.shared.traits(of: current)
                        resolved = NSFontManager.shared.convert(named, toHaveTrait: traits)
                    } else {
                        resolved = NSFontManager.shared.convert(current, toSize: size)
                    }
                    storage.addAttribute(.font, value: resolved, range: subrange)
                }
            }
        }
    }

    // MARK: Blocks

    private static func apply(block: BlockNode, storage: NSTextStorage, text: NSString, style: ProseStyle) {
        switch block {
        case .blank(let range):
            add(storage, [.paragraphStyle: blankParagraphStyle(style)], range)

        case .paragraph(let range, let inlines):
            if style.highlightsDialogue { tintDialogue(storage, text, range, style) }
            apply(inlines: inlines, storage: storage, style: style)

        case .heading(let level, let range, let markers, let inlines):
            let scale: CGFloat = [1.55, 1.35, 1.2, 1.1, 1.05, 1.0][min(max(level, 1) - 1, 5)]
            add(storage, [
                .font: style.face.font(size: (style.size * scale).rounded(), weight: .semibold),
                .paragraphStyle: headingParagraphStyle(style)
            ], range)
            apply(inlines: inlines, storage: storage, style: style)
            for marker in markers { mark(storage, marker, style, side: .opening) }

        case .blockquote(let range, let inlines):
            add(storage, [
                .paragraphStyle: quoteParagraphStyle(style),
                .foregroundColor: style.inkColor.withAlphaComponent(0.85),
                .font: italic(style.bodyFont),
                .blockquote: true
            ], range)
            apply(inlines: inlines, storage: storage, style: style)
            // The `>` of each line. The AST gives the block, not the marker — a
            // quote can span many lines and each one carries its own.
            forEachLine(in: range, text) { line in
                var index = line.location
                let end = NSMaxRange(line)
                while index < end, isSpaceOrTab(text.character(at: index)) { index += 1 }
                guard index < end, text.character(at: index) == 0x3E else { return }   // >
                var marker = index + 1
                if marker < end, isSpaceOrTab(text.character(at: marker)) { marker += 1 }
                mark(storage, NSRange(location: line.location, length: marker - line.location), style, side: .opening)
            }

        case .list(let range, let items):
            _ = range
            for item in items { apply(listItem: item, storage: storage, style: style) }

        case .table(let range):
            // A table is monospaced rather than laid out: columns that line up in
            // the source are the only alignment a Markdown file actually carries,
            // and a proportional face destroys it.
            add(storage, [
                .font: NSFont.monospacedSystemFont(ofSize: style.size * 0.9, weight: .regular),
                .foregroundColor: style.inkColor.withAlphaComponent(0.9),
                .paragraphStyle: monospacedBlockParagraphStyle(style)
            ], range)

        case .codeBlock(let range):
            add(storage, [
                .font: NSFont.monospacedSystemFont(ofSize: style.size * 0.9, weight: .regular),
                .foregroundColor: style.inkColor.withAlphaComponent(0.9),
                .paragraphStyle: monospacedBlockParagraphStyle(style),
                .backgroundColor: style.codeBackgroundColor
            ], range)
            // The fences are dimmed, not hidden. Everything else the styler hides
            // is a marker *inside* a line, where the caret can still reach the text
            // on either side; a fence is a whole line of its own, and hiding it
            // would leave the author with a code block they can see and a delimiter
            // they cannot get the caret onto to remove.
            dimFences(of: range, storage: storage, text: text, style: style)

        case .thematicBreak(let range):
            add(storage, [
                .paragraphStyle: breakParagraphStyle(style),
                .foregroundColor: style.mutedColor,
                .kern: style.size * 0.35
            ], range)

        case .blockLatex(let range):
            add(storage, [.font: NSFont.monospacedSystemFont(ofSize: style.size * 0.9, weight: .regular)], range)

        case .ext(let node):
            apply(inlines: node.inlines, storage: storage, style: style)
        }
    }

    /// One line of a list: a hanging indent so wrapped text aligns under the text
    /// rather than under the bullet, and a marker dimmed rather than hidden — the
    /// author needs to see that they are still in a list while they are editing it.
    private static func apply(listItem item: ListItem, storage: NSTextStorage, style: ProseStyle) {
        let step = style.size * 1.4
        let depth = CGFloat(min(item.indent, 8))
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = style.lineHeight.multiple
        paragraph.firstLineHeadIndent = step * depth
        paragraph.headIndent = step * depth + step
        paragraph.paragraphSpacing = 0
        add(storage, [.paragraphStyle: paragraph], item.range)

        if item.marker.length > 0 {
            add(storage, [.foregroundColor: style.mutedColor], item.marker)
        }
        if let checkbox = item.checkbox {
            add(storage, [
                .foregroundColor: item.checked ? style.confirmedColor : style.mutedColor,
                .font: NSFont.monospacedSystemFont(ofSize: style.size * 0.9, weight: .medium)
            ], checkbox)
            // A finished task reads as finished.
            if item.checked, item.contentRange.length > 0 {
                add(storage, [
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: style.mutedColor
                ], item.contentRange)
            }
        }
        apply(inlines: item.inlines, storage: storage, style: style)
    }

    // MARK: Inlines

    /// Walks the inline tree. Nesting is the parser's problem now, not a question
    /// of which regex claimed which asterisk first — `**bold with *italic* in it**`
    /// simply arrives as a bold node with an italic child.
    private static func apply(inlines: [InlineNode], storage: NSTextStorage, style: ProseStyle) {
        for node in inlines {
            switch node {
            case .text:
                break

            case .emphasis(let kind, _, let markers, let children):
                let content = span(of: markers)
                switch kind {
                case .italic:
                    apply(trait: .italicFontMask, storage: storage, content: content, style: style)
                    note(.emphasis, storage, content)
                case .bold:
                    apply(trait: .boldFontMask, storage: storage, content: content, style: style)
                    note(.strong, storage, content)
                case .boldItalic:
                    apply(trait: .boldFontMask, storage: storage, content: content, style: style)
                    apply(trait: .italicFontMask, storage: storage, content: content, style: style)
                    note(.strong, storage, content)
                    note(.emphasis, storage, content)
                }
                apply(inlines: children, storage: storage, style: style)
                markPair(storage, markers, style)

            case .code(let range, let content):
                add(storage, [
                    .font: NSFont.monospacedSystemFont(ofSize: style.size * 0.92, weight: .regular),
                    .foregroundColor: style.inkColor.withAlphaComponent(0.9)
                ], content)
                mark(storage, NSRange(location: range.location, length: content.location - range.location), style, side: .opening)
                mark(storage, NSRange(location: NSMaxRange(content), length: NSMaxRange(range) - NSMaxRange(content)), style, side: .closing)

            case .link(_, let textRange, _, let markers, let children):
                add(storage, [
                    .foregroundColor: style.linkColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .underlineColor: style.linkColor.withAlphaComponent(0.35)
                ], textRange)
                apply(inlines: children, storage: storage, style: style)
                // `[` opens; `](url)` closes as one run, so the address leaves the
                // page with its brackets instead of sitting in the middle of a
                // sentence. It is still in the file, which is the point.
                if markers.count >= 4 {
                    mark(storage, markers[0], style, side: .opening)
                    mark(storage, NSRange(location: markers[1].location,
                                          length: NSMaxRange(markers[3]) - markers[1].location), style, side: .closing)
                }

            case .escape(_, _, let marker):
                mark(storage, marker, style, side: .opening)

            case .ext(let node):
                switch node.extensionID {
                case MarkdownConstruct.highlight.id:
                    add(storage, [.backgroundColor: style.highlightColor], node.contentRange)
                    note(.highlight, storage, node.contentRange)
                case MarkdownConstruct.strikethrough.id:
                    add(storage, [
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .strikethroughColor: style.mutedColor,
                        .foregroundColor: style.inkColor.withAlphaComponent(0.55)
                    ], node.contentRange)
                    note(.strikethrough, storage, node.contentRange)
                default:
                    break
                }
                apply(inlines: node.children, storage: storage, style: style)
                markPair(storage, node.markers, style)

            case .image, .wikiLink, .imageEmbed, .inlineLatex:
                // Constructs the manuscript does not claim to render. They stay
                // literal text rather than being half-styled into something the
                // author cannot edit back out again.
                break
            }
        }
    }

    /// The content between the first and last marker of a construct.
    private static func span(of markers: [NSRange]) -> NSRange {
        guard let open = markers.first, let close = markers.last, markers.count >= 2 else {
            return NSRange(location: NSNotFound, length: 0)
        }
        return NSRange(location: NSMaxRange(open), length: close.location - NSMaxRange(open))
    }

    private static func markPair(_ storage: NSTextStorage, _ markers: [NSRange], _ style: ProseStyle) {
        guard markers.count >= 2 else { return }
        mark(storage, markers[0], style, side: .opening)
        mark(storage, markers[markers.count - 1], style, side: .closing)
    }

    // MARK: Helpers

    private static func add(_ storage: NSTextStorage, _ attributes: [NSAttributedString.Key: Any], _ range: NSRange) {
        guard range.location != NSNotFound, range.length > 0,
              NSMaxRange(range) <= storage.length else { return }
        storage.addAttributes(attributes, range: range)
    }

    private static func forEachLine(in range: NSRange, _ text: NSString, _ body: (NSRange) -> Void) {
        var cursor = range.location
        let end = min(NSMaxRange(range), text.length)
        while cursor < end {
            let line = text.lineRange(for: NSRange(location: cursor, length: 0))
            body(NSRange(location: line.location, length: min(NSMaxRange(line), end) - line.location))
            cursor = NSMaxRange(line)
        }
    }

    private static func isSpaceOrTab(_ character: unichar) -> Bool {
        character == 0x20 || character == 0x09
    }

    /// Quiet the ``` lines opening and closing a fenced block.
    private static func dimFences(of range: NSRange, storage: NSTextStorage, text: NSString, style: ProseStyle) {
        var lines: [NSRange] = []
        forEachLine(in: range, text) { lines.append($0) }
        guard let first = lines.first else { return }

        func isFence(_ line: NSRange) -> Bool {
            var index = line.location
            let end = NSMaxRange(line)
            while index < end, isSpaceOrTab(text.character(at: index)) { index += 1 }
            var ticks = 0
            while index < end, text.character(at: index) == 0x60 { ticks += 1; index += 1 }  // `
            return ticks >= 3
        }

        let quiet: [NSAttributedString.Key: Any] = [
            .foregroundColor: style.mutedColor,
            .font: NSFont.monospacedSystemFont(ofSize: style.size * 0.72, weight: .regular)
        ]
        if isFence(first) { add(storage, quiet, first) }
        if let last = lines.last, lines.count > 1, isFence(last) { add(storage, quiet, last) }
    }

    private static func tintDialogue(_ storage: NSTextStorage, _ text: NSString, _ range: NSRange, _ style: ProseStyle) {
        let line = text.substring(with: range)
        for match in Patterns.dialogue.matches(in: line, range: line.fullRange) {
            add(storage, [.foregroundColor: style.dialogueColor],
                NSRange(location: range.location + match.range.location, length: match.range.length))
        }
    }

    /// An inline marker: still in the text, gone from the page.
    ///
    /// Set at a size nothing can read, with that width kerned back out again, and
    /// drawn in nothing. The `.marker` attribute stays because the caret still has
    /// to treat the run as atomic — shrinking a marker does not stop the caret
    /// being able to stand inside it, it only stops the author being able to see
    /// that it has.
    private static func mark(_ storage: NSTextStorage, _ range: NSRange, _ style: ProseStyle, side: MarkerSide) {
        guard range.length > 0, range.location != NSNotFound,
              NSMaxRange(range) <= storage.length else { return }
        let font = style.markerFont
        storage.addAttributes([
            .font: font,
            .kern: -font.pointSize,
            .foregroundColor: NSColor.clear,
            .marker: NSNumber(value: side.rawValue)
        ], range: range)
    }

    /// What emphasis this run of prose is carrying, so the format bar can answer the
    /// question without parsing the paragraph again on every keystroke.
    private static func note(_ format: InlineFormat, _ storage: NSTextStorage, _ range: NSRange) {
        guard range.length > 0, range.location != NSNotFound else { return }
        storage.enumerateAttribute(.inlineFormat, in: range) { value, subrange, _ in
            let bits = ((value as? NSNumber)?.intValue ?? 0) | format.bit
            storage.addAttribute(.inlineFormat, value: NSNumber(value: bits), range: subrange)
        }
    }

    private static func apply(trait: NSFontTraitMask, storage: NSTextStorage, content: NSRange, style: ProseStyle) {
        guard content.length > 0, content.location != NSNotFound else { return }
        storage.enumerateAttribute(.font, in: content) { value, subrange, _ in
            let base = (value as? NSFont) ?? style.bodyFont
            let converted = NSFontManager.shared.convert(base, toHaveTrait: trait)
            storage.addAttribute(.font, value: converted, range: subrange)
        }
    }

    private static func italic(_ font: NSFont) -> NSFont {
        NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
    }

    private static func absolute(_ relative: NSRange, in paragraph: NSRange) -> NSRange {
        guard relative.location != NSNotFound else { return NSRange(location: NSNotFound, length: 0) }
        return NSRange(location: paragraph.location + relative.location, length: relative.length)
    }

    // MARK: Focus

    /// The passage the author is inside right now.
    static func focusRange(in text: NSString, selection: NSRange, depth: FocusDepth) -> NSRange? {
        guard depth != .off, text.length > 0 else { return nil }
        let caret = NSRange(location: min(selection.location, text.length), length: 0)
        let paragraph = text.paragraphRange(for: caret)

        switch depth {
        case .off:
            return nil
        case .paragraph:
            return paragraph
        case .sentence:
            var sentence: NSRange?
            text.enumerateSubstrings(in: paragraph, options: [.bySentences, .substringNotRequired]) { _, range, _, stop in
                // The caret sits *inside* a sentence, or at the boundary where the
                // author is about to extend it.
                if NSLocationInRange(caret.location, range) || caret.location == range.location + range.length {
                    sentence = range
                    stop.pointee = true
                }
            }
            return sentence ?? paragraph
        }
    }
}

// MARK: - Patterns

private nonisolated enum Patterns {
    /// The one rule the Markdown parser cannot supply, because it is not Markdown:
    /// quoted speech. Straight and curly both — the editor substitutes curly ones
    /// as you type, but imported prose may carry either.
    static let dialogue = regex("[\u{201C}\"][^\u{201C}\u{201D}\"]{0,600}?[\u{201D}\"]")

    private static func regex(_ pattern: String) -> NSRegularExpression {
        // These patterns are constant and reviewed; a failure here is a build bug.
        try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
    }
}

private extension NSRegularExpression {
    nonisolated func matches(in string: String, range: NSRange) -> [NSTextCheckingResult] {
        matches(in: string, options: [], range: range)
    }

    nonisolated func firstMatch(in string: String, range: NSRange) -> NSTextCheckingResult? {
        firstMatch(in: string, options: [], range: range)
    }
}

private extension String {
    nonisolated var fullRange: NSRange { NSRange(location: 0, length: (self as NSString).length) }
}

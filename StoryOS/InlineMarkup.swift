//
//  InlineMarkup.swift
//  StoryLoom
//
//  Emphasis is a toggle, not a stamp.
//
//  Markdown emphasis is a run of asterisks, and the length of the run is the
//  meaning: one is italic, two is bold, three is both. So "is this text already
//  bold?" is not a question about whether asterisks are present — it is a question
//  about how many. A tool that only counts presence turns ⌘B pressed twice into
//  `****word****`, which is not bold, not italic, and not anything.
//
//  Everything here is a pure function from text and selection to a single edit, so
//  it can be reasoned about, tested without a window, and applied through AppKit's
//  own text machinery — which is what puts it on the undo stack looking exactly
//  like something the author typed.
//

import Foundation

// MARK: - Formats

nonisolated enum InlineFormat: String, CaseIterable, Sendable {
    case emphasis = "*"
    case strong = "**"
    /// `==text==`. Not in CommonMark, but the one extension every Markdown editor a
    /// novelist is likely to open the file in — Obsidian, Bear, Typora — already
    /// agrees on. It matters that it is *text*: a highlight applied as an attribute
    /// would live only in the window it was made in, and this one survives the file.
    case highlight = "=="
    /// `~~cut~~`. Striking a line through prose is not deleting it — it is the
    /// author saying "probably not, but not yet".
    case strikethrough = "~~"

    var marker: String { rawValue }
    var width: Int { rawValue.count }

    /// The character a run of this marker is made of, for scanning.
    var markerScalar: unichar {
        switch self {
        case .emphasis, .strong: 0x2A  // *
        case .highlight: 0x3D          // =
        case .strikethrough: 0x7E      // ~
        }
    }

    var title: String {
        switch self {
        case .emphasis: "Emphasis"
        case .strong: "Strong"
        case .highlight: "Highlight"
        case .strikethrough: "Strikethrough"
        }
    }

    var symbolName: String {
        switch self {
        case .emphasis: "italic"
        case .strong: "bold"
        case .highlight: "highlighter"
        case .strikethrough: "strikethrough"
        }
    }

    /// A place in a bitmask, so the emphasis carried by a run of prose is one
    /// attribute rather than a collection — cheap to set on every keystroke, and
    /// cheap to read back when the format bar asks "is B lit?".
    var bit: Int {
        switch self {
        case .emphasis: 1
        case .strong: 2
        case .highlight: 4
        case .strikethrough: 8
        }
    }

    static func formats(bits: Int) -> Set<InlineFormat> {
        Set(allCases.filter { bits & $0.bit != 0 })
    }

    /// Whether a run of `length` asterisks carries this format.
    ///
    /// This is the whole trick. `**word**` is bold and contains no italic, so
    /// asking for italic there must *add* a marker, not strip one — otherwise
    /// italicising bold text silently un-bolds it. `***word***` is both, so either
    /// request removes its own marker and leaves the other standing.
    func present(inRunOf length: Int) -> Bool {
        switch self {
        case .emphasis: length == 1 || length == 3
        case .strong: length >= 2
        // Neither `=` nor `~` carries such ambiguity: there is only `==` and `~~`.
        case .highlight, .strikethrough: length >= 2
        }
    }
}

/// One replacement, and where the selection should land afterwards.
nonisolated struct TextEdit: Equatable, Sendable {
    /// The range to replace, in the *original* string.
    var range: NSRange
    var replacement: String
    /// The selection to set once the replacement is in, in the *new* string.
    var selection: NSRange
}

// MARK: - Toggle

nonisolated enum InlineMarkup {

    /// The edit that toggles `format` over `selection`, or `nil` when there is
    /// nothing sensible to do.
    static func toggle(_ format: InlineFormat, in text: NSString, selection: NSRange) -> TextEdit? {
        let width = format.width
        var span = selection.clamped(to: text.length)

        // An author who hits ⌘B with the caret in a word means that word. Every
        // editor they have ever used agrees, and asking them to select first is a
        // tax on a keystroke that is supposed to be free.
        if span.length == 0 {
            span = word(around: span.location, in: text) ?? span
        }

        // Still nothing: leave an empty pair and put the caret inside it, ready.
        if span.length == 0 {
            return TextEdit(
                range: span,
                replacement: format.marker + format.marker,
                selection: NSRange(location: span.location + width, length: 0)
            )
        }

        // `** bold **` is not bold — CommonMark requires the marker to touch the
        // word. Formatting applies to what was selected, not to the gap beside it.
        span = trimming(span, in: text)
        guard span.length > 0 else { return nil }

        if let edit = removingMarkersInside(format, in: text, span: span) { return edit }
        if let edit = removingMarkersAround(format, in: text, span: span) { return edit }

        let content = text.substring(with: span)
        return TextEdit(
            range: span,
            replacement: format.marker + content + format.marker,
            selection: NSRange(location: span.location + width, length: span.length)
        )
    }

    static func blockquote(in text: NSString, selection: NSRange) -> TextEdit? {
        let span = text.paragraphRange(for: selection.clamped(to: text.length))

        let block = text.substring(with: span)
        var lines = block.components(separatedBy: "\n")
        let hasTrailingNewline = block.hasSuffix("\n")
        if hasTrailingNewline && lines.count > 1 && lines.last?.isEmpty == true {
            lines.removeLast()
        }

        let nonBlank = lines.filter { !$0.isEmpty }
        let targetLines = nonBlank.isEmpty ? lines : nonBlank
        let quoted = targetLines.allSatisfy { $0.hasPrefix(">") }

        let rewritten = lines.map { line -> String in
            if quoted {
                guard line.hasPrefix(">") else { return line }
                let body = String(line.dropFirst())
                return body.hasPrefix(" ") ? String(body.dropFirst()) : body
            }
            return line.hasPrefix("> ") || line.hasPrefix(">") ? line : "> " + line
        }

        let replacement = rewritten.joined(separator: "\n") + (hasTrailingNewline ? "\n" : "")
        return TextEdit(
            range: span,
            replacement: replacement,
            selection: NSRange(location: span.location, length: (replacement as NSString).length)
        )
    }

    /// `# `, `## `, `### ` on every line of the selection; level 0 removes them.
    ///
    /// Real Markdown, so a heading survives the file, the export, and being
    /// opened in anything else — unlike a font size, which is why one of these is
    /// text and the other is not.
    static func heading(_ level: Int, in text: NSString, selection: NSRange) -> TextEdit? {
        let span = text.paragraphRange(for: selection.clamped(to: text.length))
        guard span.length > 0 else { return nil }
        let block = text.substring(with: span)
        let hasTrailingNewline = block.hasSuffix("\n")
        var lines = block.components(separatedBy: "\n")
        if hasTrailingNewline, lines.count > 1, lines.last?.isEmpty == true { lines.removeLast() }

        let marker = level > 0 ? String(repeating: "#", count: min(level, 6)) + " " : ""
        let rewritten = lines.map { line -> String in
            var body = line
            // Strip whatever heading it already was, so levels replace rather
            // than stack into `## # Title`.
            while body.hasPrefix("#") { body.removeFirst() }
            if body.hasPrefix(" ") { body.removeFirst() }
            return body.isEmpty && marker.isEmpty ? "" : marker + body
        }
        let replacement = rewritten.joined(separator: "\n") + (hasTrailingNewline ? "\n" : "")
        return TextEdit(
            range: span,
            replacement: replacement,
            selection: NSRange(location: span.location, length: (replacement as NSString).length)
        )
    }

    /// Turn the selected paragraphs into a list, or back out of one.
    static func list(ordered: Bool, in text: NSString, selection: NSRange) -> TextEdit? {
        let span = text.paragraphRange(for: selection.clamped(to: text.length))
        guard span.length > 0 else { return nil }
        let block = text.substring(with: span)
        let hasTrailingNewline = block.hasSuffix("\n")
        var lines = block.components(separatedBy: "\n")
        if hasTrailingNewline, lines.count > 1, lines.last?.isEmpty == true { lines.removeLast() }

        let existing = try! NSRegularExpression(pattern: #"^(\s*)(?:\d+[.)]|[-*+])\s+"#)
        func stripped(_ line: String) -> String {
            let range = NSRange(location: 0, length: (line as NSString).length)
            guard let match = existing.firstMatch(in: line, range: range) else { return line }
            return (line as NSString).replacingCharacters(in: match.range, with: (line as NSString).substring(with: match.range(at: 1)))
        }

        let alreadyList = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .allSatisfy { existing.firstMatch(in: $0, range: NSRange(location: 0, length: ($0 as NSString).length)) != nil }

        var number = 0
        let rewritten = lines.map { line -> String in
            let bare = stripped(line)
            if alreadyList { return bare }
            if bare.trimmingCharacters(in: .whitespaces).isEmpty { return bare }
            number += 1
            return ordered ? "\(number). " + bare : "- " + bare
        }
        let replacement = rewritten.joined(separator: "\n") + (hasTrailingNewline ? "\n" : "")
        return TextEdit(
            range: span,
            replacement: replacement,
            selection: NSRange(location: span.location, length: (replacement as NSString).length)
        )
    }

    /// A scene break, as its own block. Markdown's `***` centred on the page.
    ///
    /// It is a *block*, so it goes between paragraphs — never inside the word the
    /// caret happens to be touching, which is what replacing the selection outright
    /// used to do. And it absorbs the blank lines already at the seam rather than
    /// adding to them: pressed on an empty line, the old version left four.
    static func sceneBreak(in text: NSString, selection: NSRange) -> TextEdit {
        let caret = NSRange(location: selection.clamped(to: text.length).location, length: 0)
        let paragraph = text.paragraphRange(for: caret)

        var start = NSMaxRange(paragraph)
        var end = start
        while end < text.length, isNewline(text.character(at: end)) { end += 1 }
        while start > 0, isNewline(text.character(at: start - 1)) { start -= 1 }

        let lead = start == 0 ? "" : "\n\n"
        let trail = end >= text.length ? "" : "\n\n"
        let replacement = lead + "***" + trail

        return TextEdit(
            range: NSRange(location: start, length: end - start),
            replacement: replacement,
            selection: NSRange(location: start + (replacement as NSString).length, length: 0)
        )
    }

    private static func isNewline(_ character: unichar) -> Bool {
        character == 0x0A || character == 0x0D
    }

    // MARK: Removal

    /// The author selected the markers too: `**word**` with the asterisks inside
    /// the selection.
    private static func removingMarkersInside(
        _ format: InlineFormat,
        in text: NSString,
        span: NSRange
    ) -> TextEdit? {
        let width = format.width
        guard span.length > 2 * width else { return nil }

        let leading = run(in: text, from: span.location, step: 1, limit: NSMaxRange(span), of: format.markerScalar)
        let trailing = run(in: text, from: NSMaxRange(span) - 1, step: -1, limit: span.location - 1, of: format.markerScalar)
        let matched = min(leading, trailing)
        guard format.present(inRunOf: matched) else { return nil }

        let inner = NSRange(location: span.location + width, length: span.length - 2 * width)
        let content = text.substring(with: inner)
        return TextEdit(
            range: span,
            replacement: content,
            selection: NSRange(location: span.location, length: (content as NSString).length)
        )
    }

    /// The author selected only the words, and the markers sit outside them —
    /// which is what a double-click inside `**word**` gives you.
    private static func removingMarkersAround(
        _ format: InlineFormat,
        in text: NSString,
        span: NSRange
    ) -> TextEdit? {
        let width = format.width
        let end = NSMaxRange(span)
        guard span.location >= width, end + width <= text.length else { return nil }

        let leading = run(in: text, from: span.location - 1, step: -1, limit: -1, of: format.markerScalar)
        let trailing = run(in: text, from: end, step: 1, limit: text.length, of: format.markerScalar)
        let matched = min(leading, trailing)
        guard matched >= width, format.present(inRunOf: matched) else { return nil }

        let outer = NSRange(location: span.location - width, length: span.length + 2 * width)
        let content = text.substring(with: span)
        return TextEdit(
            range: outer,
            replacement: content,
            selection: NSRange(location: outer.location, length: span.length)
        )
    }

    // MARK: Scanning

    /// How many marker characters run consecutively from `index` in `step`
    /// direction, stopping before `limit`.
    private static func run(in text: NSString, from index: Int, step: Int, limit: Int, of scalar: unichar) -> Int {
        var position = index
        var length = 0
        while position != limit, position >= 0, position < text.length, text.character(at: position) == scalar {
            length += 1
            position += step
        }
        return length
    }

    /// The word the caret is sitting in or against. An apostrophe is part of a
    /// word, because "don't" is one word and bolding half of it is nobody's intent.
    private static func word(around location: Int, in text: NSString) -> NSRange? {
        guard text.length > 0 else { return nil }

        var start = min(location, text.length)
        var end = start

        while start > 0, isWordCharacter(text.character(at: start - 1)) { start -= 1 }
        while end < text.length, isWordCharacter(text.character(at: end)) { end += 1 }

        guard end > start else { return nil }
        return NSRange(location: start, length: end - start)
    }

    private static func isWordCharacter(_ character: unichar) -> Bool {
        guard let scalar = Unicode.Scalar(character) else { return false }
        if CharacterSet.alphanumerics.contains(scalar) { return true }
        return character == 0x27 || character == 0x2019  // ' and ’
    }

    private static func trimming(_ span: NSRange, in text: NSString) -> NSRange {
        var start = span.location
        var end = NSMaxRange(span)
        while start < end, isTrimmable(text.character(at: start)) { start += 1 }
        while end > start, isTrimmable(text.character(at: end - 1)) { end -= 1 }
        return NSRange(location: start, length: end - start)
    }

    private static func isTrimmable(_ character: unichar) -> Bool {
        guard let scalar = Unicode.Scalar(character) else { return false }
        return CharacterSet.whitespacesAndNewlines.contains(scalar)
    }
}

// MARK: - Hidden markers

nonisolated enum MarkerSide: Int, Sendable {
    case opening = 1
    case closing = 2
}

/// A run of asterisks the page is not drawing.
nonisolated struct MarkerRun: Equatable, Sendable {
    var range: NSRange
    var side: MarkerSide

    init(_ range: NSRange, _ side: MarkerSide) {
        self.range = range
        self.side = side
    }
}

/// What has to be true for a marker to be invisible and the page to still behave.
///
/// The asterisks stay in the text — they are the file, and the file is Markdown —
/// but the page gives them no glyph, so `**word**` is drawn as four letters, not
/// eight characters. That leaves two positions in the text for every one position on
/// the screen, and the caret has to pick. If it picks naively, the page breaks in
/// ways the author cannot see: an arrow key that appears not to move, a backspace
/// that eats an asterisk and silently turns bold text into italic.
///
/// So a hidden run is **atomic**. The caret may stand on its outer edge and nowhere
/// else, a selection may swallow it whole but never cut it, and a delete that lands
/// on one reaches through it for the letter the author was actually aiming at. All of
/// which is arithmetic, and therefore lives here, where it can be tested without a
/// window.
///
/// `run(i)` answers: is the character at index `i` part of a hidden marker, and which
/// side of its construct is it on? Everything below is derived from that one question.
nonisolated enum Markers {

    /// The nearest position the caret is allowed to occupy.
    ///
    /// An opening run belongs to the word after it, so the caret sits *before* it; a
    /// closing run belongs to the word before it, so the caret sits *after*. Both
    /// edges of a run therefore collapse onto the one visible position beside the
    /// word, and a single arrow press is a single visible step.
    static func caret(at location: Int, run: (Int) -> MarkerRun?) -> Int {
        if let marker = run(location) {
            switch marker.side {
            case .opening: return marker.range.location
            case .closing: return NSMaxRange(marker.range)
            }
        }
        if location > 0, let marker = run(location - 1) {
            switch marker.side {
            case .opening: return marker.range.location
            case .closing: return NSMaxRange(marker.range)
            }
        }
        return location
    }

    /// A selection never cuts a run in half: the markers of a construct travel with
    /// it or not at all, so cutting a bold word cannot leave a stray `**` behind.
    static func selection(_ range: NSRange, run: (Int) -> MarkerRun?) -> NSRange {
        guard range.length > 0 else {
            return NSRange(location: caret(at: range.location, run: run), length: 0)
        }

        var start = range.location
        var end = NSMaxRange(range)

        if let marker = run(start), start > marker.range.location {
            start = marker.range.location
        }
        if end > 0, let marker = run(end - 1), end < NSMaxRange(marker.range) {
            end = NSMaxRange(marker.range)
        }
        return NSRange(location: start, length: max(0, end - start))
    }

    /// The range a delete key should *actually* remove — which is not always the
    /// range it landed on, because some of what it landed on is invisible.
    ///
    /// Three cases, and only three:
    ///
    /// **Backspace beside a closing run.** Visually the caret is just after the `d` of
    /// **word**; in the text it is after two asterisks. Deleting what is literally
    /// behind it eats one of them and leaves `**word*` — not bold, partly italic, and
    /// showing an asterisk that was never typed. So it reaches *through* the run and
    /// takes the `d`.
    ///
    /// **Forward-delete beside an opening run.** The same, mirrored: the caret is
    /// before the `w`, and two invisible asterisks are in the way of it.
    ///
    /// **A selection that is exactly a construct's content.** Double-click a bold word
    /// and press delete: the author is deleting the word, and a word's emphasis is
    /// part of the word. Leaving `****` behind would put four asterisks on the page
    /// out of nowhere.
    ///
    /// Everything else — nil — is AppKit's own business, which is most of the time.
    static func delete(_ selection: NSRange, forward: Bool, length: Int, run: (Int) -> MarkerRun?) -> NSRange? {
        guard selection.length == 0 else {
            return construct(wrapping: selection, run: run)
        }

        let caret = selection.location
        if forward {
            guard caret < length, let opening = run(caret), opening.side == .opening else { return nil }
            return reaching(through: opening, forward: true, length: length, run: run)
        } else {
            guard caret > 0, let closing = run(caret - 1), closing.side == .closing else { return nil }
            return reaching(through: closing, forward: false, length: length, run: run)
        }
    }

    /// The letter on the far side of a run the author cannot see — unless taking that
    /// letter would leave the construct holding nothing, in which case the construct
    /// goes with it.
    private static func reaching(
        through marker: MarkerRun,
        forward: Bool,
        length: Int,
        run: (Int) -> MarkerRun?
    ) -> NSRange? {
        let target = forward ? NSMaxRange(marker.range) : marker.range.location - 1
        guard target >= 0, target < length else { return nil }

        // The construct is empty already: `****`, with the two pairs back to back.
        if let partner = run(target), partner.side != marker.side {
            return union(marker.range, partner.range)
        }

        // It is about to be. `**d**` minus its `d` is not a bold word with nothing in
        // it — it is four asterisks on the page that the author never typed.
        let beyond = forward ? target + 1 : target - 1
        if beyond >= 0, beyond < length, let partner = run(beyond), partner.side != marker.side {
            return union(marker.range, partner.range)
        }

        return NSRange(location: target, length: 1)
    }

    private static func union(_ one: NSRange, _ other: NSRange) -> NSRange {
        let start = min(one.location, other.location)
        let end = max(NSMaxRange(one), NSMaxRange(other))
        return NSRange(location: start, length: end - start)
    }

    /// The whole of `**word**` when `selection` is exactly the `word`.
    private static func construct(wrapping selection: NSRange, run: (Int) -> MarkerRun?) -> NSRange? {
        guard selection.location > 0,
              let opening = run(selection.location - 1), opening.side == .opening,
              let closing = run(NSMaxRange(selection)), closing.side == .closing
        else { return nil }

        return NSRange(
            location: opening.range.location,
            length: NSMaxRange(closing.range) - opening.range.location
        )
    }
}

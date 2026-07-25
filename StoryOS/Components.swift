//
//  Components.swift
//  StoryLoom
//
//  The shared vocabulary.
//
//  One rule decides most of what is in this file: **controls may have edges;
//  containers may not.** A text field, a filter, a menu — those are things you
//  operate, and an edge tells you where to click. A card, a panel, a section, a
//  group — those are things you *read*, and an edge around them is a line the eye
//  has to cross for nothing. Hierarchy comes from typography, indentation, and a
//  single hairline rule, which is how Xcode, Finder, and Mail have always done it
//  and why they still work at hour eight.
//
//  The application had cards. It does not any more.
//

import SwiftUI

// MARK: - Structure

/// A dense band of chrome: a filter bar, a jump bar, a status line. Fixed height,
/// hairline beneath, no fill of its own.
struct Strip<Content: View>: View {
    var height: CGFloat = Metrics.strip
    var divides = true
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: Space.snug) {
            content
        }
        .padding(.horizontal, Space.small)
        .frame(height: height)
        .overlay(alignment: .bottom) {
            if divides {
                Rectangle()
                    .fill(Palette.hairline)
                    .frame(height: 1)
            }
        }
    }
}

/// The single strip above a navigator: filter what is listed, and make one more of
/// it. The room's name is deliberately absent — it is selected in the sidebar, two
/// hundred points to the left, and printing it twice is how a list loses a row.
struct NavigatorBar<Action: View>: View {
    @Binding var filter: String
    let prompt: String
    @ViewBuilder var action: Action

    var body: some View {
        Strip {
            FilterField(text: $filter, prompt: prompt)
            action
                .buttonStyle(.borderless)
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .font(.system(size: 11, weight: .medium))
        }
    }
}

/// A list group's header, carrying the count that used to live in a pane subtitle.
/// The number belongs beside the things it counts.
struct GroupHeader: View {
    let title: String
    var count: Int?
    var detail: String?

    var body: some View {
        HStack(spacing: Space.snug) {
            Text(title)
            Spacer(minLength: Space.tight)
            if let detail {
                Text(detail)
                    .foregroundStyle(.tertiary)
            }
            if let count {
                Text(count.formatted())
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
    }
}

/// A section of a dense pane: a rule, a name, and what is under it. The rule is
/// the container — there is no box, because a box would draw three more lines to
/// say what one already said.
///
/// `note` sits on the label's own line, right-aligned. It is where a promise goes
/// ("never exported"), never where an explanation goes: a caption that narrates
/// what is plainly on screen is read three times and then becomes wallpaper.
struct PaneSection<Content: View>: View {
    let title: String
    var note: String?
    /// The rule separates this section from the one above it. The first section on a
    /// surface has nothing above it to be separated from, and a rule drawn under a
    /// strip that already has one reads as a two-pixel line.
    var divides = true
    @ViewBuilder var content: Content

    init(_ title: String, note: String? = nil, divides: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self.note = note
        self.divides = divides
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.snug) {
            HStack(alignment: .firstTextBaseline, spacing: Space.small) {
                SectionLabel(title)
                Spacer(minLength: Space.tight)
                if let note {
                    Text(note)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Space.regular)
        .padding(.bottom, Space.tight)
        .overlay(alignment: .top) {
            if divides {
                Rectangle()
                    .fill(Palette.hairline)
                    .frame(height: 1)
            }
        }
    }
}

/// A section of a canvas: a rule, a name you can actually read, and room under it.
///
/// This is `PaneSection`'s bigger sibling and the difference is the whole point. An
/// inspector is a column of chrome three hundred points wide and it should be tight.
/// A canvas is the record itself, with the width of the window to work in — and the
/// same tight measurements applied there do not read as dense, they read as *dumped*:
/// six groups of unrelated facts jammed against one another with nothing to say where
/// one ends. The rule says where it ends. The gap says how much it matters.
struct Block<Content: View>: View {
    let title: String
    var caption: String?
    @ViewBuilder var content: Content

    init(_ title: String, caption: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.caption = caption
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.regular) {
            HStack(alignment: .firstTextBaseline, spacing: Space.medium) {
                Text(title)
                    .font(Chrome.heading)
                Spacer(minLength: Space.small)
                if let caption {
                    Text(caption)
                        .font(Chrome.small)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            content
        }
        .padding(.top, Space.wide)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.hairline)
                .frame(height: 1)
        }
    }
}

/// One short fact and its label, as a column.
///
/// Three of these across a canvas is a table you read in one movement. The same three
/// stacked as a form is four hundred points of empty page beside a column of
/// twenty-point fields, and a label so starved of room that "Also called" wraps onto
/// two lines to say one word.
struct Fact<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.tight) {
            SectionLabel(label)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The facts of a record, side by side across the page.
struct Facts<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: Space.section) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A small all-caps label that opens a group without demanding attention.
struct SectionLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(Chrome.micro)
            .tracking(0.5)
            .foregroundStyle(.tertiary)
    }
}

// MARK: - Atoms

/// A status dot. Always accompanied by text: colour is never the only cue.
struct StatusDot: View {
    let color: Color
    var filled = true

    var body: some View {
        Group {
            if filled {
                Circle().fill(color)
            } else {
                Circle().strokeBorder(color, lineWidth: 1.2)
            }
        }
        .frame(width: 6, height: 6)
        .accessibilityHidden(true)
    }
}

/// A token: a record named in the prose, a person in an event. Flat, because it is
/// a *thing*, not a button — the tinted capsule it used to be belonged to a pricing
/// page. Colour survives on the symbol, where it still says which kind this is.
struct Chip: View {
    let text: String
    var symbol: String?
    var tint: Color = .secondary
    var isTinted = false
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { label }
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        } else {
            label
        }
    }

    private var label: some View {
        HStack(spacing: Space.tight) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: Icon.inline, weight: .medium))
                    .foregroundStyle(tint)
            }
            Text(text)
                .font(Chrome.small)
                .foregroundStyle(isTinted ? tint : .primary)
                .lineLimit(1)
        }
        .padding(.horizontal, Space.snug)
        .padding(.vertical, 2)
        .background(Palette.subtleFill, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
    }
}

/// A keyboard shortcut rendered as a key.
struct KeyCap: View {
    let keys: String

    var body: some View {
        Text(keys)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, Space.tight + 1)
            .padding(.vertical, 1)
            .background(Palette.subtleFill, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

/// A label and its value on one line, the label right-aligned against a fixed
/// column. Stacked, these read as a table you can sweep down in one movement.
struct FieldRow<Value: View>: View {
    let label: String
    @ViewBuilder var value: Value

    init(_ label: String, @ViewBuilder value: () -> Value) {
        self.label = label
        self.value = value()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.small) {
            Text(label)
                .font(Chrome.small)
                .foregroundStyle(.secondary)
                .frame(width: Metrics.labelColumn, alignment: .trailing)
            value
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: Metrics.row)
    }
}

// MARK: - Editing affordances

/// A field that reads as text until you touch it: no box at rest, a hairline on
/// hover, an accent rule while you are in it. Used wherever the value *is* content
/// — a title, a name, a place — rather than a form to be completed.
struct QuietField: View {
    let placeholder: String
    @Binding var text: String
    var font: Font = Chrome.body
    var weight: Font.Weight = .regular

    @FocusState private var focused: Bool
    @State private var hovering = false

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(font.weight(weight))
            .focused($focused)
            .padding(.vertical, 2)
            .overlay(alignment: .bottom) { Underline(focused: focused, hovering: hovering) }
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.1), value: focused)
            .animation(.easeOut(duration: 0.1), value: hovering)
    }
}

/// The same affordance, over as many lines as the answer needs. It grows; it does
/// not scroll.
///
/// It is an `NSTextView`, and it has to be.
///
/// SwiftUI's `TextField(axis: .vertical)` looks exactly right and sizes itself, and
/// it is wrong in a way that costs the author work: **Return does not insert a
/// newline.** It ends editing, and the next keystroke arrives at a field whose
/// contents are entirely selected and replaces them — so a novelist typing a
/// paragraph into "the answer", hitting Return, and carrying on has just deleted the
/// paragraph. `TextEditor` keeps the text but cannot size itself to it, so it scrolls
/// its own contents inside a pane that is already scrolling, which is two scrollbars
/// fighting over one gesture and the author's own words hidden behind an arbitrary
/// height.
///
/// So: one text view, no scroller, reporting its laid-out height as its intrinsic
/// size. Return inserts a newline, ⌘Z undoes, and the field is exactly as tall as
/// what is in it.
struct QuietText: View {
    let placeholder: String
    @Binding var text: String
    var size: CGFloat = 12
    var minimumLines = 1

    @State private var focused = false
    @State private var hovering = false

    var body: some View {
        GrowingText(text: $text, size: size, minimumLines: minimumLines, focused: $focused)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: size))
                        .foregroundStyle(.tertiary)
                        .allowsHitTesting(false)
                }
            }
            .padding(.vertical, 2)
            .overlay(alignment: .bottom) { Underline(focused: focused, hovering: hovering) }
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.1), value: focused)
            .animation(.easeOut(duration: 0.1), value: hovering)
    }
}

private struct GrowingText: NSViewRepresentable {
    @Binding var text: String
    let size: CGFloat
    let minimumLines: Int
    @Binding var focused: Bool

    func makeNSView(context: Context) -> QuietTextView {
        let view = QuietTextView()
        view.delegate = context.coordinator
        view.isRichText = false
        view.importsGraphics = false
        view.allowsUndo = true
        view.drawsBackground = false
        view.isVerticallyResizable = false
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        // A novelist invents words. Nothing here may "fix" one.
        view.isAutomaticSpellingCorrectionEnabled = false
        view.isAutomaticQuoteSubstitutionEnabled = true
        view.isAutomaticDashSubstitutionEnabled = true
        view.string = text
        configure(view)
        return view
    }

    func updateNSView(_ view: QuietTextView, context: Context) {
        context.coordinator.parent = self
        if view.string != text { view.string = text }
        configure(view)
    }

    private func configure(_ view: QuietTextView) {
        let font = NSFont.systemFont(ofSize: size)
        view.font = font
        view.typingAttributes = [.font: font, .foregroundColor: NSColor.labelColor]
        view.textColor = .labelColor
        view.insertionPointColor = .controlAccentColor
        view.minimumLines = minimumLines
        view.invalidateIntrinsicContentSize()
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: GrowingText

        init(_ parent: GrowingText) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? QuietTextView else { return }
            view.invalidateIntrinsicContentSize()
            if parent.text != view.string { parent.text = view.string }
        }

        func textDidBeginEditing(_ notification: Notification) {
            if !parent.focused { parent.focused = true }
        }

        func textDidEndEditing(_ notification: Notification) {
            if parent.focused { parent.focused = false }
        }
    }
}

/// A text view that is as tall as its text, and no taller.
final class QuietTextView: NSTextView {
    var minimumLines = 1

    override var intrinsicContentSize: NSSize {
        guard let layoutManager, let textContainer else { return super.intrinsicContentSize }
        layoutManager.ensureLayout(for: textContainer)
        let used = layoutManager.usedRect(for: textContainer).height
        let face = font ?? .systemFont(ofSize: 12)
        let floor = layoutManager.defaultLineHeight(for: face) * CGFloat(minimumLines)
        return NSSize(width: NSView.noIntrinsicMetric, height: ceil(max(used, floor)))
    }

    /// The width is handed down by SwiftUI, and the height has to be recomputed
    /// against it — a paragraph that fit on two lines in a wide inspector needs four
    /// in a narrow one, and nothing else will tell us.
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        invalidateIntrinsicContentSize()
    }

    /// The pane scrolls; the field never does. It is exactly as tall as its text, so
    /// it has nothing of its own to scroll — and a text view that swallowed the wheel
    /// would make the inspector feel stuck whenever the pointer happened to be
    /// resting on an answer, which is most of the time. Say so, rather than trusting
    /// the responder chain to work it out.
    override func scrollWheel(with event: NSEvent) {
        if let next = nextResponder {
            next.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }
}

/// The whole affordance: one line, and only when it is needed.
private struct Underline: View {
    let focused: Bool
    let hovering: Bool

    var body: some View {
        Rectangle()
            .fill(focused ? Color.accentColor.opacity(0.7) : (hovering ? Palette.hairline : .clear))
            .frame(height: 1)
    }
}

/// A filter that lives in the pane it filters. `.searchable` would hoist it into
/// the window toolbar, which puts a scene filter as far from the scene list as the
/// window allows.
struct FilterField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: Space.tight) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: Icon.inline))
                .foregroundStyle(.tertiary)

            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(Chrome.small)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: Icon.inline))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .help("Clear filter")
            }
        }
        .padding(.horizontal, Space.snug)
        .frame(height: 19)
        .background(Palette.subtleFill, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        }
    }
}

// MARK: - Empty states

/// Empty states invite the next action; they never teach the tool and never
/// appear while the author is writing (11-UX, "Cognitive-load rules"). They are
/// the one surface in StoryLoom allowed to be spacious, because you see them on the
/// first day and then never again.
///
/// This wraps `ContentUnavailableView` rather than hand-rolling the layout. A
/// hand-rolled greedy view in a `NavigationSplitView` column stops the split view
/// from applying its title-bar safe area, and every column's content slides up
/// underneath the traffic lights. Apple's component already gets that right.
struct EmptyStateView: View {
    let icon: IconSource
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    init(
        symbol: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.init(icon: .system(symbol), title: title, message: message, actionTitle: actionTitle, action: action)
    }

    init(
        glyph: Glyph,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.init(icon: .glyph(glyph), title: title, message: message, actionTitle: actionTitle, action: action)
    }

    init(
        icon: IconSource,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
            } icon: {
                IconView(icon, size: Icon.display)
            }
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
            }
        }
        // It hugs its content otherwise, which turns any background painted behind it
        // into a floating card — the one thing this design does not do.
        .fillsColumn()
    }
}

// MARK: - Rows

/// A selectable row that highlights on hover without borrowing list chrome.
///
/// `padding` is not a detail. On a canvas a row carries two lines — a scene and the
/// sentence the character's name appears in — and four points of air around it is why
/// eight of them in a column read as one grey mass instead of eight things.
struct HoverRow<Content: View>: View {
    var isSelected = false
    var padding: CGFloat = Space.tight
    let action: () -> Void
    @ViewBuilder var content: Content

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Space.small)
                .padding(.vertical, padding)
                .background {
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.14) : (hovering ? Palette.hoverFill : .clear))
                }
                .contentShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - Layout

/// Wraps chips onto as many lines as they need.
struct FlowLayout: Layout {
    var spacing: CGFloat = Space.tight
    var lineSpacing: CGFloat = Space.tight

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + (x > 0 ? spacing : 0)
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: proposal.width ?? x, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Search text highlighting

/// Renders a snippet with matched ranges emphasised. Highlighting never touches
/// canonical prose (13-Search): it is a property of the result, not the document.
struct HighlightedText: View {
    let text: String
    let ranges: [Range<String.Index>]
    var font: Font = Chrome.small
    var lineLimit = 2

    var body: some View {
        build()
            .font(font)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func build() -> Text {
        var attributed = AttributedString(text)
        attributed.foregroundColor = .secondary

        for range in ranges where range.lowerBound >= text.startIndex && range.upperBound <= text.endIndex {
            guard let scoped = Range(range, in: attributed) else { continue }
            attributed[scoped].foregroundColor = .primary
            attributed[scoped].inlinePresentationIntent = .stronglyEmphasized
        }
        return Text(attributed)
    }
}

// MARK: - List density

extension View {
    /// A navigator list: short rows, and no room-name header above it.
    ///
    /// `defaultMinListRowHeight` is the whole density argument in one call. SwiftUI's
    /// sidebar rows are sized for a Settings pane with nine items in it; a manuscript
    /// has five hundred, and the author is looking for one.
    func denseList() -> some View {
        environment(\.defaultMinListRowHeight, Metrics.row)
    }

    /// Takes the whole column, so what is above it stays at the top of the column.
    ///
    /// A navigator is a filter bar with a `List` under it, and a `List` is greedy —
    /// so the bar sits at the top and everything works. Swap the list for an empty
    /// state, which hugs its own content, and the stack shrinks to fit; the column
    /// centres what is left, and the filter bar floats halfway down the pane with
    /// nothing above it. The empty state has to be as greedy as the list it replaces.
    func fillsColumn() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

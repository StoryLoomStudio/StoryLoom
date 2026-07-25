//
//  ManuscriptEditor.swift
//  StoryLoom
//
//  The authoritative creative surface (10-Editor). SwiftUI's TextEditor cannot
//  give a novelist a measured column, typewriter scrolling, a focused paragraph,
//  resilient annotation highlights, or the native find bar — so the page is an
//  NSTextView and everything around it is SwiftUI.
//
//  TextKit 2. The stack is assembled by hand in `makeNSView`, and the one rule
//  the whole file obeys is that `NSTextView.layoutManager` is never named: reading
//  that property is a compatibility trapdoor that silently drops the view back to
//  TextKit 1, taking the rendering attributes and fragment geometry below with it.
//
//  Display-only decoration — focus dimming, comment washes, reveal flashes — is
//  applied as *rendering* attributes (TextKit 1 called them temporary attributes;
//  the contract is identical). They never enter the text storage, never dirty the
//  document, and never appear in undo.
//
//  One thing was lost in the move and it is worth recording. Under TextKit 1 a
//  Markdown marker could be denied a glyph outright — `.null` from
//  `layoutManager(_:shouldGenerateGlyphs:…)` — so `**word**` was drawn as four
//  letters and the asterisks had no width at all. TextKit 2 has no glyph-generation
//  hook. Markers are now shrunk instead (see `ProseStyle.markerFont`): set at 0.1pt
//  with that width kerned back out, which is invisible in practice and leaves a
//  sub-pixel residue at extreme zoom. The characters stay in the text either way,
//  which is the part that matters — the file is still Markdown.
//

import AppKit
import SwiftUI

// MARK: - Editor state shared with SwiftUI

nonisolated struct EditorSelection: Equatable {
    var range = NSRange(location: 0, length: 0)
    var text = ""
    /// The emphasis the author would be writing in if they typed right now. Read
    /// straight off the styled text, so it is whatever the page is actually showing.
    var formats: Set<InlineFormat> = []

    var isEmpty: Bool { range.length == 0 }
}

/// A request to scroll to a passage and flash it — used by search results and by
/// finding evidence. The token makes repeated reveals of the same range distinct.
nonisolated struct RevealRequest: Equatable {
    var token = UUID()
    var range: NSRange
}

/// Edits the surrounding UI can ask the page to make. They go through AppKit's
/// own text-change machinery so that undo, autosave, and styling all behave as
/// if the author had typed them.
/// Note what is *not* here: paragraph alignment, and a highlight applied as a
/// colour attribute. Both were offered on the format bar and neither could survive
/// the next keystroke — a document is a Markdown string, so an attribute the text
/// does not spell is wiped by the very next restyle of that paragraph, never
/// reaches the file, and never reaches an export. Highlight earned its place back
/// by becoming real text (`==like this==`); alignment has no Markdown to become,
/// and a manuscript is set flush left.
nonisolated enum EditorCommand: Equatable {
    case format(InlineFormat)
    case blockquote
    case sceneBreak
    /// Heading level 1–3, or 0 to make it body prose again. Real Markdown: `#`.
    case heading(Int)
    /// A bulleted or numbered list. Real Markdown: `- ` / `1. `.
    case list(ordered: Bool)
    // Below here nothing is text. These go to the presentation layer beside the
    // file rather than into it — see `Presentation.swift` for why.
    case underline
    case highlight(HighlightColour?)
    case alignment(TextAlignmentChoice)
    case face(String?)
    case size(Double?)
}

nonisolated struct EditorCommandRequest: Equatable {
    var token = UUID()
    var command: EditorCommand
}

/// Text services the author controls. Autocorrect is deliberately absent: a
/// novelist invents words, and a tool that "fixes" them is an adversary.
nonisolated struct TextBehaviour: Equatable, Sendable {
    var checksSpelling = true
    var checksGrammar = false
    var smartQuotes = true
    var smartDashes = true
}

// MARK: - Representable

struct ManuscriptEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var selection: EditorSelection

    let documentID: UUID
    let style: ProseStyle
    /// Anchors for this document's comments. Resolved here so a moved anchor
    /// lights up in the right place without the model recomputing offsets.
    var commentAnchors: [TextAnchor] = []
    /// Names offered when the author types "@". The completion inserts the plain
    /// name: prose stays readable, and Story Brain links it by name (05-Format).
    var mentionNames: [String] = []
    var reveal: RevealRequest?
    var command: EditorCommandRequest?
    var behaviour = TextBehaviour()
    var onCommentRequest: ((NSRange) -> Void)?
    var onFormat: ((InlineFormat) -> Void)?
    var onCreateRecord: ((String) -> Void)?
    /// Appearance the Markdown cannot spell. Handed down so the styler can
    /// re-apply it after every restyle, and handed back up whenever an edit
    /// moves it, so the model can save it.
    var presentation = PresentationLayer()
    var onPresentationChange: ((PresentationLayer) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> ManuscriptScrollView {
        // TextKit 2. The stack is assembled by hand rather than left to
        // `NSTextView(frame:)` because the container has to be configured before
        // the view adopts it, and because *touching* `textView.layoutManager`
        // anywhere afterwards silently drops the whole view back to TextKit 1 —
        // it is a compatibility trapdoor, not an accessor, and nothing below may
        // step on it.
        let contentStorage = NSTextContentStorage()
        let layoutManager = NSTextLayoutManager()
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0
        layoutManager.textContainer = container
        contentStorage.addTextLayoutManager(layoutManager)
        let storage = contentStorage.textStorage ?? NSTextStorage()

        let textView = ManuscriptTextView(frame: .zero, textContainer: container)
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.usesRuler = false
        textView.usesFontPanel = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.delegate = context.coordinator
        textView.onCommentRequest = { [weak coordinator = context.coordinator] range in
            coordinator?.parent.onCommentRequest?(range)
        }
        textView.onFormat = { [weak coordinator = context.coordinator] format in
            coordinator?.parent.onFormat?(format)
        }
        textView.onCreateRecord = { [weak coordinator = context.coordinator] name in
            coordinator?.parent.onCreateRecord?(name)
        }
        storage.delegate = context.coordinator

        let scrollView = ManuscriptScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.onGeometryChange = { [weak coordinator = context.coordinator] in
            coordinator?.updateGeometry()
        }

        context.coordinator.attach(textView: textView, scrollView: scrollView)
        context.coordinator.load(text: text, documentID: documentID)
        context.coordinator.apply(style: style)
        context.coordinator.apply(behaviour: behaviour)

        // Focus dimming has to follow the reader, not just the caret.
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.viewportMoved),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        return scrollView
    }

    func updateNSView(_ scrollView: ManuscriptScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        if coordinator.documentID != documentID {
            coordinator.load(text: text, documentID: documentID)
        } else if coordinator.textView?.string != text {
            coordinator.replaceTextPreservingCaret(with: text)
        }

        if coordinator.style != style {
            coordinator.apply(style: style)
        }
        if coordinator.behaviour != behaviour {
            coordinator.apply(behaviour: behaviour)
        }

        coordinator.refreshDecorations()
        coordinator.perform(reveal: reveal)
        coordinator.perform(command: command)
    }

    static func dismantleNSView(_ scrollView: ManuscriptScrollView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var parent: ManuscriptEditor
        private(set) var textView: ManuscriptTextView?
        private(set) var scrollView: ManuscriptScrollView?
        private(set) var documentID: UUID?
        private(set) var style = ProseStyle()
        private(set) var behaviour = TextBehaviour()
        /// The live layer. Kept here rather than read from `parent` on demand
        /// because it is mutated by edits between SwiftUI updates.
        var presentation = PresentationLayer()

        /// Reached through the text view rather than stored, so there is exactly
        /// one owner of the stack. Note the deliberate absence of `layoutManager`
        /// (the TextKit 1 one): reading that property is what drops an
        /// `NSTextView` back to the old engine, so it is never named below.
        var layoutManager: NSTextLayoutManager? { textView?.textLayoutManager }
        var contentStorage: NSTextContentStorage? { textView?.textContentStorage }

        /// Guards the binding from echoing programmatic edits back into the model.
        private var isLoading = false
        private var lastRevealToken: UUID?
        private var lastCommandToken: UUID?
        private var revealRange: NSRange?
        private var revealDismissal: Task<Void, Never>?
        private var shouldOfferMentions = false

        init(_ parent: ManuscriptEditor) {
            self.parent = parent
        }

        func attach(textView: ManuscriptTextView, scrollView: ManuscriptScrollView) {
            self.textView = textView
            self.scrollView = scrollView
        }

        // MARK: Loading

        func load(text: String, documentID: UUID) {
            guard let textView, let storage = textView.textStorage else { return }
            isLoading = true
            self.documentID = documentID
            // Offsets from a previous session may be stale — the file could have
            // been edited elsewhere — so every span re-finds its words here, and
            // any that cannot are dropped rather than guessed at.
            presentation = parent.presentation
            presentation.reanchor(in: text)
            storage.setAttributedString(NSAttributedString(string: text, attributes: ProseStyler.typingAttributes(style)))
            restyleEverything()
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            textView.undoManager?.removeAllActions()
            scrollView?.contentView.scroll(to: NSPoint(x: 0, y: -(scrollView?.contentInsets.top ?? 0)))
            scrollView.map { $0.reflectScrolledClipView($0.contentView) }
            isLoading = false
            refreshDecorations()
            reportSelection()
        }

        /// Used when the model replaces text under us — a snapshot restore, or an
        /// external edit picked up from disk. The caret is kept where it can be.
        func replaceTextPreservingCaret(with text: String) {
            guard let textView, let storage = textView.textStorage else { return }
            isLoading = true
            let caret = textView.selectedRange()
            storage.setAttributedString(NSAttributedString(string: text, attributes: ProseStyler.typingAttributes(style)))
            restyleEverything()
            textView.setSelectedRange(caret.clamped(to: (text as NSString).length))
            isLoading = false
        }

        // MARK: Style

        func apply(style: ProseStyle) {
            self.style = style
            guard let textView, let scrollView else { return }

            textView.style = style
            textView.backgroundColor = style.pageColor
            textView.drawsBackground = style.viewMode != .page
            textView.insertionPointColor = style.caretColor
            textView.selectedTextAttributes = [.backgroundColor: style.selectionColor]
            textView.typingAttributes = ProseStyler.typingAttributes(style)
            textView.defaultParagraphStyle = ProseStyler.bodyParagraphStyle(style)
            scrollView.backgroundColor = style.viewMode == .page ? NSColor.controlBackgroundColor.withAlphaComponent(0.6) : style.pageColor
            scrollView.typewriterEnabled = style.typewriter

            restyleEverything()
            updateGeometry()
            refreshDecorations()
            if style.typewriter { scrollToTypewriterLine(animated: false) }
        }

        /// Spelling and substitution are author preferences, not style, so they
        /// arrive separately and are applied whenever they change.
        func apply(behaviour: TextBehaviour) {
            self.behaviour = behaviour
            guard let textView else { return }
            textView.isContinuousSpellCheckingEnabled = behaviour.checksSpelling
            textView.isGrammarCheckingEnabled = behaviour.checksGrammar
            textView.isAutomaticQuoteSubstitutionEnabled = behaviour.smartQuotes
            textView.isAutomaticTextReplacementEnabled = behaviour.smartQuotes
            textView.isAutomaticDashSubstitutionEnabled = behaviour.smartDashes
            // Autocorrect rewrites an author's invented words. It is never on.
            textView.isAutomaticSpellingCorrectionEnabled = false
        }

        /// Applies an edit requested by the surrounding UI.
        ///
        /// What the edit *is* was decided by `InlineMarkup`, which knows nothing
        /// about AppKit. All that happens here is applying it, and applying it the
        /// long way round — `shouldChangeText`, then the storage, then
        /// `didChangeText` — because that is what makes it a real authorial edit:
        /// undoable with ⌘Z, coalesced with the typing around it, and restyled by
        /// the same delegate that handles a keystroke.
        func perform(command request: EditorCommandRequest?) {
            guard let request, request.token != lastCommandToken, let textView else { return }
            lastCommandToken = request.token

            let string = textView.string as NSString
            let selection = textView.selectedRange()

            switch request.command {
            case .format(let format):
                if let edit = InlineMarkup.toggle(format, in: string, selection: selection) { apply(edit) }
            case .blockquote:
                if let edit = InlineMarkup.blockquote(in: string, selection: selection) { apply(edit) }
            case .sceneBreak:
                apply(InlineMarkup.sceneBreak(in: string, selection: selection))
            case .heading(let level):
                if let edit = InlineMarkup.heading(level, in: string, selection: selection) { apply(edit) }
            case .list(let ordered):
                if let edit = InlineMarkup.list(ordered: ordered, in: string, selection: selection) { apply(edit) }

            case .underline:
                mutatePresentation { layer, range, text in
                    let on = layer.attributes(at: range).underline
                    layer.setRun(range, in: text) { $0.underline = !on }
                }
            case .highlight(let colour):
                mutatePresentation { layer, range, text in
                    layer.setRun(range, in: text) { $0.highlight = colour }
                }
            case .face(let name):
                mutatePresentation { layer, range, text in
                    layer.setRun(range, in: text) { $0.fontName = name }
                }
            case .size(let points):
                mutatePresentation { layer, range, text in
                    layer.setRun(range, in: text) { $0.fontSize = points }
                }
            case .alignment(let choice):
                mutatePresentation(requiresSelection: false) { layer, range, text in
                    layer.setAlignment(choice, over: range, in: text)
                }
            }
        }

        /// Change the presentation layer over the selection, then repaint.
        ///
        /// No text is replaced, so this never touches the undo stack — which is
        /// correct: the manuscript did not change. What changed is how this
        /// machine is showing it.
        private func mutatePresentation(
            requiresSelection: Bool = true,
            _ change: (inout PresentationLayer, NSRange, String) -> Void
        ) {
            guard let textView else { return }
            let text = textView.string
            var range = textView.selectedRange()
            if range.length == 0 {
                guard !requiresSelection else { return }
                range = (text as NSString).paragraphRange(for: range)
            }
            change(&presentation, range, text)
            parent.onPresentationChange?(presentation)
            restyleEverything()
            refreshDecorations()
        }

        private func apply(_ edit: TextEdit) {
            guard let textView, let storage = textView.textStorage else { return }
            guard textView.shouldChangeText(in: edit.range, replacementString: edit.replacement) else { return }
            storage.replaceCharacters(in: edit.range, with: edit.replacement)
            textView.didChangeText()
            textView.setSelectedRange(edit.selection.clamped(to: (textView.string as NSString).length))
        }

        private func restyleEverything() {
            guard let textView, let storage = textView.textStorage else { return }
            ProseStyler.applyAttributes(
                to: storage,
                range: NSRange(location: 0, length: storage.length),
                style: style,
                presentation: presentation
            )
        }

        // MARK: Geometry

        /// Centres a measured column of text in whatever width the window gives us.
        /// The container tracks the text view's width, so setting the inset is
        /// enough — the column narrows and the page keeps its margins.
        func updateGeometry() {
            guard let textView, textView.frame.width > 1 else { return }
            let available = textView.frame.width

            let minimumSide: CGFloat = 28
            let target = min(style.measureWidth, max(280, available - minimumSide * 2))
            let inset = max(minimumSide, ((available - target) / 2).rounded())
            let topInset = style.topTextInset

            if abs(textView.textContainerInset.width - inset) > 0.5 || abs(textView.textContainerInset.height - topInset) > 0.5 {
                textView.textContainerInset = NSSize(width: inset, height: topInset)
            }
        }

        // MARK: Decoration (rendering attributes only)

        /// TextKit 1 called these *temporary* attributes; TextKit 2 calls them
        /// *rendering* attributes. Same contract, and it is the contract that
        /// matters: display-only, never in the text storage, never in the
        /// document, never in undo. Focus dimming and comment washes are things
        /// the author is shown, not things they wrote.
        func refreshDecorations() {
            updateCommentWashes()
            updateFocusDimming()
        }

        /// The document as a text range, for the whole-document clears below.
        private var documentTextRange: NSTextRange? {
            layoutManager?.documentRange
        }

        /// Translate a character range into the text range TextKit 2 speaks.
        func textRange(_ range: NSRange) -> NSTextRange? {
            guard let contentStorage,
                  let start = contentStorage.location(contentStorage.documentRange.location, offsetBy: range.location),
                  let end = contentStorage.location(start, offsetBy: range.length)
            else { return nil }
            return NSTextRange(location: start, end: end)
        }

        private func updateCommentWashes() {
            guard let textView, let layoutManager, let full = documentTextRange else { return }
            let length = (textView.string as NSString).length
            layoutManager.removeRenderingAttribute(.backgroundColor, for: full)

            for anchor in parent.commentAnchors {
                guard let resolved = anchor.resolve(in: textView.string),
                      let range = textRange(resolved.clamped(to: length)) else { continue }
                layoutManager.addRenderingAttribute(.backgroundColor, value: style.commentWashColor, for: range)
            }

            if let revealRange, revealRange.location != NSNotFound,
               let range = textRange(revealRange.clamped(to: length)) {
                layoutManager.addRenderingAttribute(.backgroundColor, value: style.revealWashColor, for: range)
            }
        }

        private func updateFocusDimming() {
            guard let textView, let layoutManager, let full = documentTextRange else { return }

            let string = textView.string as NSString
            layoutManager.removeRenderingAttribute(.foregroundColor, for: full)

            guard style.focus != .off,
                  let focus = ProseStyler.focusRange(in: string, selection: textView.selectedRange(), depth: style.focus)
            else { return }

            // Only what is on screen needs dimming; scrolling refreshes the rest.
            // TextKit 2 lays out by viewport, so the range it has actually laid out
            // *is* the visible range — there is no glyph store to interrogate.
            let visible = viewportCharacterRange() ?? NSRange(location: 0, length: string.length)
            let start = visible.location
            let end = NSMaxRange(visible)
            let focusStart = focus.location
            let focusEnd = NSMaxRange(focus)

            func dim(_ range: NSRange) {
                guard range.length > 0, let target = textRange(range) else { return }
                layoutManager.addRenderingAttribute(.foregroundColor, value: style.mutedColor, for: target)
            }

            if start < focusStart {
                dim(NSRange(location: start, length: min(end, focusStart) - start))
            }
            if focusEnd < end {
                let location = max(start, focusEnd)
                dim(NSRange(location: location, length: end - location))
            }
        }

        /// The character range currently laid out for the viewport.
        private func viewportCharacterRange() -> NSRange? {
            guard let layoutManager, let contentStorage,
                  let viewport = layoutManager.textViewportLayoutController.viewportRange
            else { return nil }
            let start = contentStorage.offset(from: contentStorage.documentRange.location, to: viewport.location)
            let end = contentStorage.offset(from: contentStorage.documentRange.location, to: viewport.endLocation)
            guard start >= 0, end >= start else { return nil }
            return NSRange(location: start, length: end - start)
        }

        // MARK: Reveal

        func perform(reveal request: RevealRequest?) {
            guard let request, request.token != lastRevealToken, let textView else { return }
            lastRevealToken = request.token

            let full = (textView.string as NSString).length
            let range = request.range.clamped(to: full)
            guard range.length > 0 || full == 0 else { return }

            textView.setSelectedRange(range)
            textView.scrollRangeToVisible(range)
            revealRange = range
            updateCommentWashes()

            revealDismissal?.cancel()
            revealDismissal = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(1400))
                guard !Task.isCancelled else { return }
                self?.revealRange = nil
                self?.updateCommentWashes()
            }
        }

        // MARK: Typewriter

        /// Where the caret is, in container coordinates.
        ///
        /// TextKit 1 answered this by asking the glyph store for a bounding rect.
        /// TextKit 2 has no glyph store: the question is put to the layout manager
        /// as "what is the frame of this text segment", which is the same answer
        /// arrived at without a glyph ever being named.
        private func caretFrame() -> NSRect? {
            guard let layoutManager,
                  let caret = textRange(NSRange(location: textView?.selectedRange().location ?? 0, length: 0))
            else { return nil }

            var frame: NSRect?
            layoutManager.enumerateTextSegments(in: caret, type: .standard, options: []) { _, segment, _, _ in
                frame = segment
                return false
            }
            // A caret at the very end of the document has no segment of its own;
            // the last laid-out fragment is the honest answer there.
            if frame == nil, let last = layoutManager.textLayoutFragment(for: caret.location) {
                frame = last.layoutFragmentFrame
            }
            return frame
        }

        private func scrollToTypewriterLine(animated: Bool) {
            guard style.typewriter,
                  let textView,
                  let scrollView,
                  var rect = caretFrame() else { return }
            rect.origin.y += textView.textContainerOrigin.y

            let clip = scrollView.contentView
            let anchorLine = clip.bounds.height * 0.42
            let target = rect.midY - anchorLine
            let lowest = -scrollView.contentInsets.top
            let highest = max(lowest, textView.frame.height + scrollView.contentInsets.bottom - clip.bounds.height)
            let y = min(max(target, lowest), highest)

            guard abs(clip.bounds.origin.y - y) > 0.5 else { return }
            let destination = NSPoint(x: 0, y: y)
            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.12
                    context.allowsImplicitAnimation = true
                    clip.animator().setBoundsOrigin(destination)
                }
            } else {
                clip.setBoundsOrigin(destination)
            }
            scrollView.reflectScrolledClipView(clip)
        }

        // MARK: Selection reporting

        /// The selection is *what* is selected, not where it sits on screen.
        ///
        /// It used to carry a rectangle too, so a bar could float above the words —
        /// which meant every scroll event re-measured the glyph run and pushed a new
        /// value into SwiftUI. The bar is gone (its four actions live in the page's
        /// own context menu, where a Mac user looks for them and where they do not
        /// cover the sentence being edited), and with it goes a layout query on every
        /// frame of every scroll.
        private func reportSelection() {
            guard let textView, let storage = textView.textStorage else { return }
            let string = textView.string as NSString
            let safe = textView.selectedRange().clamped(to: string.length)
            let next = EditorSelection(
                range: safe,
                text: string.substring(with: safe),
                formats: formats(at: safe, in: storage)
            )
            if parent.selection != next {
                parent.selection = next
            }
        }

        /// What the format bar lights up — which is not "what is selected" but *what
        /// the author would be writing in if they typed right now*. So it reads the
        /// character behind the caret, exactly as AppKit does when it decides what
        /// attributes the next keystroke inherits, and the answer is the same one the
        /// page is already showing.
        private func formats(at selection: NSRange, in storage: NSTextStorage) -> Set<InlineFormat> {
            let index = selection.length > 0 ? selection.location : selection.location - 1
            guard index >= 0, index < storage.length else { return [] }
            guard let value = storage.attribute(.inlineFormat, at: index, effectiveRange: nil) as? NSNumber
            else { return [] }
            return InlineFormat.formats(bits: value.intValue)
        }

        @objc func viewportMoved() {
            updateFocusDimming()
        }

        // MARK: NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard !isLoading, let textView else { return }
            parent.text = textView.string
            refreshDecorations()
            reportSelection()

            if style.typewriter {
                scrollToTypewriterLine(animated: false)
            }
            if shouldOfferMentions {
                shouldOfferMentions = false
                if !parent.mentionNames.isEmpty {
                    textView.complete(nil)
                }
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isLoading else { return }
            updateFocusDimming()
            reportSelection()

            // Recentre for the keyboard, never for the mouse: a click that yanks
            // the page out from under the pointer feels broken.
            if style.typewriter, NSApp.currentEvent?.type == .keyDown {
                scrollToTypewriterLine(animated: true)
            }
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            if replacementString == "@" { shouldOfferMentions = true }
            return true
        }

        func textView(
            _ textView: NSTextView,
            completions words: [String],
            forPartialWordRange charRange: NSRange,
            indexOfSelectedItem index: UnsafeMutablePointer<Int>?
        ) -> [String] {
            let string = textView.string as NSString
            let partial = string.substring(with: charRange.clamped(to: string.length))
            guard partial.hasPrefix("@") else { return words }

            let fragment = String(partial.dropFirst()).trimmingCharacters(in: .whitespaces)
            let names = parent.mentionNames
            guard !fragment.isEmpty else { return names }
            return names.filter { $0.localizedCaseInsensitiveContains(fragment) }
        }

        // MARK: NSTextStorageDelegate

        /// Restyling belongs here: the edited range is exact, so a keystroke costs
        /// one paragraph of work rather than a whole scene. Attribute changes are
        /// explicitly permitted at this point; character changes are not.
        nonisolated func textStorage(
            _ textStorage: NSTextStorage,
            didProcessEditing editedMask: NSTextStorageEditActions,
            range editedRange: NSRange,
            changeInLength delta: Int
        ) {
            guard editedMask.contains(.editedCharacters) else { return }
            MainActor.assumeIsolated {
                // Move the presentation spans through this edit first: the restyle
                // below re-applies them, and it has to be given the new positions,
                // not last keystroke's.
                if !presentation.isEmpty {
                    presentation.adjust(editedRange: editedRange, delta: delta)
                    parent.onPresentationChange?(presentation)
                }
                let string = textStorage.string as NSString
                let paragraphs = string.paragraphRange(for: editedRange.clamped(to: string.length))
                ProseStyler.applyAttributes(to: textStorage, range: paragraphs, style: style,
                                            presentation: presentation, wrapInEditing: false)
            }
        }

    }
}

// MARK: - Text view

final class ManuscriptTextView: NSTextView {
    var onCommentRequest: ((NSRange) -> Void)?
    var onFormat: ((InlineFormat) -> Void)?
    var onCreateRecord: ((String) -> Void)?

    /// Held here because the quote rules are drawn here. Under TextKit 1 this
    /// lived on a layout-manager subclass, which was the natural home for
    /// `drawBackground(forGlyphRange:at:)`. TextKit 2 has no layout manager to
    /// subclass and no background-drawing hook on it, so the drawing moves to the
    /// view and the style follows it.
    var style = ProseStyle() {
        didSet { needsDisplay = true }
    }

    /// The rule in the margin of a blockquote.
    ///
    /// Rewritten for TextKit 2, and it is the one piece of drawing that got
    /// *simpler*: fragments already know their own frames, so the vertical extent
    /// of a wrapped quote is the union of its fragments rather than a glyph-range
    /// query, and there is no container origin to add back by hand — which is
    /// exactly the arithmetic that used to put the bar an inset below its words.
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let layoutManager = textLayoutManager,
              let contentStorage = textContentStorage,
              let storage = contentStorage.textStorage,
              storage.length > 0
        else { return }

        let barColor = style.inkColor.withAlphaComponent(0.30)
        let origin = textContainerOrigin

        layoutManager.enumerateTextLayoutFragments(
            from: layoutManager.documentRange.location,
            options: [.ensuresLayout]
        ) { fragment in
            var frame = fragment.layoutFragmentFrame
            frame.origin.x += origin.x
            frame.origin.y += origin.y
            // Fragments arrive in order, so the first one past the bottom of the
            // dirty rect ends the walk rather than the document.
            guard frame.minY <= dirtyRect.maxY else { return false }
            guard frame.maxY >= dirtyRect.minY else { return true }

            let start = contentStorage.offset(
                from: contentStorage.documentRange.location,
                to: fragment.rangeInElement.location
            )
            guard start >= 0, start < storage.length,
                  storage.attribute(.blockquote, at: start, effectiveRange: nil) != nil
            else { return true }

            let indent = (storage.attribute(.paragraphStyle, at: start, effectiveRange: nil)
                as? NSParagraphStyle)?.headIndent ?? 0

            let rect = NSRect(
                x: origin.x + indent - 12,
                y: frame.minY + 1,
                width: 3,
                height: frame.height - 2
            )
            barColor.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 1.5, yRadius: 1.5).fill()
            return true
        }
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        textContainerInset = NSSize(width: 28, height: 48)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        textContainerInset = NSSize(width: 28, height: 48)
    }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn: Bool) {
        guard let coordinator = (delegate as? ManuscriptEditor.Coordinator),
              coordinator.style.viewMode == .page else {
            super.drawInsertionPoint(in: rect, color: color, turnedOn: turnedOn)
            return
        }

        let topInset = textContainerInset.height
        var adjusted = rect
        if adjusted.origin.y < topInset {
            let fontHeight: CGFloat = font?.pointSize ?? 16
            adjusted.origin.y = topInset
            adjusted.size.height = fontHeight * 1.2
        }

        super.drawInsertionPoint(in: adjusted, color: color, turnedOn: turnedOn)
    }

    override func drawBackground(in rect: NSRect) {
        guard let coordinator = (delegate as? ManuscriptEditor.Coordinator) else {
            super.drawBackground(in: rect)
            return
        }

        if coordinator.style.viewMode == PageViewMode.page {
            // Desk background
            NSColor.controlBackgroundColor.withAlphaComponent(0.6).setFill()
            rect.fill()

            // Calculate paper card bounds
            let available = bounds.width
            let minimumSide: CGFloat = 28
            let target = min(coordinator.style.measureWidth, max(280, available - minimumSide * 2))
            let inset = max(minimumSide, ((available - target) / 2).rounded())

            let paperRect = NSRect(
                x: inset - 20,
                y: 12,
                width: target + 40,
                height: max(bounds.height - 24, (enclosingScrollView?.bounds.height ?? bounds.height) - 24)
            )

            // Draw card shadow
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(coordinator.style.pageAppearance == .dark ? 0.4 : 0.08)
            shadow.shadowOffset = NSSize(width: 0, height: -3)
            shadow.shadowBlurRadius = 8
            shadow.set()

            coordinator.style.pageColor.setFill()
            let path = NSBezierPath(roundedRect: paperRect, xRadius: 8, yRadius: 8)
            path.fill()
            NSGraphicsContext.restoreGraphicsState()

            // Draw card border
            NSGraphicsContext.saveGraphicsState()
            NSColor.separatorColor.withAlphaComponent(0.35).setStroke()
            let borderPath = NSBezierPath(roundedRect: paperRect, xRadius: 8, yRadius: 8)
            borderPath.lineWidth = 1
            borderPath.stroke()
            NSGraphicsContext.restoreGraphicsState()
        } else {
            super.drawBackground(in: rect)
        }
    }

    // MARK: Invisible markers

    /// Is the character at `index` part of a marker the page is not drawing?
    ///
    /// The styler is the only thing that knows, and it says so in an attribute, so
    /// this asks the text rather than parsing it again. What the caret believes is
    /// hidden is therefore exactly what the page has hidden — there is no second
    /// opinion to drift out of step.
    private func markerRun(at index: Int) -> MarkerRun? {
        guard let storage = textStorage, index >= 0, index < storage.length else { return nil }
        var range = NSRange(location: 0, length: 0)
        guard let value = storage.attribute(.marker, at: index, effectiveRange: &range) as? NSNumber,
              let side = MarkerSide(rawValue: value.intValue)
        else { return nil }
        return MarkerRun(range, side)
    }

    /// The caret may not stand inside a run it cannot see, and a selection may not
    /// cut one in half. Both are decided by `Markers`; this is only where AppKit
    /// hands over the proposal.
    override func setSelectedRanges(
        _ ranges: [NSValue],
        affinity: NSSelectionAffinity,
        stillSelecting: Bool
    ) {
        let legal = ranges.map { value in
            NSValue(range: Markers.selection(value.rangeValue, run: markerRun(at:)))
        }
        super.setSelectedRanges(legal, affinity: affinity, stillSelecting: stillSelecting)
    }

    /// Typing beside a hidden marker inherits its attributes, which would make the
    /// author's next keystroke invisible. It is corrected on the next restyle either
    /// way; correcting it here means it is never even briefly true.
    override var typingAttributes: [NSAttributedString.Key: Any] {
        get { super.typingAttributes }
        set {
            var clean = newValue
            clean.removeValue(forKey: .marker)
            clean.removeValue(forKey: .inlineFormat)
            super.typingAttributes = clean
        }
    }

    // MARK: Paste

    /// Rich text pasted from a browser arrives as Markdown.
    ///
    /// A novelist researching a scene copies out of Safari, Notion, or a chat
    /// window, and what the pasteboard offers is HTML. Taking the plain-text
    /// flavour throws away every heading, list, and emphasis in it; taking the
    /// HTML flavour into a Markdown file is worse. Converting means the structure
    /// survives *as Markdown*, which is what the file is made of.
    ///
    /// Only when the HTML actually carries block structure. A casually copied
    /// bold word or link is inline-only, and running it through the converter
    /// would sprinkle markup into a sentence that did not ask for any.
    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        if let html = pasteboard.string(forType: .html),
           Self.hasBlockStructure(html),
           let markdown = HTMLToMarkdownConverter.markdown(fromHTML: html),
           !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Fenced on both sides. The paste goes in through `insertText`, which
            // is the typing path, so without this the next thing the author types
            // coalesces into it and a single ⌘Z takes back both — the paste and
            // the sentence they wrote after it.
            breakUndoCoalescing()
            insertText(markdown, replacementRange: selectedRange())
            breakUndoCoalescing()
            return
        }
        super.paste(sender)
    }

    private static func hasBlockStructure(_ html: String) -> Bool {
        // `li` on its own because Chromium serialises a selection inside a list
        // as bare <li> elements with no <ul> around them.
        let blockTags = ["ul", "ol", "li", "h1", "h2", "h3", "h4", "h5", "h6",
                         "blockquote", "pre", "table", "p"]
        let lowered = html.lowercased()
        return blockTags.contains { lowered.contains("<\($0)") }
    }

    // MARK: Caret

    /// FB22524198: with TextKit 2, a caret on the empty last line of a document
    /// that ends in a newline is drawn at the *top of the previous line* instead
    /// of below it. It is AppKit's bug, not ours, and it shows up the moment a
    /// scene ends with a blank line — which every scene does.
    ///
    /// The fix is to snap the indicator to the bottom of the last laid-out line
    /// plus that paragraph's spacing. Layout-fragment coordinates are relative to
    /// the text container and the indicator's frame is relative to the view, so
    /// the container inset has to be added back or the snap lands wrong on a
    /// page-mode inset.
    override func updateInsertionPointStateAndRestartTimer(_ restartFlag: Bool) {
        super.updateInsertionPointStateAndRestartTimer(restartFlag)
        DispatchQueue.main.async { [weak self] in self?.snapTrailingCaret() }
    }

    private func snapTrailingCaret() {
        guard let storage = textStorage,
              let layoutManager = textLayoutManager,
              let contentStorage = textContentStorage,
              let indicator = subviews.first(where: { type(of: $0) == NSTextInsertionIndicator.self })
        else { return }

        let text = storage.string as NSString
        let selection = selectedRange()
        guard selection.length == 0, selection.location == text.length, text.length > 0,
              text.character(at: text.length - 1) == 0x0A,
              let trailing = contentStorage.location(contentStorage.documentRange.location, offsetBy: text.length - 1)
        else { return }

        var desiredY: CGFloat?
        layoutManager.enumerateTextLayoutFragments(from: trailing, options: [.ensuresLayout]) { fragment in
            // The last line *with content* — a wrapped paragraph must not be
            // pulled back up to its first line.
            guard let line = fragment.textLineFragments.last(where: { $0.characterRange.length > 0 })
                ?? fragment.textLineFragments.last else { return false }
            let paragraph = storage.attribute(.paragraphStyle, at: text.length - 1, effectiveRange: nil) as? NSParagraphStyle
            desiredY = fragment.layoutFragmentFrame.origin.y
                + line.typographicBounds.maxY
                + (paragraph?.paragraphSpacing ?? 0)
                + self.textContainerInset.height
            return false
        }
        guard let desiredY, abs(indicator.frame.origin.y - desiredY) >= 0.5 else { return }
        indicator.frame.origin.y = desiredY
    }

    // MARK: Lists

    /// Return continues a list or a quote; Tab indents an item.
    ///
    /// It goes through `shouldChangeText`/`didChangeText` like every other edit
    /// the app makes on the author's behalf, so it coalesces with the typing
    /// around it and one ⌘Z takes it back.
    override func insertNewline(_ sender: Any?) {
        guard !performListEdit(for: "\n") else { return }
        super.insertNewline(sender)
    }

    override func insertTab(_ sender: Any?) {
        guard !performListEdit(for: "\t") else { return }
        super.insertTab(sender)
    }

    private func performListEdit(for replacement: String) -> Bool {
        guard let storage = textStorage else { return false }
        let selection = selectedRange()
        guard selection.length == 0 else { return false }

        // Markdown inside a fenced block is not markup, it is content: a `-` in
        // a code sample must stay a `-`.
        guard !isInsideCodeBlock(at: selection.location) else { return false }

        guard let edit = MarkdownInput.edit(for: replacement, at: selection, in: storage.string as NSString)
        else { return false }
        guard shouldChangeText(in: edit.range, replacementString: edit.replacement) else { return true }
        storage.replaceCharacters(in: edit.range, with: edit.replacement)
        didChangeText()
        setSelectedRange(edit.selection.clamped(to: (string as NSString).length))
        return true
    }

    /// Asked of the parser rather than guessed at, so a `-` inside ``` fences is
    /// left alone for the same reason the styler leaves it alone.
    private func isInsideCodeBlock(at location: Int) -> Bool {
        let text = string
        guard text.contains("`") else { return false }
        return BlockParser.parse(text, registry: .manuscript).contains { block in
            block.kind == .fencedCode && NSLocationInRange(location, block.range)
        }
    }

    override func deleteBackward(_ sender: Any?) {
        guard !deleteThroughMarkers(forward: false) else { return }
        super.deleteBackward(sender)
    }

    override func deleteForward(_ sender: Any?) {
        guard !deleteThroughMarkers(forward: true) else { return }
        super.deleteForward(sender)
    }

    /// The delete keys aim at what the author can see. Where that is on the far side
    /// of an asterisk they cannot, the edit is made here — the long way round, through
    /// `shouldChangeText` and `didChangeText`, so it lands on the undo stack looking
    /// exactly like the keystroke it was.
    private func deleteThroughMarkers(forward: Bool) -> Bool {
        guard let storage = textStorage else { return false }
        guard let range = Markers.delete(
            selectedRange(),
            forward: forward,
            length: storage.length,
            run: markerRun(at:)
        ) else { return false }

        guard shouldChangeText(in: range, replacementString: "") else { return true }
        storage.replaceCharacters(in: range, with: "")
        didChangeText()
        setSelectedRange(NSRange(location: range.location, length: 0))
        return true
    }

    /// Completion swallows the "@" so the inserted mention is a plain, readable
    /// name. The manuscript never carries an identifier the author did not type.
    override var rangeForUserCompletion: NSRange {
        let string = self.string as NSString
        let caret = selectedRange().location
        guard caret > 0, caret <= string.length else { return super.rangeForUserCompletion }

        var index = caret - 1
        var scanned = 0
        while index >= 0, scanned < 64 {
            let character = string.character(at: index)
            if character == 0x40 {  // "@"
                return NSRange(location: index, length: caret - index)
            }
            if character == 0x0A || character == 0x0D { break }
            index -= 1
            scanned += 1
        }
        return super.rangeForUserCompletion
    }

    /// What an author reaches for on a passage they have just marked, in the place a
    /// Mac author reaches for it.
    ///
    /// This used to be a capsule that floated over the page at the selection, with a
    /// drop shadow, in a blur. It looked like a web editor and it behaved like one:
    /// it covered the line above the words being worked on, it could not be reached
    /// from the keyboard, and it was the *only* way to reach emphasis — so an author
    /// with the caret in a word, which is the common case, could not format at all.
    ///
    /// Now the four actions are here, under the right button, above AppKit's own
    /// spelling and substitution items; and ⌘B, ⌘I and ⌥⌘C reach three of them
    /// without a pointer at all.
    override func menu(for event: NSEvent) -> NSMenu? {
        guard let menu = super.menu(for: event) else { return nil }
        let selection = selectedRange()
        guard selection.length > 0 else { return menu }

        var index = 0
        func insert(_ title: String, _ action: Selector, key: String, modifiers: NSEvent.ModifierFlags = .command) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = modifiers
            item.target = self
            menu.insertItem(item, at: index)
            index += 1
        }

        insert(InlineFormat.strong.title, #selector(toggleStrong(_:)), key: "b")
        insert(InlineFormat.emphasis.title, #selector(toggleEmphasis(_:)), key: "i")
        insert(InlineFormat.highlight.title, #selector(toggleHighlight(_:)), key: "H", modifiers: [.command, .shift])
        menu.insertItem(.separator(), at: index)
        index += 1
        insert("Add Comment", #selector(addComment(_:)), key: "c", modifiers: [.command, .option])

        // A name, not an essay. Offering to make a record out of half a paragraph is
        // offering to make a mess.
        let name = (string as NSString).substring(with: selection)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty, name.count <= 60 {
            insert("New Record from “\(name)”", #selector(createRecord(_:)), key: "")
        }

        menu.insertItem(.separator(), at: index)
        return menu
    }

    @objc private func toggleStrong(_ sender: Any?) { onFormat?(.strong) }

    @objc private func toggleEmphasis(_ sender: Any?) { onFormat?(.emphasis) }

    @objc private func toggleHighlight(_ sender: Any?) { onFormat?(.highlight) }

    @objc private func addComment(_ sender: Any?) {
        let range = selectedRange()
        guard range.length > 0 else { return }
        onCommentRequest?(range)
    }

    @objc private func createRecord(_ sender: Any?) {
        let range = selectedRange()
        guard range.length > 0 else { return }
        let name = (string as NSString).substring(with: range)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        onCreateRecord?(name)
    }
}

// MARK: - Scroll view

/// Owns the vertical breathing room. Typewriter mode needs an asymmetric bottom
/// inset — the last line of a scene has to be able to reach the middle of the
/// window — and `textContainerInset` cannot express that, but content insets can.
final class ManuscriptScrollView: NSScrollView {
    var typewriterEnabled = false {
        didSet { needsLayout = true }
    }
    var onGeometryChange: (() -> Void)?

    override func layout() {
        super.layout()

        let restingPadding = ProseStyle.restingPadding
        let height = contentView.bounds.height
        let bottom = typewriterEnabled ? max(restingPadding, height * 0.58) : restingPadding
        let insets = NSEdgeInsets(top: restingPadding, left: 0, bottom: bottom, right: 0)

        if !insets.matches(contentInsets) {
            contentInsets = insets
        }
        onGeometryChange?()
    }
}

private extension NSEdgeInsets {
    func matches(_ other: NSEdgeInsets) -> Bool {
        abs(top - other.top) < 0.5
            && abs(bottom - other.bottom) < 0.5
            && abs(left - other.left) < 0.5
            && abs(right - other.right) < 0.5
    }
}

// MARK: - Find bar

/// The native find bar is already correct; it only needs a menu item to reach it.
nonisolated enum TextFinder {
    @MainActor
    static func perform(_ action: NSTextFinder.Action) {
        let sender = NSMenuItem()
        sender.tag = action.rawValue
        NSApp.sendAction(#selector(NSTextView.performTextFinderAction(_:)), to: nil, from: sender)
    }
}

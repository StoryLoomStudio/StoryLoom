//
//  MarkdownSyntax.swift
//  StoryLoom
//
//  Adapted from SwiftMarkdownEngine (github.com/nodes-app/swift-markdown-engine),
//  Apache License 2.0. See Markdown/NOTICE.md.
//
//  The parser-facing half of that project's extension seam. Upstream, an
//  extension supplies both *syntax* (the delimiters) and *attributes* (how the
//  content looks), and the attribute half drags in AppKit and the engine's own
//  theme type. StoryLoom already owns its look — `ProseStyle` decides what a
//  highlight is — so only the syntax half is carried over: the delimiters, and
//  the registry the parsers consult. Appearance stays where it already lived.
//
//  Constructs beyond CommonMark are opt-in and named here rather than wired
//  into the parser, which is what keeps `==` and `~~` from being special cases
//  scattered through the scanner.
//

import Foundation

// MARK: - Syntax rules

/// The syntax of a delimited inline span.
///
/// * The span opens where `open` matches and closes at the FIRST exact `close`
///   match on the same line.
/// * A lone occurrence of `close`'s first character inside the content aborts
///   the match, so `==a=b==` stays literal.
/// * A newline before the close aborts the match — spans are single-line.
nonisolated struct InlineSyntax: Sendable, Equatable {
    var open: String
    var close: String
    /// Whether the content is re-parsed as Markdown (so `==a **b**==` nests) or
    /// kept opaque.
    var parsesContent: Bool
    /// Reject an empty span (`====`).
    var requiresNonEmptyContent: Bool
    /// Reject when the character before `open` repeats `open`'s first character,
    /// so a span never extends a longer delimiter run.
    var rejectsOpenerRun: Bool
    /// Reject when the character after `close` repeats `close`'s last character.
    /// `~~` wants this; `==` does not.
    var rejectsCloserRun: Bool

    init(
        open: String,
        close: String,
        parsesContent: Bool = true,
        requiresNonEmptyContent: Bool = true,
        rejectsOpenerRun: Bool = true,
        rejectsCloserRun: Bool = false
    ) {
        self.open = open
        self.close = close
        self.parsesContent = parsesContent
        self.requiresNonEmptyContent = requiresNonEmptyContent
        self.rejectsOpenerRun = rejectsOpenerRun
        self.rejectsCloserRun = rejectsCloserRun
    }
}

/// The syntax of a fenced block: a line beginning with `fence` opens it, the
/// next such line closes it, and an unclosed block runs to the end of the text.
nonisolated struct BlockSyntax: Sendable, Equatable {
    var fence: String
}

/// One registered construct: an id, and the inline and/or block syntax it adds.
nonisolated struct MarkdownConstruct: Sendable, Equatable {
    var id: String
    var inline: InlineSyntax?
    var block: BlockSyntax?

    init(id: String, inline: InlineSyntax? = nil, block: BlockSyntax? = nil) {
        self.id = id
        self.inline = inline
        self.block = block
    }
}

// MARK: - The constructs StoryLoom recognises

nonisolated extension MarkdownConstruct {
    /// `==marked==`. Not CommonMark, but the one extension every editor an
    /// author is likely to open the file in — Obsidian, Bear, Typora — agrees on.
    static let highlight = MarkdownConstruct(
        id: "highlight",
        inline: InlineSyntax(open: "==", close: "==")
    )

    /// `~~cut~~`. A novelist strikes a line through prose they have not decided
    /// to delete yet, which is a different act from deleting it.
    static let strikethrough = MarkdownConstruct(
        id: "strikethrough",
        inline: InlineSyntax(open: "~~", close: "~~", rejectsCloserRun: true)
    )

    /// Everything the manuscript understands beyond CommonMark.
    static let all: [MarkdownConstruct] = [.highlight, .strikethrough]
}

// MARK: - Registry

/// The precompiled, purely syntactic view the parsers see.
nonisolated struct ExtensionRegistry {
    struct Entry {
        let id: String
        let open: [unichar]
        let close: [unichar]
        let syntax: InlineSyntax
    }

    struct BlockEntry {
        let id: String
        let fence: String
        let fenceChars: [unichar]
    }

    let entries: [Entry]
    let blockEntries: [BlockEntry]
    /// Stable fingerprint for cache keying; two registries with the same one
    /// produce identical parses for identical text.
    let fingerprint: String

    static let empty = ExtensionRegistry(entries: [], blockEntries: [], fingerprint: "")

    /// The registry the manuscript is parsed with.
    static let manuscript = ExtensionRegistry(constructs: MarkdownConstruct.all)

    private init(entries: [Entry], blockEntries: [BlockEntry], fingerprint: String) {
        self.entries = entries
        self.blockEntries = blockEntries
        self.fingerprint = fingerprint
    }

    init(constructs: [MarkdownConstruct]) {
        guard !constructs.isEmpty else {
            self = .empty
            return
        }
        self.entries = constructs.compactMap { construct in
            guard let syntax = construct.inline else { return nil }
            return Entry(
                id: construct.id,
                open: Array(syntax.open.utf16),
                close: Array(syntax.close.utf16),
                syntax: syntax
            )
        }
        self.blockEntries = constructs.compactMap { construct in
            guard let block = construct.block, !block.fence.isEmpty else { return nil }
            return BlockEntry(id: construct.id, fence: block.fence, fenceChars: Array(block.fence.utf16))
        }
        // Every field participates, and free text is length-prefixed so the
        // concatenation is injective: two registries that differ in any flag can
        // never share a cached parse.
        func framed(_ string: String) -> String { "\(string.utf16.count).\(string)" }
        self.fingerprint = constructs
            .map { construct in
                var parts = [framed(construct.id)]
                if let syntax = construct.inline {
                    parts += ["i", framed(syntax.open), framed(syntax.close),
                              "\(syntax.parsesContent)", "\(syntax.requiresNonEmptyContent)",
                              "\(syntax.rejectsOpenerRun)", "\(syntax.rejectsCloserRun)"]
                }
                if let block = construct.block {
                    parts += ["b", framed(block.fence)]
                }
                return parts.joined(separator: ",")
            }
            .joined(separator: "|")
    }

    var isEmpty: Bool { entries.isEmpty && blockEntries.isEmpty }

    /// The first registered block rule whose fence opens `line`; registration
    /// order is precedence.
    func blockEntry(opening line: String) -> BlockEntry? {
        blockEntries.first { line.hasPrefix($0.fence) }
    }

    func blockEntry(for id: String) -> BlockEntry? {
        blockEntries.first { $0.id == id }
    }
}

# Third-party code

## SwiftMarkdownEngine

Taken verbatim from **SwiftMarkdownEngine**:

- `BlockParser.swift`, `InlineParser.swift`, `MarkdownAST.swift` — the parser
- `HTMLToMarkdownConverter.swift` — rich paste

Adapted from it:

- `MarkdownSyntax.swift` — from its extension seam
- `MarkdownInput.swift` — from `MarkdownListHandler`
- the trailing-caret snap in `ManuscriptEditor.swift` (their FB22524198 fix)

- Source: <https://github.com/nodes-app/swift-markdown-engine>
- Version: **0.10.1** (commit `3d55f661b716cc8ae768c1ce8addf7b2e522f099`)
- Copyright: Nodes (nodes.app)
- Licence: Apache License 2.0 — full text in
  `LICENSE-SwiftMarkdownEngine.txt`, beside this file.

The upstream checkout is no longer vendored in this repository; only the files
listed below were kept. To diff against upstream, or to recover anything not
taken — its renderer, its table and LaTeX drawing, or its test suite, which
covers `BlockParser`, `InlineParser`, the AST pipeline, list parsing and the
HTML converter — clone that commit:

```
git clone https://github.com/nodes-app/swift-markdown-engine
git -C swift-markdown-engine checkout 3d55f661b716cc8ae768c1ce8addf7b2e522f099
```

### What was taken, and what was not

What was taken is what is **independent of how the text is drawn**: the parser,
the HTML converter, the list-input rules. All of it is pure Foundation, or close
enough that the AppKit it touches is `NSTextView` rather than any layout engine.

What was **not** taken is the renderer — `NativeTextView`, the layout fragments,
the styler, the table and LaTeX drawing, wiki links, images, the scrolling
header. StoryLoom's appearance is its own, and `ProseStyle` already decides it.

A note on the history, because it explains the shape of this directory. The
parser was taken first, while StoryLoom's editor was still **TextKit 1** — at
which point none of the rendering code *could* be used, since it is TextKit 2
throughout. The editor has since migrated to TextKit 2, which is what made the
second round (rich paste, list input, the caret fix) possible.

The one thing that migration cost is worth recording here, since this project is
where the trade-off was learned. Under TextKit 1 a Markdown marker could be
denied a glyph outright (`layoutManager(_:shouldGenerateGlyphs:…)` returning
`.null`), so `**word**` drew as four letters with the asterisks taking no width
at all. TextKit 2 has no glyph-generation hook. StoryLoom now hides markers the
way SwiftMarkdownEngine does — a 0.1pt font with the width kerned away — and
inherits the sub-pixel residue its documentation describes.

### Modifications

- `nonisolated` added to the parser types, so they can be called from
  StoryLoom's `nonisolated` styler under `SWIFT_DEFAULT_ACTOR_ISOLATION =
  MainActor`.
- The extension seam was reduced to its syntactic half (`MarkdownSyntax.swift`).
  Upstream, an extension supplies both delimiters *and* an AppKit attribute
  dictionary; StoryLoom's appearance belongs to `ProseStyle`, so only the
  delimiters were carried across.
- Diagnostics (`PerfTrace`) and the incremental token pipeline
  (`DocumentParseState`, `MarkdownTokenizer`) were dropped; the styler calls the
  cached static `BlockParser.parse` path directly.

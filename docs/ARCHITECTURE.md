# StoryLoom — Target Architecture

Companion to `AUDIT.md` (finding ids such as B4, A7, U1 refer to it). This document is the
specification the build follows. Where it says **must**, a phase cannot close without it.

---

## 0. Ground rules

1. **The author's real novel is off limits.** Nothing — no test, no script, no launched build — may
   read prose from, write to, or open `/Users/vibrant/Desktop/Projects/Ashes of You`. All testing
   uses synthetic fixtures (§10.4). Debug builds use their own bundle id (§12, Phase 0) so they
   never share recents or a container with the build the author writes in.
2. **Never lose or silently change a word.** Any operation that can alter prose on disk is
   atomic, verifiable, and recoverable from History.
3. **Keep every existing capability** unless this document removes it by name: threads, scene
   questions, continuity findings, comments, appearance spans, mentions, search, trash, history,
   focus and typewriter modes, all five export formats.
4. **The uncommitted work in the tree is the owner's latest editor work.** Build on it; do not
   revert it.
5. **Dependencies**: Yams (YAML) and swift-argument-parser (CLI). Anything else needs approval.
6. **No commits or pushes** until the architect relays the owner's permission.
7. Target: macOS 26.0+, Swift 6 language mode in the package, Xcode 27.

## 1. Product principles

- **The folder is the interface.** Anything the app can do to a project, a person or an AI tool can
  do with plain files — and the app keeps up with them live.
- **The app never fights for a file.** It writes only what changed, never renames or rewrites a
  file it did not create until the author acts on it, and merges outside edits at paragraph level.
- **Typing is sacred.** A keystroke does a paragraph of work, redraws the text and at most one
  number.
- **One Mac app, not a web app in a window.** System materials, system controls, standard menus,
  standard window behaviour; custom drawing only for the page.
- **Pull, not push.** The things that make people come back are speed, resumption and a visible
  sense of progress — never a nag.

## 2. Repository layout

```
StoryLoom/                       git root
  StoryLoom.xcodeproj
  StoryLoom/                     app target — UI only
    App/         StoryLoomApp, AppModel, commands, window scenes
    Session/     ProjectSession and its observable models
    Shell/       sidebar, navigator scaffold, toolbar, status bar, banners
    Rooms/       Manuscript, Codex, Timeline, Threads, Notes, Trash, History
    Editor/      TextKit 2 editor, styler, format bar, inspector
    Panels/      palette, search, export, review, welcome, settings
    DesignSystem/ tokens, components
  StoryLoomTests/                app-level tests
  StoryLoomKit/                  local Swift package — no SwiftUI
    Package.swift                products: library StoryLoomKit, executable storyloom
    Sources/StoryLoomKit/
      Model/     value types
      Format/    v2 codec, front matter, v1 reader, migrator
      Store/     ProjectStore, file watcher, journal, trash
      Merge/     three-way paragraph merge, text diff
      History/   content-addressed save points
      Index/     search, mentions, thread arcs, continuity
      Markdown/  the existing parser
      Export/    the existing export service (AppKit allowed)
      Agent/     guide generator, context pack, validation
    Sources/storyloom/           CLI
    Tests/StoryLoomKitTests/     + fixture generator
  docs/  scripts/check.sh
```

`.gitignore` currently ignores `Packages/`; the package lives at `StoryLoomKit/` for that reason.
Model types lose their SwiftUI imports (Q4): tints and glyphs become app-side extensions.

---

## 3. Project format v2

### 3.1 Layout

```
My Novel/
  project.storyloom          manifest (YAML) — small, human
  AGENTS.md                  generated section + the author's own section
  manuscript/                the book; the directory tree is the outline
    0010-Part One/
      _index.md              optional folder note
      0010-arrival.md
      0020-the-letter.md
    0020-Part Two/
    loose-idea.md            unprefixed files are legal
  codex/
    characters/ locations/ objects/ organizations/ themes/ symbols/   one .md per record
    threads/                 one .md per thread
    timeline.yaml
    relationships.yaml
  notes/                     one .md per note
  archive/                   scenes kept out of the book
  .storyloom/                app-owned; agents are told to leave it alone
    annotations/<scene-id>.yaml     comments + appearance spans, one file per scene
    dispositions.yaml
    history/  trash/  journal.ndjson  cache/  stats/
    .gitignore                      history/ trash/ cache/ journal.ndjson stats/
```

Unknown files and folders anywhere are left exactly as found.

`project.storyloom`:

```yaml
formatVersion: 2
id: 19D720A9-62BF-458A-B1D1-264AD75A994F
title: Ashes of You
author: ""
targets:
  words: 100000
  daily: 0            # 0 = no daily goal
agentFiles: true      # write AGENTS.md
```

There is no document index in the manifest. The tree is read from disk.

### 3.2 Order (fixes B5)

- An entry's position is its numeric prefix: `NNNN-name`. A prefix is exactly three or four digits
  followed by a dash (`^\d{3,4}-`) — nothing looser, so "2024 Notes" keeps its name. Sort key:
  prefix value, then name; unprefixed entries follow all prefixed ones, by name.
- New prefixes are **sparse** (step 10, four digits). Inserting between two entries takes the
  midpoint. Only when no integer gap exists, or when prefix widths in that folder differ, are that
  folder's direct children renumbered — nothing else is renamed.
- Moving or reordering renames only the moved entry. Retitling in the app renames that one file
  (same prefix, new slug). Both are journaled operations (§4.2).
- v1's dense `NNN-` names are still readable, but migration renumbers every folder once to four
  digits, step 10, keeping each slug (§11) — otherwise the author's first insert in each folder
  would rename all its siblings.

### 3.3 Identity and adoption (fixes B8)

- A scene's identity is `id` in its front matter — an opaque string. Existing UUIDs stay valid;
  new ids are short (`sc_` + 8 base-32 characters).
- **Lazy identity.** A Markdown file without front matter or without an `id` is a scene the moment
  it appears. The app gives it a session id keyed by path and does **not** touch the file. It
  writes an `id` only when something has to refer to the scene (a comment, an event) or the author
  edits the file in the app, and it renames the file only when the author moves or reorders it.
- Two files with the same `id`: the one not seen before keeps its content and gets a new id the
  next time the app writes it.
- A "Normalise Project" command (and `storyloom normalize`) assigns ids and prefixes on demand.

### 3.4 Folders (fixes A5)

- Display name is the directory name without its prefix. `_index.md` may override with `title:`.
- Kind is `kind:` in `_index.md`, otherwise inferred from the name: volume/book → volume;
  part/act → part; chapter → chapter; else folder. The app writes `_index.md` only when the author
  sets something a name cannot say (a kind that differs from inference, a synopsis, a title with
  characters a filename cannot hold).
- `_index.md` body is the folder's synopsis/notes. It is never a scene and never exported.
- Folder identity is its path. When the app itself renames or moves a folder it remaps collapse
  state and selection. UI state is stored outside the project (§5.5).

### 3.5 Scene files (fixes A6, A10)

```markdown
---
id: sc_8k2f9qzt
title: The Wrong Order
status: draft                 # outline | draft | revised | done
pov: Asher
location: Greywatch
target: 2500
synopsis: |
  One paragraph on what happens. The field an AI tool reads first.
intention: Why the scene exists.
turn: What changes.
withheld: What must not be revealed here.
residue: What the reader carries out.
threads:
  opens: [the-ring]
  advances: [annie-watching]
  lands: []
kind: note                    # only when it is a note; scenes omit it
---
Prose…
```

- Real YAML, parsed with Yams: block scalars, block or flow lists, comments.
- **Write rules.** Keys are written in the order above; empty strings, empty lists and unset
  values are omitted; `status` is always written. Unknown top-level entries are preserved
  **byte for byte** (raw line ranges), in place after the known keys.
- **Minimal writes.** A file whose model did not change is not written. A body-only edit leaves
  the front-matter bytes identical. Front matter is re-emitted only when a known field changes.
  Line endings and the trailing newline are preserved.
- `title` is optional: without it the title is the first `# Heading`, else the de-slugged filename.
- `volume` and `chapter` are gone. Structure is the tree, everywhere (fixes A4).
- A file with front matter but no `id` is a scene with front matter (v1 read such a file as prose
  and treated the YAML block as body text).
- `kind: note` marks a working note that lives in the manuscript tree: it is listed in the binder
  with a note glyph and is excluded from export and from every word total. These are distinct from
  the free notes in `notes/` (§3.6).
- Accept v1 spellings on read: `targetWordCount`, top-level `opens`/`advances`/`lands`, thread
  UUIDs (resolved through the migration map when present).

### 3.6 Codex, notes, trash (fixes A9, B7)

Record identity is the **slug** — the filename stem. References everywhere use slugs.

`codex/characters/annie-stahl.md`
```markdown
---
name: Annie Stahl
aliases: [Annie]
pronouns: she/her
role: Asher's sister
---
Free notes in Markdown.
```
Optional `scenes: [scene ids]` lists scenes the author linked to the record by hand (v1
`linkedDocumentIDs`). Any directory under `codex/` is a category; the six built-in ones get icons,
others are listed under their folder name.

`codex/threads/the-ring.md` — front matter `question`, optional short `name`, `kind` (mystery,
promise, threat, goal, relationship, character-arc, foreshadowing, conflict, theme), `status`
(open | abandoned); the body is the answer and notes. A thread's slug comes from `name` when it has
one, otherwise from the first five words of the question; a collision takes a `-2`, `-3` suffix.

`codex/timeline.yaml` — ordered list: `id`, `title`, `when` (free text), `certainty`
(stated | approximate | disputed | unplaced), `scene` (scene id), `who` (slugs), `summary`.

`codex/relationships.yaml` — list: `id`, `from`, `to`, `kind` (knows, family, loves, opposes, owes,
conceals, belongsTo, locatedIn, custom), `label`, `summary`.

`notes/<slug>.md` — optional `title` and `updated` (timestamp); body.

Renaming a record in the app renames its file and rewrites every reference as one journaled
change. A dangling slug is shown as a finding, never dropped from the file.

Trash: `.storyloom/trash/<timestamp>-<name>/` holds the original files or folder plus `trash.yaml`
(kind, original path, deleted-at). Restoring moves them back — to the original parent when it
exists, otherwise the manuscript root. Records that are rows rather than files (timeline events,
relationships) are kept inline in `trash.yaml` under `payload:` and restored into their list. A
relationship is restorable only while both of its ends exist.

Finding ids (the keys of `.storyloom/dispositions.yaml`) are derived from scene ids and record
slugs, so they are stable across sessions and renames are carried through by the rename change.

### 3.7 Annotations

`.storyloom/annotations/<scene-id>.yaml`:

```yaml
comments:
  - id: c_41xk
    author: author            # or an agent's name
    at: 2026-11-11T09:30:00Z
    quote: "the exact words commented on"
    prefix: "up to 32 chars before"
    suffix: "up to 32 chars after"
    body: Tighten this.
    offset: 602               # last known position, a hint only
    resolvedAt:               # a timestamp once resolved; `resolved: true` is accepted on read
presentation: { … }           # existing appearance spans, same anchoring
```

An entry with only `quote` and `body` is valid — that is how an agent leaves a margin note. The app
resolves anchors by quote + context and marks unresolvable ones as detached rather than deleting.

---

## 4. Persistence engine (`StoryLoomKit/Store`)

### 4.1 Shape

```swift
public actor ProjectStore {
    public init(root: URL)
    public func load() async throws -> LoadedProject
    public func commit(_ changes: ChangeSet) async throws -> CommitReceipt
    public nonisolated var externalEvents: AsyncStream<[ExternalChange]> { get }
}
public enum FileOp { case write(path, Data), move(from, to), delete(path), makeDirectory(path) }
```

The store keeps a stamp table — path → (size, mtime, content hash) — for everything it has read or
written. That table is the only means of telling own writes from outside ones.

### 4.2 Writing (fixes B4, A11, A12)

- The app tracks dirty **files**. A commit writes those and nothing else; each write is atomic
  (temporary file in the same directory, then replace). Typing in one scene writes one file.
- Autosave: 1.5 s after the last change, at most 10 s after the first; also on app deactivation,
  scene switch, window close and quit. Quit performs a direct synchronous write of the dirty files
  — no semaphore around an async task.
- The journal records **multi-file** operations only (move, rename, renumber, trash, record rename
  with reference rewrites): intent before, completion after, replay or roll back on next open.
  The journal is `.storyloom/journal.ndjson` and is truncated on clean open. (v1 kept it at
  `.storyloom/journal/journal.ndjson` and its history at `history/snapshots/` in the project root;
  only the migrator reads those.)
- No project-wide fingerprint. No generated files rewritten per save: `AGENTS.md` is regenerated
  only when its generated section's content would differ.
- Every failed write surfaces as a per-file error state with a retry; nothing is swallowed.

### 4.3 Watching (fixes A8, B8)

One FSEvents stream on the project root with file-level events, coalesced over 300 ms. For each
path: stat, compare with the stamp table, ignore if it matches, otherwise reload **that file** and
hand an `ExternalChange` to the session. No directory re-scan except after a root-level event or
on activation, when a cheap stat sweep reconciles the table.

### 4.4 Merging outside edits (fixes A7)

For a changed scene: base = last synced text, local = editor/model text, remote = disk.

- Local unchanged → take remote. Remote equals local → nothing.
- Both changed → three-way merge by paragraph (blank-line separated blocks, diff3 over LCS).
  Non-overlapping changes merge silently.
- Overlap → that scene alone enters a conflict state: a bar inside the editor offers *Keep Mine*,
  *Take Theirs* and *Compare*; both versions are saved to History first. Every other file keeps
  saving.
- Front matter merges per key by the same base/local/remote rule.
- Applying a merge to an open editor replaces only the changed ranges in the text storage, as one
  undo group named "Changes from Outside", preserving caret and scroll; appearance spans and
  comment anchors are re-resolved afterwards.
- Before the first outside change of a burst is absorbed, the store records a save point named
  "Before outside changes" (§4.5) and the change is added to the review list (§8.4).

### 4.5 History (fixes B6)

Content-addressed, under `.storyloom/history/`:

- `objects/ab/<sha256>` — zlib-compressed file contents.
- `snapshots/<timestamp>-<id>.json` — reason, date, `{ path: hash }` for manuscript, codex, notes,
  annotations and the manifest.

A save point stores only blobs that are new. Listing reads small manifests. Restoring writes the
files whose hash differs. Per-scene history ("versions of this scene") is a query over manifests.
Retention: automatic points every 10 minutes while changes exist, thinned to hourly after a day and
daily after a month; named points are kept until deleted; unreferenced blobs are collected.
v1 snapshots are imported once during migration (§11) and the old files removed only after
verification.

### 4.6 Derived data

Search index, mention index, thread arcs and continuity findings are computed off the main actor
and updated **per changed scene**, not per project. Word counts are cached per scene and updated on
a 100 ms debounce. Nothing derived is stored in the project.

---

## 5. App state

### 5.1 Models (Observation framework, `@Observable`, `@MainActor`)

```
AppModel            settings, recents, registry of open sessions
ProjectSession      one per project window
  manuscript: ManuscriptModel     outline tree + [SceneID: SceneModel]
  codex: CodexModel               records, threads, timeline, relationships, notes
  navigation: NavigationModel     room, selections, collapse set, presented panel
  editor: EditorModel             selection, focus, format state — editor-local
  review: ReviewModel             outside changes awaiting a look
  history: HistoryModel   trash: TrashModel   sync: SyncModel (save state, conflicts)
SceneModel          final class: id, path, meta, text, wordCount, saveState
```

`ObservableObject`, `@Published` and `@EnvironmentObject` are removed. Views read only the
properties they draw, so a keystroke invalidates the editor bridge, the open scene's row and the
status-bar counts — and nothing else (fixes A1, A2). `SceneModel.text` is read by the editor bridge
alone.

### 5.2 One project per window (fixes B3)

`ProjectSession` is created per window and placed in that window's environment. No singleton holds
a project.

### 5.3 Commands

Menu commands reach the key window's session through `FocusedValue`. `NotificationCenter` command
broadcasting is removed. Panel presentation lives in `NavigationModel`.

### 5.4 Undo (fixes A3)

Typing undo stays with the text view. Structural actions register the **inverse change** (the
affected tree nodes and fields), not a project copy. One user action is one undo step.

### 5.5 Per-project UI state

Room, selection, collapse set, inspector visibility, and per-scene caret and scroll position are
stored in the app's Application Support folder keyed by project id — never inside the project.

---

## 6. Windows, scenes, menus

### 6.1 Scenes (fixes B2, U12)

- `Window("Welcome to StoryLoom", id: "welcome")` — fixed-size launcher: recent projects with
  last-opened date and word count, New Project, Open, and "Continue <last project>" as the default
  button.
- `WindowGroup(id: "project", for: ProjectReference.self)` — one resizable window per project;
  opening a project that is already open raises its window. Title is the project name with a proxy
  icon (`representedURL`). State restoration reopens the projects that were open.
- `Settings`.
- `NSWindow.allowsAutomaticWindowTabbing = false`.
- No style-mask mutation, no deferred title hacks: standard `navigationTitle`, standard unified
  toolbar.

### 6.2 Opening

Open panel, drag onto the Dock icon, double-click on `project.storyloom`, Open Recent. When the app
is handed a manifest file but has no access to its folder (sandbox), it resolves a stored bookmark
for that folder; failing that it shows one open panel already pointed at the folder, with a
one-line explanation.

### 6.3 Menus (fixes U9)

File: New Project, New ▸ (Scene, Folder, Character…, Thread, Note), Open…, Open Recent ▸, Close,
Save Point, Export…, Reveal in Finder, Open in Terminal. Edit: standard text editing commands
including Find, Spelling and Grammar, Substitutions, Transformations, Speech
(`TextEditingCommands`). Format: Strong, Emphasis, Highlight, Underline, Strikethrough, Quote,
Heading ▸, List ▸, Scene Break. View: sidebar, inspector, focus, typewriter, page options, text
size. Go: each room, History, Trash, Quick Open. Window and Help standard. Every command has one
shortcut, shown in the menu, the palette and the tooltip from a single table.

---

## 7. Interface

### 7.1 Design system (fixes U4, U13)

One token file. Nothing outside `DesignSystem/` contains a literal colour, font size, radius or
duration.

- **Surfaces.** Sidebar, toolbar, inspector, sheets and Settings use system materials and system
  background colours untouched. The page is the only custom surface: paper themes defined in the
  asset catalog with light, dark and increased-contrast variants. Chrome must not be painted to
  match the page.
- **Type.** Chrome uses semantic text styles (`body`, `callout`, `subheadline`, `caption`); nothing
  below 11 pt, body text in lists and the inspector at 13 pt. Prose uses the author's face and
  size. Detail-view titles share one style across all rooms.
- **Spacing** on a 4-pt grid; **control heights** 28 pt regular, 24 pt in dense bars; every click
  target at least 24×24.
- **Motion** tokens: quick 0.15 s, standard 0.25 s spring, all collapsing to cross-fades under
  Reduce Motion.
- **Components**: `RoomScaffold`, `NavigatorList`, `NavigatorRow`, `DetailHeader`,
  `InspectorSection`, `LabeledField`, `EmptyState`, `Banner`, `IconButton`, `StatusItem`,
  `ProgressBarThin`.

### 7.2 Shell

Sidebar: project name and word count; rooms — Manuscript, Codex, Timeline, Threads, Notes; below a
divider, History and Trash. Counts on the right. The toolbar holds: sidebar toggle (system), a
**contextual New button** (New Scene in Manuscript, New Character… in Codex, New Event, New Thread,
New Note — fixes U6), Quick Open, inspector toggle, and one overflow menu using the standard
toolbar menu style.

### 7.3 Rooms (fixes U5)

Every room is built from `RoomScaffold`: the same navigator header (filter field, add), the same
row height and selection style, the same detail header (title, kind control, a "…" menu that holds
Delete and other secondary actions), the same empty state. "Story" is renamed **Codex**. Timeline
gains a real ordered view (drag to reorder, grouped by certainty) rather than a bare list.

### 7.4 Editor canvas (fixes U1, U2, U7, U8, U12)

- The text column keeps its measure and its top inset through any width change; opening or closing
  the inspector preserves the first visible line.
- Minimum window width is the sum of the columns' minimums; below a comfortable canvas width the
  inspector becomes an overlay instead of squeezing the page. Nothing clips.
- The header shows a **breadcrumb** from the tree (Part ▸ Chapter ▸ Scene), each segment a menu of
  its siblings; the title is editable in place. Status lives in the inspector header and the binder
  dot only.
- The empty-scene prompt sits on the first line of the text column.
- Focus mode hides the columns, toolbar and bars around the **same** editor instance with one
  animation; Escape leaves. Caret, scroll and undo are untouched.

### 7.5 Format bar (fixes U15)

Visible: Strong, Emphasis, Heading menu, List menu, Quote, Comment, then a "More" menu (underline,
strikethrough, highlight colours, alignment, local face and size). It collapses to the More menu
alone when narrow. Buttons are 24×24 with labels for VoiceOver and state reflecting the selection.

### 7.6 Status bar (fixes U11)

Scene words · selection words · reading time — session words — project total against target
("106,606 of 100,000 · 7% over"), save state. Counts use locale grouping and automatic plurals.

### 7.7 Quick Open / command palette (fixes U10)

A floating panel (non-activating `NSPanel`, centred near the top of the window, no dimming),
⌘K. One field searching commands, scenes, codex records, threads and notes with fuzzy ranking and
recents first; results in under one frame for a 1,000-scene project. Rows show a kind icon, the
name, a path or shortcut — no "Action" label.

### 7.8 Export (fixes U3)

Preview renders the first pages immediately and the rest lazily, off the main actor; a standard
sheet with Cancel and a default Export button. Chapter headings come from the tree.

### 7.9 Messages (fixes U14)

`Banner` carries its own title per cause. Errors name the file and offer the next step (Retry,
Reveal, Open History). No generic alert titled "StoryLoom".

### 7.10 Inspector

Sections: Scene (status, POV, location, target, synopsis), Questions, Threads, Mentions, Comments.
13 pt body, labelled fields with accessibility labels, collapsible sections that remember their
state. Comments show author; agent comments are tinted.

---

## 8. AI fluency

### 8.1 What an agent can do with files alone

| Task | How |
|---|---|
| Read the book in order | sorted glob of `manuscript/**/*.md` |
| Edit a scene | edit the file; the app merges live |
| Add a scene | create a `.md` anywhere under `manuscript/`; no front matter needed |
| Place it precisely | give it a numeric prefix between its neighbours |
| Add a chapter or part | create a directory |
| Add a character, location, thread | create one `.md` under `codex/…` |
| Link a scene to a thread | add the thread's slug under `threads:` |
| Leave a margin note | append to `.storyloom/annotations/<scene-id>.yaml` |
| Check the work | `storyloom check` |

### 8.2 Agent files

`AGENTS.md` at the project root has a generated block between
`<!-- storyloom:begin -->` and `<!-- storyloom:end -->` (short, task-shaped: the table above, the
front-matter keys, "never edit `.storyloom/history`, `trash`, `cache`") and everything outside the
markers belongs to the author. If no `CLAUDE.md` exists, one is created containing `@AGENTS.md`.
`agentFiles: false` in the manifest turns both off. The old `story/AI-GUIDE.md` and
`story/schema.json` are retired.

### 8.3 `storyloom` command-line tool

Built from the package, bundled at `StoryLoom.app/Contents/Helpers/storyloom`; Settings shows its
path with Copy and a "Copy Install Command" button (a `ln -s` line the author runs — a sandboxed
app cannot write `/usr/local/bin`). Run from a terminal the tool is not sandboxed and reads whatever
the user can. All commands take `--project <dir>`
(default: nearest ancestor with `project.storyloom`) and `--json`.

- `tree` — outline with status and word counts.
- `check` — validates front matter, slugs, duplicate ids, dangling references, detached comments;
  non-zero exit on errors. This is the linter an agent runs after editing.
- `context <scene>` — the pack an agent needs before drafting: breadcrumb, synopsis of the
  preceding scenes, this scene's questions, characters present with their codex notes, open
  threads, open comments.
- `new scene|folder|character|thread|note`, `mv`, `normalize`.
- `comments [--open]`, `comment add --scene … --quote … --body … --author …`.

### 8.4 In the app

- **Review Outside Changes**: a panel listing files changed from outside since the last
  acknowledgement, each with a word-level diff against the base, *Revert* per file or per hunk and
  *Mark Reviewed*. The sidebar shows "3 scenes changed outside · Review" while the list is
  non-empty.
- **Copy Context for AI** on any scene (the `context` pack on the clipboard) and **Open in
  Terminal** for the project folder.
- Automatic save point before outside changes are absorbed (§4.4).
- Agent comments appear in the inspector beside the author's.

No model is called from inside the app in this release; the format and the tool are the
integration.

---

## 9. Flow

- **Resume exactly**: last project, room, scene, scroll position and caret, with the window where
  it was.
- **Session and day**: words this session in the status bar; an optional daily goal drawn as a
  thin line that completes once, quietly. A **Progress** popover shows a calendar of writing days,
  current run and best day (data in `.storyloom/stats/`). On by default, one switch to hide.
- **Quick Open** for everything; **Next/Previous Scene** shortcuts; breadcrumb sibling menus.
- **Feel**: spring transitions for sidebar and inspector; drop indicators with alignment haptics
  while dragging in the binder; a small state change when a scene is marked Done; no modal in the
  writing path.
- **First run**: the Welcome window offers a small sample project that demonstrates folders,
  threads, a codex entry and a comment.

## 10. Quality bars

### 10.1 Performance (measured on the 1,000-scene fixture)

- Keystroke: no SwiftUI body re-evaluation outside the status bar and the open scene's row.
- Saving after typing in one scene: exactly one manuscript file written.
- Open to first paint under 1 s; scene switch under 50 ms; Quick Open results under 16 ms.
- Idle CPU zero; no timers while idle.

### 10.2 Accessibility

Every control labelled; full keyboard operation of lists, binder and panels; Reduce Motion,
Increase Contrast and Reduce Transparency respected; text sizes follow tokens.

### 10.3 Localisation readiness

All user-facing strings through the string catalog; plurals by inflection; numbers and dates
formatted for the user's locale.

### 10.4 Tests and fixtures

- A fixture generator in the test target writes synthetic projects (generated filler prose only):
  **v1-shaped** — `project.storyloom` with a document index, a stale `manifest.yaml`,
  `story/metadata.json` with characters, events, notes, a thread and trash payloads (documents and
  groups), `story/binder.json` (`formatVersion: 2`, path → kind), `story/presentation.json`,
  `history/snapshots/*.json`, dense `NNN-` names, scenes with all sixteen v1 keys written even when
  empty, an empty duplicate folder and an unprefixed folder — and **v2** at 60 and 1,000 scenes.
- Kit tests: front-matter round trip (unknown keys byte-identical; body-only edit leaves front
  matter bytes identical), order and renumbering, lazy identity, store writes exactly the dirty
  files, own writes produce no external events, merge matrix, conflict isolation, history
  store/restore/prune, trash round trip, migration (§11), CLI commands.
- Tests never touch the real defaults domain or container (fixes Q1).
- `scripts/check.sh` builds the app, runs both test suites and fails on warnings in the package.
  Warnings-as-errors is a flag the script passes, not a setting in `Package.swift`, so a new
  toolchain warning cannot stop the app from building in Xcode.
- `StoryLoomKit/Package.resolved` is committed so dependency versions are pinned.
- Files shared between the app target (Swift 5 mode, default MainActor isolation) and the package
  (Swift 6, no default isolation) keep explicit `nonisolated`. Once model and store live in the
  package the app tests stop being hosted in the app.

## 11. Migration v1 → v2

Opening a v1 project shows an **Upgrade Project** sheet: what will change, where the backup goes.
Nothing happens without the author's click.

Before anything else the migrator refuses, with an explanation, if the v1 journal's last entry is an
unfinished save.

1. Copy the whole project to a sibling `<name> (v1 backup <date>)`.
2. Build the v2 tree in a temporary sibling directory: scenes keep their slugs and their body
   bytes, and every folder's entries are renumbered once to four digits, step 10; front matter is
   rewritten per §3.5 (drop `volume`, `chapter`, empty values, the default
   `targetWordCount: 500`; thread UUIDs → slugs); `metadata.json` becomes codex files, timeline,
   relationships, notes, annotations and trash; `binder.json` kinds become `_index.md` only where
   inference disagrees; `presentation.json` becomes per-scene annotations; v1 snapshots are imported
   into the history store; `manifest.yaml`, `story/` and empty swept folders are not carried over.
   A scene whose body opens with a second front-matter block (a file v1 once read as prose) has
   that block folded into its front matter, and is named in the upgrade summary. Comments get
   `author: author`. Thread, record and note trash entries become trashed files; event and
   relationship entries become inline payloads. Dispositions are re-keyed by regenerating findings
   on both sides of the id map; any that cannot be matched are kept under `legacy:`.
3. Verify: same number of scenes, same order, every scene body byte-identical (apart from a folded
   block), every record, comment and trash entry accounted for. Save points are verified by
   decoding, not by comparing bytes — v1 wrote them with unstable key order.
4. Swap directories atomically. On any failure the original is untouched and the sheet says why.

A UUID → slug map is kept in `.storyloom/migration.json` so v1-style references still resolve.

---

## 12. Phases

Each phase ends with the app building, `scripts/check.sh` green, and a written report: what
changed, what was measured, what is left. The architect reviews before the next phase starts.

**Phase 0 — Stabilise.**
Fix B1. Give the Debug configuration bundle id `io.storyloom.dev` and display name
"StoryLoom Dev" (the product and module stay `StoryLoom`); Debug declares the document type with
handler rank None so it never competes for double-clicks. Make tests hermetic (Q1). Replace the broken smoke script with `scripts/check.sh`
(Q2). Add `Logger`, remove `print` (Q6). Create the `StoryLoomKit` package skeleton and the fixture
generator. Gate: build and tests green from a clean checkout.

**Phase 1 — Kit: format v2 and the store.**
Move model, Markdown, export, search, continuity into the package (no SwiftUI). Implement §3, §4,
§11 and the tests in §10.4. The app still runs on the old `WorkspaceModel` through a thin adapter
or is temporarily limited — the package is the deliverable. Gate: all Kit tests green; migration
verified on the v1 fixture; a written note of any format question that came up.

**Phase 2 — State and windows.**
§5 and §6: `ProjectSession` and observable models replace `WorkspaceModel`; Welcome and project
windows; focused-value commands; inverse-change undo; per-project UI state; live merge wired into
the editor. Gate: two different projects open in two windows independently; keystroke invalidation
verified; outside edit to an open scene merges without moving the caret.

**Phase 3 — Interface.**
§7: tokens and components, shell, rooms on one scaffold, editor canvas fixes, format bar, status
bar, Quick Open panel, export, messages, inspector, menus. Gate: every U-finding closed, checked at
900, 1240 and 1710 pt widths in light and dark.

**Phase 4 — AI fluency.**
§8: agent files, the CLI and its bundling, context pack, Review Outside Changes, agent comments.
Gate: a scripted session — create scenes, a character and a thread from the shell while the app is
open, edit an open scene from outside, leave a comment — ends with `storyloom check` clean and
everything visible in the app.

**Phase 5 — Flow and release readiness.**
§9, §10.1–10.3: resume, progress, haptics and motion, sample project, accessibility pass, string
catalog, performance measurements on the 1,000-scene fixture, About window, app icon check.
Gate: the quality bars in §10 met and recorded.

## 13. Working agreement

- Read `AUDIT.md` and this file before changing anything; raise disagreements with the spec in the
  phase report rather than silently diverging.
- Work one phase at a time and stop at its gate.
- Keep comments short: say what a constraint is, not the history of how it was found.
- When a decision is not covered here, choose the option that keeps files stable on disk and the
  typing path light, and note it in the report.

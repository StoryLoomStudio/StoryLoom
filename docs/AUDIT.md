# StoryLoom — Audit (2026-11-11)

Scope: the whole macOS app (≈23,400 lines of Swift, one app target + one test target), the on-disk
project format, and a live pass over the running app with a real 106k-word, 57-scene project.
Findings are numbered so work can cite them. Severity: **P0** breaks the product or risks an
author's work · **P1** must be fixed before public release · **P2** polish.

Every fix is specified in `ARCHITECTURE.md`; the section or phase is named at the end of each row.

## What is good and must be kept

- The principle: a project is a plain folder of Markdown that survives the app.
- The TextKit 2 editor (`ManuscriptEditor.swift`): incremental paragraph restyle on edit, marker-aware
  selection, typewriter mode, focus dimming. Keep the engine; fix what surrounds it.
- The writing-craft model: scene questions (intention / turn / withheld / residue), threads with
  opens / advances / lands, the continuity checker, reversible trash, save points.
- Export breadth (Markdown, plain text, RTF, DOCX, PDF) and its test coverage.
- Unknown front-matter keys are preserved; external Markdown is adopted rather than rejected.

## P0

| ID | Finding | Evidence | Fix |
|---|---|---|---|
| B1 | **The working tree does not compile.** | `ManuscriptEditor.swift:218` calls `coordinator.restyleEverything()`, declared `private` at `:483`. `xcodebuild` → BUILD FAILED. | Phase 0 |
| B2 | **Opening a project file does not open the project.** `open project.storyloom` (what Finder double-click does) spawns a second window showing whatever was already open. | Observed live. SwiftUI `WindowGroup` answers the open event with a new window; `AppDelegate.application(_:open:)` never loads the project. Under the sandbox a file URL also grants no access to its parent folder. | §6, Phase 2 |
| B3 | **Every window is the same workspace.** One `WorkspaceModel` is injected into the only `WindowGroup`; a second window (or a system tab — "Show Tab Bar" is in the View menu) mirrors selection, scroll target and sheets. Menu commands are broadcast through `NotificationCenter`, so the palette and the export sheet open in all windows at once. | Observed live: palette and export opened in both windows. `StoryLoomApp.swift:28-36`, `WorkspaceView.swift:78`. | §5–6, Phase 2 |
| B4 | **Every autosave rewrites the whole project.** 700 ms after any change: every scene file, `story/metadata.json`, the manifest, `binder.json`, `presentation.json`, `AI-GUIDE.md`, `schema.json`; two fsync'd journal lines; and two SHA-256 passes over every file (before and after). Every mtime changes, so git, sync clients and AI tools see the entire project as modified on each keystroke burst. | `ProjectRepository.save` `:388-445`, `writeManuscript` `:454-499`, `fingerprint` `:692-727`. Journal shows `"57 documents"` on every save. | §4, Phase 1 |
| B5 | **Reordering renames files.** Order is a dense `NNN-` prefix, so inserting or moving one scene renames every sibling after it; retitling renames too. The author's git repo shows dozens of deleted/re-added paths, and an AI tool holding a path loses it. | `writeManuscript` prefix `:474`; `git status` of a real project. | §3.2, Phase 1 |
| B6 | **History is a full copy every ten minutes.** Each save point is the whole project as one pretty-printed JSON (1.7 MB for a 600 KB manuscript); 50 of them are 28 MB. Listing and pruning decode every file. | `createSnapshot` `:643-658`, `pruneAutosaveSnapshots` `:662-677`; `history/` on disk. | §4.5, Phase 1 |
| B7 | **Trash lives inside the metadata file.** Deleted scenes and folders are embedded as payloads in `story/metadata.json`: 1.10 MB of its 1.13 MB, re-encoded and rewritten on every save. | `StoryMetadata.trash`; measured on disk. | §3.6, Phase 1 |
| B8 | **External files are renamed and rewritten the moment they are noticed.** A Markdown file an AI tool has just created is "adopted" on the next autosave: front matter injected, file renamed under a numeric prefix, original deleted. A tool still editing that path fails or recreates it. Empty duplicate folders (`004-Volume 1`, `005-Volume 1`, `Volume 1`) are left behind in the real project. | `adopt` + `sweep` `:517-559`; `WorkspaceModel` `pendingAdoptions`; observed on disk. | §3.3, §4.3, Phase 1 |

## P1 — architecture and data

| ID | Finding | Evidence | Fix |
|---|---|---|---|
| A1 | **God object.** `WorkspaceModel` is 2,571 lines, ~30 `@Published` properties, an `ObservableObject` read by ~60 `@EnvironmentObject` views. `project` is one published struct, so each keystroke (`updateText`) and each selection change invalidates the sidebar, binder, status bar, inspector and toolbar. | `WorkspaceModel.swift`; pattern counts. | §5, Phase 2 |
| A2 | **Uncached work in rows.** `SceneRow` calls `document.wordCount` (a full split of the text) instead of the memo; findings/arcs/index are rebuilt for the whole project 450 ms after any edit. | `ManuscriptViews.swift:364`; `rebuildDerived`. | §5, §4.6 |
| A3 | **Whole-project equality and whole-project undo.** `mutate` copies the project, compares all of it, and registers the previous copy as the undo step. | `WorkspaceModel.swift:2183-2216`. | §5.4 |
| A4 | **Two sources of truth for structure.** The binder tree and the legacy `volume` / `chapter` front-matter strings both exist. The jump bar shows "Volume 1" for a root-level scene; export reports "57 scenes · 1 chapters"; `move(_:by:)`, `moveDocuments`, `createScene(in: Chapter)` still edit `documents` order and ignore the tree. | Observed live; `StoryModel.swift:119-135`, `WorkspaceModel.swift:392-411, 460-472, 976-1008`. | §3, Phase 1–2 |
| A5 | **Folder identity is a hash of its path.** Renaming or reordering a folder gives it a new id, so collapse state and selection are lost; folder types are an index keyed by path that silently falls behind. | `folderID(for:)` `:294-300`; `GroupIndex`. | §3.4 |
| A6 | **Hand-rolled YAML subset.** Block scalars, block lists and nested maps — what people and AI tools actually write — are not parsed; such lines are kept as "preserved" text and the known key is written again, producing duplicate keys. Multi-line craft notes cannot be written naturally. | `MarkdownDocument.decode` `:1327-1390`, `YAML` `:1398-1471`. | §3.5 |
| A7 | **Whole-scene conflict granularity.** If an outside edit and an in-app edit touch the same scene — even different paragraphs — the app stops saving the *whole project* and shows a modal choice. There is no paragraph merge and no per-scene review. | `synchronizeExternalChanges`, `choose`, `mergeDocuments` `:1732-1915`; `scheduleAutosave` guard `:2305`. | §4.4 |
| A8 | **External-change detection reloads everything.** Any event re-hashes and re-parses the entire project; one vnode source per directory; own writes are told apart by "are we currently saving" plus a 1.5 s wait. | `:1716-1725`, `:1950-2011`. | §4.3 |
| A9 | **Opaque references.** Scenes link threads by raw UUID arrays; characters, locations, threads, events, notes and comments live in one JSON file. Nothing is greppable or diffable, and an AI tool must cross-reference UUIDs to do anything. | `story/metadata.json`, front matter `opens/advances/lands`. | §3.6–3.7 |
| A10 | **Format debris.** A stale `manifest.yaml` (v0) sits beside `project.storyloom` and both claim to be canonical; every scene writes every key even when empty (16 lines of `""` and `[]`); the title is stored in front matter *and* as the first heading; `targetWordCount: 500` is a default stamped on every scene. | Real project on disk. | §3.5, §11 |
| A11 | **Silent failure.** 49 `try?` sites, several on writes and deletes in the save path; a failed sweep or journal write is invisible. Error alert is a generic "StoryLoom" + message. | grep; `sweep`, `journal`. | §4, §7.9 |
| A12 | **Quit can lose the last edits or hang.** `flush()` blocks the main thread on a semaphore for up to 2 s while a detached task awaits an actor; on timeout the process exits mid-write. | `WorkspaceModel.swift:2391-2420`. | §4.2 |

## P1 — interface (observed in the running app)

| ID | Finding | Fix |
|---|---|---|
| U1 | **Toggling the inspector makes the manuscript jump**: the top inset collapses and the text moves under the format bar. | §7.4 |
| U2 | **Content is clipped at ordinary window sizes.** At 1240 pt wide the inspector and the format bar run off the right edge (word count, section captions, the last toolbar groups are cut). | §7.4–7.5 |
| U3 | **Export preview is blank.** The Preview pane shows nothing for the entire manuscript. | §7.8 |
| U4 | **Surfaces disagree.** Toolbar, inspector and Settings chrome are navy; the canvas is warm black; the sidebar is neutral grey. Custom backgrounds are painted over system materials. 59 raw colour literals and 34 literal font sizes sit outside the token file. | §7.1 |
| U5 | **Each room invents its own chrome.** Different row heights and list styles (binder vs Story vs Timeline), a 25 pt "+" in one room and a 10–15 pt "+" in others, sans headings in one detail view and serif in another, destructive actions as blue text links ("Delete Record", "Delete Event") in two rooms and absent in a third. | §7.3 |
| U6 | **The toolbar's "New Scene" is shown in every room** — in Story, Timeline and Threads it creates a scene. | §7.2 |
| U7 | **Status is shown twice** (jump bar and inspector header) and the jump-bar pill is clipped at the trailing edge; the jump bar's first field is the dead legacy "chapter" string. | §7.4 |
| U8 | **Empty-scene prompt floats** left of and above the text column instead of sitting where the first line will be. | §7.4 |
| U9 | **Menu bar is not a Mac writing app's menu bar.** No Open Recent, no Close Project, no Spelling and Grammar / Substitutions / Transformations / Speech, system tab items present, History and Trash reachable only through "Go to". | §6.3 |
| U10 | **Command palette is a sheet** that dims the window; every row carries the word "Action"; the last row is clipped; it lists commands only, not scenes or characters. | §7.7 |
| U11 | **Goal progress lies when over target** ("1,06,606 / 1,00,000 · 100%", "0 remaining"); "1 chapters", "1 words" (no plural rules). | §7.6 |
| U12 | **One window plays two roles.** The launcher and the workspace share a window whose style mask is mutated on each update; the title is hidden by a deferred AppKit call. Focus mode replaces the whole view tree with a second `EditorCanvas`, discarding scroll position. | §6.1, §7.4 |
| U13 | **Small targets, faint text.** Format buttons are 23×20 pt, the "+" as small as 10×10; inspector prompts are 11 pt at low contrast; several custom text views have no accessibility label. | §7.1, §10.2 |
| U14 | **The recovery banner is mislabelled**: every notice — unreadable metadata, newer appearance file — is titled "A previous save was interrupted". | §7.9 |
| U15 | **Format shortcuts and bar are overloaded** (≈18 controls in one fixed strip, no overflow). | §7.5 |

## P2 — quality and tooling

| ID | Finding | Fix |
|---|---|---|
| Q1 | Tests write `StoryLoomTests.<uuid>.plist` into the real app container on every run (12 found). | Phase 0 |
| Q2 | `tools/run-smoke-tests.sh` compiles a file that no longer exists (`SampleProject.swift`); the script cannot run. | Phase 0 |
| Q3 | Two sandbox containers exist (`io.StoryOS`, `io.Storyloom`); Debug and the author's daily build share one bundle id, so a development build reopens the author's real novel on launch. | Phase 0 |
| Q4 | Model types import SwiftUI for colours and icons, so nothing below the UI can be built or tested without it. | §2 |
| Q5 | No localisation (`String(localized:)` is used nowhere), although the build setting for string catalogs is on. | §10.3 |
| Q6 | `print(` in 9 places; no `Logger`. | §10 |
| Q7 | Stale `build/` (344 MB) and `.build/` (157 MB) derived-data folders inside the repo folder. | housekeeping |

## What the format looks like to an AI tool today

An agent handed the folder must: read a generated guide; keep UUIDs intact; never create a thread or
character (they are entries in a 1 MB JSON file); expect the file it just wrote to be renamed and
rewritten under it; and expect every other file's mtime to change every few seconds. That is
workable for read-and-edit-one-scene and hostile to everything else. The redesign in
`ARCHITECTURE.md §3` and `§8` exists to make the folder itself the interface.

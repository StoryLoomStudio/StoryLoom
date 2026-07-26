# Graph Report - StoryOS  (2026-07-26)

## Corpus Check
- 143 files · ~102,598 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1630 nodes · 4487 edges · 57 communities (50 shown, 7 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 181 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `209de6c2`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Community 0
- Community 1
- Community 2
- Community 3
- Community 4
- Community 5
- Community 6
- Community 7
- Community 8
- Community 9
- Community 10
- Community 11
- Community 12
- Community 13
- Community 14
- Community 15
- Community 16
- Community 17
- Community 18
- Community 19
- Community 20
- Community 21
- Community 22
- Community 23
- Community 24
- Community 25
- Community 26
- Community 27
- .send
- PersistenceState
- StartScreen
- View
- EntityKind
- Community 33
- Community 34
- Community 35
- Overlays.swift
- FindingSeverity
- FindingKind
- ThreadKind
- WorkspaceView.swift
- AppCommands
- Date
- Community 43
- CodingKeys
- WorkspaceView
- Community 46
- WorkspaceView.swift
- ProseStyler.swift
- .edit
- FlowLayout
- Community 57
- Community 76
- Community 125
- Community 126
- Community 130
- Community 133

## God Nodes (most connected - your core abstractions)
1. `WorkspaceModel` - 204 edges
2. `Glyph` - 123 edges
3. `NSRange` - 118 edges
4. `StoryProject` - 86 edges
5. `StoryDocument` - 66 edges
6. `Coordinator` - 42 edges
7. `InlineParser` - 38 edges
8. `StoryEntity` - 38 edges
9. `ProseStyle` - 36 edges
10. `ManuscriptTextView` - 35 edges

## Surprising Connections (you probably didn't know these)
- `ExportPanel` --calls--> `ExportProfile`  [INFERRED]
  StoryOS/Overlays.swift → StoryOS/ExportService.swift
- `WorkspaceModel` --calls--> `EditorSelection`  [INFERRED]
  StoryOS/WorkspaceModel.swift → StoryOS/ManuscriptEditor.swift
- `EnvironmentValues` --references--> `ProseStyle`  [EXTRACTED]
  StoryOS/WorkspaceView.swift → StoryOS/ProseStyler.swift
- `String` --references--> `NSRange`  [EXTRACTED]
  StoryOS/ProseStyler.swift → StoryOS/TextAnchor.swift
- `WorkspaceModel` --calls--> `StoryIndex`  [INFERRED]
  StoryOS/WorkspaceModel.swift → StoryOS/StoryBrain.swift

## Import Cycles
- None detected.

## Communities (57 total, 7 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.11
Nodes (7): DispatchSourceFileSystemObject, Bool, Double, Never, Set, WorkspaceModel, UndoManager

### Community 1 - "Community 1"
Cohesion: 0.20
Nodes (8): Character, HTMLToMarkdownConverter, Node, String, Bool, Int, Set, String

### Community 2 - "Community 2"
Cohesion: 0.11
Nodes (21): InlineFormat, emphasis, highlight, strikethrough, strong, InlineMarkup, MarkerRun, Markers (+13 more)

### Community 3 - "Community 3"
Cohesion: 0.13
Nodes (25): BarDivider, CommentRow, EditorCanvas, EditorStatusBar, EmptyPagePrompt, FormatBar, FormatButton, JumpBar (+17 more)

### Community 4 - "Community 4"
Cohesion: 0.06
Nodes (62): DelimRun, EmphasisKind, bold, boldItalic, italic, ExtensionInlineNode, InlineNode, code (+54 more)

### Community 5 - "Community 5"
Cohesion: 0.08
Nodes (28): NSFontTraitMask, NSTextCheckingResult, LineHeight, double, normal, relaxed, tight, NSAttributedString.Key (+20 more)

### Community 6 - "Community 6"
Cohesion: 0.23
Nodes (6): NSTextRange, NSTextStorageDelegate, Coordinator, Never, Notification, Void

### Community 7 - "Community 7"
Cohesion: 0.14
Nodes (22): Action, Content, Block, EmptyStateView, Fact, Facts, FilterField, GroupHeader (+14 more)

### Community 8 - "Community 8"
Cohesion: 0.02
Nodes (99): Glyph, advances, alignCentre, alignEnd, alignJustify, alignStart, annotate, archive (+91 more)

### Community 9 - "Community 9"
Cohesion: 0.12
Nodes (26): Fuzzy, SearchDestination, document, entity, event, note, relationship, snapshot (+18 more)

### Community 10 - "Community 10"
Cohesion: 0.09
Nodes (31): CryptoKit, FileManager, DocumentEntry, LocalProjectRepository, MarkdownDocument, ProjectLoad, ProjectManifest, ProjectRepositoryError (+23 more)

### Community 12 - "Community 12"
Cohesion: 0.09
Nodes (31): DropDelegate, DropInfo, DropProposal, NSItemProvider, BinderDrag, BinderName, BinderOutline, BinderRowDrop (+23 more)

### Community 13 - "Community 13"
Cohesion: 0.18
Nodes (10): Equatable, NSMenuItem, NSTextFinder, EditorCommandRequest, ManuscriptEditor, RevealRequest, Coordinator, UUID (+2 more)

### Community 14 - "Community 14"
Cohesion: 0.06
Nodes (31): NSTrackingArea, NSView, NSViewRepresentable, BinderContextMenu, BinderMenu, BinderMenuEntry, destructive, item (+23 more)

### Community 15 - "Community 15"
Cohesion: 0.08
Nodes (31): CaseIterable, Sendable, PageViewMode, continuous, page, ExportPreview, ExportRecord, ExportWarning (+23 more)

### Community 16 - "Community 16"
Cohesion: 0.12
Nodes (8): Error, HistoryReason, ProjectSnapshotRecord, Int, String, Task, URL, WorkspaceError

### Community 17 - "Community 17"
Cohesion: 0.22
Nodes (9): AnyShapeStyle, ArcBlock, BeatRow, OwedRow, Bool, String, ThreadCanvas, ThreadLine (+1 more)

### Community 18 - "Community 18"
Cohesion: 0.12
Nodes (23): CompositionSettings, GeneralSettings, PagePreview, PageSettings, SettingsView, AppearanceRow, EntityDossier, EntityRow (+15 more)

### Community 19 - "Community 19"
Cohesion: 0.28
Nodes (5): Array, Bool, Int, Set, UUID

### Community 20 - "Community 20"
Cohesion: 0.07
Nodes (26): App, AppKit, Commands, Foundation, NSApplication, NSApplicationDelegate, NSObject, ObservableObject (+18 more)

### Community 21 - "Community 21"
Cohesion: 0.08
Nodes (6): UUID, StoryProject, ThreadList, threads, UUID, Void

### Community 22 - "Community 22"
Cohesion: 0.12
Nodes (22): ThreadLinks, StoryThread, Bool, Int, String, UUID, ThreadArc, ThreadBeat (+14 more)

### Community 23 - "Community 23"
Cohesion: 0.09
Nodes (23): CodingKeys, advancesThreadIDs, archivedDocuments, binder, chapter, documents, id, intention (+15 more)

### Community 24 - "Community 24"
Cohesion: 0.16
Nodes (23): Codable, Identifiable, EventCertainty, approximate, disputed, stated, unplaced, FindingDisposition (+15 more)

### Community 25 - "Community 25"
Cohesion: 0.12
Nodes (16): ISO8601DateFormatter, Date, JSONDecoder, JSONEncoder, Timestamp, String, UUID, TrashedItem (+8 more)

### Community 26 - "Community 26"
Cohesion: 0.06
Nodes (33): Animation, CGSize, NSFontDescriptor, ColorScheme, Chrome, Icon, IconView, Metrics (+25 more)

### Community 28 - ".send"
Cohesion: 0.16
Nodes (16): Chapter, DocumentKind, note, scene, DocumentStatus, done, draft, outline (+8 more)

### Community 29 - "PersistenceState"
Cohesion: 0.14
Nodes (13): ExternalChange, LibraryItem, history, manuscript, story, timeline, trash, PersistenceState (+5 more)

### Community 30 - "StartScreen"
Cohesion: 0.22
Nodes (8): RecentRow, StartAction, StartScreen, String, Int, NSSize, String, Void

### Community 31 - "View"
Cohesion: 0.06
Nodes (41): Comparable, Int, ContinuityChecker, FindingEvidence, FindingKind, aliasCollision, chronologyInversion, emptyScene (+33 more)

### Community 32 - "EntityKind"
Cohesion: 0.16
Nodes (8): Image, HighlightedText, Font, Range, LibrarySidebar, String, TrashContents, Text

### Community 33 - "Community 33"
Cohesion: 0.16
Nodes (13): EditorCommand, alignment, blockquote, face, format, heading, highlight, list (+5 more)

### Community 34 - "Community 34"
Cohesion: 0.15
Nodes (7): NSTextContainer, ManuscriptTextView, Any, NSCoder, NSEvent, NSMenu, NSRect

### Community 35 - "Community 35"
Cohesion: 0.05
Nodes (46): LocalizedError, NSTextAlignment, Any, ExportError, renderFailed, usePDFWriter, ExportFormat, docx (+38 more)

### Community 36 - "Overlays.swift"
Cohesion: 0.05
Nodes (39): Actions, EnvironmentKey, NavigationSplitViewVisibility, NSWindow, CommandPalette, Coordinator, KeyMonitor, PaletteAction (+31 more)

### Community 37 - "FindingSeverity"
Cohesion: 0.10
Nodes (17): Combine, AppAppearance, dark, light, system, AppSettings, Bool, ColorScheme (+9 more)

### Community 39 - "ThreadKind"
Cohesion: 0.17
Nodes (11): Decoder, ThreadKind, characterArc, conflict, foreshadowing, goal, mystery, promise (+3 more)

### Community 40 - "WorkspaceView.swift"
Cohesion: 0.13
Nodes (14): Chip, WarningRow, EntityKind, character, location, object, organization, symbol (+6 more)

### Community 41 - "AppCommands"
Cohesion: 0.24
Nodes (12): Hashable, BinderItem, GroupKind, chapter, folder, part, volume, Kind (+4 more)

### Community 42 - "Date"
Cohesion: 0.23
Nodes (7): NSScrollView, NSTextContentStorage, NSTextLayoutManager, ManuscriptScrollView, Context, NSAttributedString, String

### Community 43 - "Community 43"
Cohesion: 0.17
Nodes (7): NSSelectionAffinity, NSValue, NSEdgeInsets, Bool, Int, NSTextView, UnsafeMutablePointer

### Community 44 - "CodingKeys"
Cohesion: 0.33
Nodes (6): CodingKeys, answer, id, isAbandoned, kind, question

### Community 46 - "Community 46"
Cohesion: 0.09
Nodes (23): CodingKeys, aliases, certainty, chronologyLabel, comments, dispositions, entities, events (+15 more)

### Community 47 - "WorkspaceView.swift"
Cohesion: 0.29
Nodes (7): CodingKey, CodingKeys, children, group, id, kind, name

### Community 48 - "ProseStyler.swift"
Cohesion: 0.33
Nodes (4): NSTextStorageEditActions, EditorSelection, NSTextStorage, Set

### Community 49 - ".edit"
Cohesion: 0.50
Nodes (3): FieldRow, InspectorPane, Value

### Community 51 - "FlowLayout"
Cohesion: 0.36
Nodes (6): CGPoint, CGRect, Layout, ProposedViewSize, FlowLayout, Subviews

### Community 57 - "Community 57"
Cohesion: 0.15
Nodes (11): NSTextView, NSTextViewDelegate, Coordinator, GrowingText, QuietTextView, Context, Coordinator, Int (+3 more)

### Community 76 - "Community 76"
Cohesion: 0.13
Nodes (20): ArraySlice, BlockParser, BufferDiff, MarkdownBlock, MarkdownBlockKind, blank, blockLatex, blockquote (+12 more)

### Community 126 - "Community 126"
Cohesion: 0.40
Nodes (4): Modifications, SwiftMarkdownEngine, Third-party code, What was taken, and what was not

## Knowledge Gaps
- **379 isolated node(s):** `continuous`, `page`, `light`, `dark`, `system` (+374 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `WorkspaceModel` connect `Community 0` to `Community 3`, `Community 10`, `Community 11`, `Community 12`, `Community 13`, `Community 16`, `Community 17`, `Community 18`, `Community 20`, `Community 21`, `Community 22`, `Community 24`, `Community 25`, `.send`, `PersistenceState`, `StartScreen`, `View`, `EntityKind`, `Community 35`, `Overlays.swift`, `FindingSeverity`, `WorkspaceView.swift`, `AppCommands`, `WorkspaceView`, `ProseStyler.swift`, `.edit`?**
  _High betweenness centrality (0.214) - this node is a cross-community bridge._
- **Why does `NSRange` connect `Community 4` to `Community 1`, `Community 2`, `Community 35`, `Community 34`, `Community 5`, `Community 6`, `Community 9`, `Date`, `Community 43`, `Community 76`, `Community 13`, `ProseStyler.swift`, `Community 18`, `Community 20`, `Community 21`, `View`?**
  _High betweenness centrality (0.162) - this node is a cross-community bridge._
- **Why does `Glyph` connect `Community 8` to `Community 2`, `Community 3`, `Community 7`, `Community 15`, `Community 17`, `Community 18`, `Community 22`, `Community 24`, `Community 26`, `.send`, `PersistenceState`, `StartScreen`, `EntityKind`, `Community 35`, `Overlays.swift`, `FindingSeverity`, `ThreadKind`, `WorkspaceView.swift`, `AppCommands`?**
  _High betweenness centrality (0.158) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `WorkspaceModel` (e.g. with `.appearances()` and `EditorSelection`) actually correct?**
  _`WorkspaceModel` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `NSRange` (e.g. with `.inlineAttributed()` and `.prose()`) actually correct?**
  _`NSRange` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 27 inferred relationships involving `StoryProject` (e.g. with `.adopt()` and `.archive()`) actually correct?**
  _`StoryProject` has 27 INFERRED edges - model-reasoned connections that need verification._
- **What connects `continuous`, `page`, `light` to the rest of the system?**
  _379 weakly-connected nodes found - possible documentation gaps or missing edges._
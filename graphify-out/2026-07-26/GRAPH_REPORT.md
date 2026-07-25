# Graph Report - StoryOS  (2026-07-26)

## Corpus Check
- 42 files · ~83,914 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1325 nodes · 3781 edges · 57 communities (53 shown, 4 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 155 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

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
- Hashable
- WorkspaceView.swift
- WindowConfigurator
- Date
- Community 43
- CodingKeys
- WorkspaceView
- Community 46
- .updateNSView
- WorkspaceSheet
- Community 55
- Community 57
- Community 76
- Community 118
- Community 125
- Community 126
- Community 130
- Community 133

## God Nodes (most connected - your core abstractions)
1. `WorkspaceModel` - 172 edges
2. `NSRange` - 117 edges
3. `StoryProject` - 73 edges
4. `StoryDocument` - 60 edges
5. `Coordinator` - 42 edges
6. `InlineParser` - 38 edges
7. `ProseStyle` - 36 edges
8. `StoryEntity` - 36 edges
9. `ManuscriptTextView` - 35 edges
10. `AppSettings` - 31 edges

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

## Communities (57 total, 4 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.08
Nodes (12): Error, InspectorPane, ExternalChange, Bool, Double, Int, Never, Task (+4 more)

### Community 1 - "Community 1"
Cohesion: 0.20
Nodes (8): Character, HTMLToMarkdownConverter, Node, String, Bool, Int, Set, String

### Community 2 - "Community 2"
Cohesion: 0.10
Nodes (22): AppKit, InlineFormat, emphasis, highlight, strikethrough, strong, InlineMarkup, MarkerRun (+14 more)

### Community 3 - "Community 3"
Cohesion: 0.12
Nodes (26): BarDivider, EditorCanvas, EditorStatusBar, EmptyPagePrompt, FormatButton, JumpBar, LibrarySidebar, PageRulerView (+18 more)

### Community 4 - "Community 4"
Cohesion: 0.06
Nodes (63): Equatable, DelimRun, EmphasisKind, bold, boldItalic, italic, ExtensionInlineNode, InlineNode (+55 more)

### Community 5 - "Community 5"
Cohesion: 0.16
Nodes (14): NSFontTraitMask, ProseStyle, ProseStyler, Any, Bool, CGFloat, ColorScheme, NSAttributedString (+6 more)

### Community 6 - "Community 6"
Cohesion: 0.23
Nodes (5): NSTextRange, NSTextStorageDelegate, Coordinator, Never, Notification

### Community 7 - "Community 7"
Cohesion: 0.09
Nodes (32): Action, Content, Font, Block, Chip, EmptyStateView, Fact, Facts (+24 more)

### Community 8 - "Community 8"
Cohesion: 0.12
Nodes (15): NSTextCheckingResult, Any, LineHeight, double, normal, relaxed, tight, NSAttributedString.Key (+7 more)

### Community 9 - "Community 9"
Cohesion: 0.13
Nodes (24): Fuzzy, SearchDestination, document, entity, event, note, relationship, snapshot (+16 more)

### Community 10 - "Community 10"
Cohesion: 0.07
Nodes (39): CryptoKit, FileManager, ISO8601DateFormatter, HistoryReason, ProjectSnapshotRecord, Int, String, DocumentEntry (+31 more)

### Community 11 - "Community 11"
Cohesion: 0.11
Nodes (8): LibraryItem, history, manuscript, notes, review, story, timeline, String

### Community 12 - "Community 12"
Cohesion: 0.24
Nodes (7): Coordinator, KeyMonitor, Any, Context, Coordinator, Int, NSView

### Community 13 - "Community 13"
Cohesion: 0.23
Nodes (8): ExportProfile, ExportService, Data, Double, NSAttributedString, NSFont, NSParagraphStyle, URL

### Community 14 - "Community 14"
Cohesion: 0.12
Nodes (16): Combine, ObservableObject, AppSettings, Bool, Double, UserDefaults, TypeMenu, TypePanel (+8 more)

### Community 15 - "Community 15"
Cohesion: 0.17
Nodes (7): NSSelectionAffinity, NSValue, NSEdgeInsets, Bool, Int, NSTextView, UnsafeMutablePointer

### Community 16 - "Community 16"
Cohesion: 0.21
Nodes (12): ContinuityChecker, FindingEvidence, FindingTarget, comment, document, entity, event, thread (+4 more)

### Community 17 - "Community 17"
Cohesion: 0.13
Nodes (20): AnyShapeStyle, ThreadArc, ThreadState, abandoned, cooling, landed, open, unopened (+12 more)

### Community 18 - "Community 18"
Cohesion: 0.18
Nodes (12): AppearanceRow, EntityList, EntityRow, EventDetail, EventRow, MentionGroup, NoteEditor, NoteList (+4 more)

### Community 19 - "Community 19"
Cohesion: 0.26
Nodes (7): NSTextView, NSViewRepresentable, GrowingText, QuietTextView, Context, NSEvent, NSSize

### Community 20 - "Community 20"
Cohesion: 0.19
Nodes (10): App, Scene, Entry, RecentProjects, Any, Bool, String, URL (+2 more)

### Community 21 - "Community 21"
Cohesion: 0.18
Nodes (9): NSTextFinder, EditorCommandRequest, EditorSelection, ManuscriptEditor, RevealRequest, Coordinator, UUID, TextBehaviour (+1 more)

### Community 22 - "Community 22"
Cohesion: 0.11
Nodes (13): ThreadLinks, StoryThread, Bool, Decoder, String, UUID, ThreadKind, mystery (+5 more)

### Community 23 - "Community 23"
Cohesion: 0.10
Nodes (21): CodingKeys, advancesThreadIDs, archivedDocuments, chapter, documents, id, intention, kind (+13 more)

### Community 24 - "Community 24"
Cohesion: 0.08
Nodes (28): EntityKind, character, location, object, organization, symbol, theme, RelationshipKind (+20 more)

### Community 25 - "Community 25"
Cohesion: 0.22
Nodes (8): NSScrollView, NSTextContentStorage, NSTextLayoutManager, ManuscriptScrollView, Context, NSAttributedString, String, Void

### Community 26 - "Community 26"
Cohesion: 0.20
Nodes (8): EventCertainty, approximate, disputed, stated, unplaced, StoryEvent, EventList, UUID

### Community 28 - ".send"
Cohesion: 0.11
Nodes (17): IndexSet, ManuscriptNavigator, Chapter, DocumentKind, note, scene, DocumentStatus, done (+9 more)

### Community 29 - "PersistenceState"
Cohesion: 0.33
Nodes (6): PersistenceState, failed, loading, saved, saving, unsaved

### Community 30 - "StartScreen"
Cohesion: 0.22
Nodes (8): RecentRow, StartAction, StartScreen, String, Int, NSSize, String, Void

### Community 31 - "View"
Cohesion: 0.16
Nodes (10): Mention, StoryBrain, StoryIndex, Bool, Int, NSString, Range, String (+2 more)

### Community 32 - "EntityKind"
Cohesion: 0.28
Nodes (4): NSTextViewDelegate, Coordinator, Coordinator, Notification

### Community 33 - "Community 33"
Cohesion: 0.16
Nodes (13): EditorCommand, alignment, blockquote, face, format, heading, highlight, list (+5 more)

### Community 34 - "Community 34"
Cohesion: 0.15
Nodes (7): NSCoder, NSMenu, NSRect, NSTextContainer, ManuscriptTextView, Any, NSEvent

### Community 35 - "Community 35"
Cohesion: 0.13
Nodes (21): Identifiable, NSTextAlignment, FormatBar, Set, HighlightColour, amber, mint, rose (+13 more)

### Community 36 - "Overlays.swift"
Cohesion: 0.20
Nodes (12): CommandPalette, PaletteAction, PaletteEntry, PaletteRow, SearchHelp, SearchPanel, SearchRow, Bool (+4 more)

### Community 37 - "FindingSeverity"
Cohesion: 0.33
Nodes (5): AppAppearance, dark, light, system, ColorScheme

### Community 38 - "FindingKind"
Cohesion: 0.10
Nodes (20): Comparable, Int, FindingKind, aliasCollision, chronologyInversion, emptyScene, eventWithoutScene, orphanedComment (+12 more)

### Community 39 - "Hashable"
Cohesion: 0.20
Nodes (12): Codable, Hashable, FindingDisposition, dismissed, intentional, Int, ThreadBeat, ThreadRole (+4 more)

### Community 40 - "WorkspaceView.swift"
Cohesion: 0.17
Nodes (10): Actions, EnvironmentKey, Banner, EnvironmentValues, Notification.Name, ProseStyleKey, StoryLoomCommand, export (+2 more)

### Community 41 - "WindowConfigurator"
Cohesion: 0.30
Nodes (6): NSWindow, Coordinator, Bool, Context, NSView, WindowConfigurator

### Community 42 - "Date"
Cohesion: 0.40
Nodes (3): NSTextStorageEditActions, NSTextStorage, Set

### Community 43 - "Community 43"
Cohesion: 0.17
Nodes (11): Foundation, CommentRow, Bool, StoryComment, Bool, Double, Int, NSString (+3 more)

### Community 44 - "CodingKeys"
Cohesion: 0.29
Nodes (7): CodingKey, CodingKeys, answer, id, isAbandoned, kind, question

### Community 45 - "WorkspaceView"
Cohesion: 0.18
Nodes (9): NavigationSplitViewVisibility, Binding, Notification, WorkspaceSheet, export, palette, search, WorkspaceView (+1 more)

### Community 46 - "Community 46"
Cohesion: 0.09
Nodes (22): CodingKeys, aliases, certainty, chronologyLabel, comments, dispositions, entities, events (+14 more)

### Community 47 - ".updateNSView"
Cohesion: 0.40
Nodes (4): FocusDepth, off, paragraph, sentence

### Community 48 - "WorkspaceSheet"
Cohesion: 0.67
Nodes (3): PageViewMode, continuous, page

### Community 55 - "Community 55"
Cohesion: 0.05
Nodes (43): Animation, CGRect, CGSize, Edge, Layout, NSFontDescriptor, ProposedViewSize, FlowLayout (+35 more)

### Community 57 - "Community 57"
Cohesion: 0.16
Nodes (9): Commands, NSApplication, NSApplicationDelegate, NSObject, AppCommands, AppDelegate, Bool, Notification (+1 more)

### Community 76 - "Community 76"
Cohesion: 0.13
Nodes (20): ArraySlice, BlockParser, BufferDiff, MarkdownBlock, MarkdownBlockKind, blank, blockLatex, blockquote (+12 more)

### Community 118 - "Community 118"
Cohesion: 0.12
Nodes (23): CaseIterable, LocalizedError, Sendable, ExportError, renderFailed, usePDFWriter, ExportFormat, docx (+15 more)

### Community 126 - "Community 126"
Cohesion: 0.40
Nodes (4): Modifications, SwiftMarkdownEngine, Third-party code, What was taken, and what was not

## Knowledge Gaps
- **243 isolated node(s):** `continuous`, `page`, `light`, `dark`, `system` (+238 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `NSRange` connect `Community 4` to `Community 1`, `Community 2`, `Community 3`, `Community 5`, `Community 6`, `Community 8`, `Community 9`, `Community 13`, `Community 15`, `Community 16`, `Community 18`, `Community 21`, `Community 25`, `View`, `Community 34`, `Community 35`, `Date`, `Community 43`, `.updateNSView`, `Community 76`?**
  _High betweenness centrality (0.257) - this node is a cross-community bridge._
- **Why does `WorkspaceModel` connect `Community 0` to `Community 3`, `Community 7`, `Community 10`, `Community 11`, `Community 14`, `Community 16`, `Community 17`, `Community 18`, `Community 20`, `Community 21`, `Community 22`, `Community 24`, `Community 26`, `.send`, `PersistenceState`, `StartScreen`, `View`, `Community 35`, `Overlays.swift`, `Community 43`, `WorkspaceView`, `Community 57`, `Community 118`?**
  _High betweenness centrality (0.212) - this node is a cross-community bridge._
- **Why does `StoryProject` connect `Community 16` to `Community 0`, `Community 4`, `Hashable`, `Community 9`, `Community 10`, `Community 11`, `Community 13`, `Community 118`, `Community 22`, `Community 24`, `Community 26`, `.send`, `View`?**
  _High betweenness centrality (0.060) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `WorkspaceModel` (e.g. with `.appearances()` and `EditorSelection`) actually correct?**
  _`WorkspaceModel` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `NSRange` (e.g. with `.inlineAttributed()` and `.prose()`) actually correct?**
  _`NSRange` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 19 inferred relationships involving `StoryProject` (e.g. with `.archive()` and `.canMove()`) actually correct?**
  _`StoryProject` has 19 INFERRED edges - model-reasoned connections that need verification._
- **What connects `continuous`, `page`, `light` to the rest of the system?**
  _243 weakly-connected nodes found - possible documentation gaps or missing edges._
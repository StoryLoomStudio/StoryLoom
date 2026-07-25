# Graph Report - StoryOS  (2026-07-26)

## Corpus Check
- 45 files · ~84,313 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1325 nodes · 3784 edges · 53 communities (48 shown, 5 thin omitted)
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
- WorkspaceView.swift
- Date
- Community 43
- CodingKeys
- WorkspaceView
- Community 46
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

## Communities (53 total, 5 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.08
Nodes (12): InspectorPane, ExternalChange, Bool, Double, Int, Never, Task, URL (+4 more)

### Community 1 - "Community 1"
Cohesion: 0.20
Nodes (8): Character, HTMLToMarkdownConverter, Node, String, Bool, Int, Set, String

### Community 2 - "Community 2"
Cohesion: 0.11
Nodes (21): InlineFormat, emphasis, highlight, strikethrough, strong, InlineMarkup, MarkerRun, Markers (+13 more)

### Community 3 - "Community 3"
Cohesion: 0.11
Nodes (22): BarDivider, CommentRow, EditorCanvas, EditorStatusBar, EmptyPagePrompt, FormatButton, JumpBar, LibrarySidebar (+14 more)

### Community 4 - "Community 4"
Cohesion: 0.06
Nodes (63): Equatable, DelimRun, EmphasisKind, bold, boldItalic, italic, ExtensionInlineNode, InlineNode (+55 more)

### Community 5 - "Community 5"
Cohesion: 0.07
Nodes (32): NSFontTraitMask, NSTextCheckingResult, ColorScheme, LineHeight, double, normal, relaxed, tight (+24 more)

### Community 6 - "Community 6"
Cohesion: 0.23
Nodes (5): NSTextRange, NSTextStorageDelegate, Coordinator, Never, Notification

### Community 7 - "Community 7"
Cohesion: 0.12
Nodes (27): Action, Content, Layout, Block, Chip, EmptyStateView, Fact, Facts (+19 more)

### Community 8 - "Community 8"
Cohesion: 0.32
Nodes (6): Any, ExportRecord, ExportWarning, Int, UUID, String

### Community 9 - "Community 9"
Cohesion: 0.13
Nodes (24): Fuzzy, SearchDestination, document, entity, event, note, relationship, snapshot (+16 more)

### Community 10 - "Community 10"
Cohesion: 0.09
Nodes (30): CryptoKit, FileManager, DocumentEntry, LocalProjectRepository, MarkdownDocument, ProjectManifest, ProjectRepositoryError, identityMismatch (+22 more)

### Community 11 - "Community 11"
Cohesion: 0.14
Nodes (4): Error, notes, String, Void

### Community 12 - "Community 12"
Cohesion: 0.16
Nodes (11): Combine, ObservableObject, EvidenceRow, FindingDetail, FindingList, FindingRow, FindingSelection, SnapshotDetail (+3 more)

### Community 13 - "Community 13"
Cohesion: 0.21
Nodes (9): renderFailed, ExportProfile, ExportService, Data, Double, NSAttributedString, NSFont, NSParagraphStyle (+1 more)

### Community 14 - "Community 14"
Cohesion: 0.21
Nodes (10): AppSettings, Bool, Double, UserDefaults, TypeMenu, CompositionSettings, GeneralSettings, PagePreview (+2 more)

### Community 15 - "Community 15"
Cohesion: 0.17
Nodes (7): NSSelectionAffinity, NSValue, NSEdgeInsets, Bool, Int, NSTextView, UnsafeMutablePointer

### Community 16 - "Community 16"
Cohesion: 0.36
Nodes (4): HistoryReason, ProjectSnapshotRecord, Int, String

### Community 17 - "Community 17"
Cohesion: 0.18
Nodes (14): AnyShapeStyle, ThreadArc, AnswerBlock, ArcBlock, BeatRow, OwedRow, QuestionBlock, Bool (+6 more)

### Community 18 - "Community 18"
Cohesion: 0.16
Nodes (16): StatusDot, AppearanceRow, EntityDossier, EntityList, EntityRow, EventDetail, EventList, EventRow (+8 more)

### Community 19 - "Community 19"
Cohesion: 0.25
Nodes (7): LibraryItem, history, manuscript, review, story, threads, timeline

### Community 20 - "Community 20"
Cohesion: 0.19
Nodes (10): App, Scene, Entry, RecentProjects, Any, Bool, String, URL (+2 more)

### Community 21 - "Community 21"
Cohesion: 0.18
Nodes (9): NSTextFinder, EditorCommandRequest, EditorSelection, ManuscriptEditor, RevealRequest, Coordinator, UUID, TextBehaviour (+1 more)

### Community 22 - "Community 22"
Cohesion: 0.10
Nodes (30): CaseIterable, Hashable, Sendable, ThreadLinks, DocumentKind, note, scene, StoryThread (+22 more)

### Community 23 - "Community 23"
Cohesion: 0.10
Nodes (21): CodingKeys, advancesThreadIDs, archivedDocuments, chapter, documents, id, intention, kind (+13 more)

### Community 24 - "Community 24"
Cohesion: 0.07
Nodes (39): Codable, EntityKind, character, location, object, organization, symbol, theme (+31 more)

### Community 25 - "Community 25"
Cohesion: 0.22
Nodes (8): NSScrollView, NSTextContentStorage, NSTextLayoutManager, ManuscriptScrollView, Context, NSAttributedString, String, Void

### Community 26 - "Community 26"
Cohesion: 0.29
Nodes (7): FormatBar, Set, HighlightColour, amber, mint, rose, sky

### Community 28 - ".send"
Cohesion: 0.10
Nodes (15): IndexSet, ManuscriptNavigator, Chapter, DocumentStatus, done, draft, outline, revised (+7 more)

### Community 29 - "PersistenceState"
Cohesion: 0.33
Nodes (6): PersistenceState, failed, loading, saved, saving, unsaved

### Community 30 - "StartScreen"
Cohesion: 0.22
Nodes (8): RecentRow, StartAction, StartScreen, String, Int, NSSize, String, Void

### Community 31 - "View"
Cohesion: 0.06
Nodes (41): Comparable, Int, ContinuityChecker, FindingEvidence, FindingKind, aliasCollision, chronologyInversion, emptyScene (+33 more)

### Community 32 - "EntityKind"
Cohesion: 0.67
Nodes (3): Font, HighlightedText, Range

### Community 33 - "Community 33"
Cohesion: 0.16
Nodes (13): EditorCommand, alignment, blockquote, face, format, heading, highlight, list (+5 more)

### Community 34 - "Community 34"
Cohesion: 0.15
Nodes (7): NSCoder, NSMenu, NSRect, NSTextContainer, ManuscriptTextView, Any, NSEvent

### Community 35 - "Community 35"
Cohesion: 0.19
Nodes (13): NSTextAlignment, PresentationBlock, PresentationLayer, PresentationRun, Bool, Double, Int, Void (+5 more)

### Community 36 - "Overlays.swift"
Cohesion: 0.11
Nodes (20): NSViewRepresentable, CommandPalette, Coordinator, KeyMonitor, PaletteAction, PaletteEntry, PaletteRow, SearchHelp (+12 more)

### Community 37 - "FindingSeverity"
Cohesion: 0.12
Nodes (16): Identifiable, AppAppearance, dark, light, system, PageViewMode, continuous, page (+8 more)

### Community 40 - "WorkspaceView.swift"
Cohesion: 0.12
Nodes (16): Actions, EnvironmentKey, NSWindow, Banner, Coordinator, EnvironmentValues, Notification.Name, ProseStyleKey (+8 more)

### Community 42 - "Date"
Cohesion: 0.40
Nodes (3): NSTextStorageEditActions, NSTextStorage, Set

### Community 43 - "Community 43"
Cohesion: 0.13
Nodes (14): Foundation, ISO8601DateFormatter, Date, JSONDecoder, JSONEncoder, Timestamp, StoryComment, Bool (+6 more)

### Community 44 - "CodingKeys"
Cohesion: 0.29
Nodes (7): CodingKey, CodingKeys, answer, id, isAbandoned, kind, question

### Community 45 - "WorkspaceView"
Cohesion: 0.29
Nodes (5): NavigationSplitViewVisibility, Binding, Notification, WorkspaceView, ToolbarContent

### Community 46 - "Community 46"
Cohesion: 0.09
Nodes (22): CodingKeys, aliases, certainty, chronologyLabel, comments, dispositions, entities, events (+14 more)

### Community 55 - "Community 55"
Cohesion: 0.06
Nodes (41): Animation, CGRect, CGSize, Edge, NSFontDescriptor, ProposedViewSize, ColorScheme, Chrome (+33 more)

### Community 57 - "Community 57"
Cohesion: 0.08
Nodes (19): Commands, NSApplication, NSApplicationDelegate, NSObject, NSTextView, NSTextViewDelegate, Coordinator, GrowingText (+11 more)

### Community 76 - "Community 76"
Cohesion: 0.13
Nodes (20): ArraySlice, BlockParser, BufferDiff, MarkdownBlock, MarkdownBlockKind, blank, blockLatex, blockquote (+12 more)

### Community 118 - "Community 118"
Cohesion: 0.15
Nodes (13): AppKit, LocalizedError, ExportError, usePDFWriter, ExportFormat, docx, markdown, pdf (+5 more)

### Community 126 - "Community 126"
Cohesion: 0.40
Nodes (4): Modifications, SwiftMarkdownEngine, Third-party code, What was taken, and what was not

## Knowledge Gaps
- **243 isolated node(s):** `continuous`, `page`, `light`, `dark`, `system` (+238 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `NSRange` connect `Community 4` to `Community 1`, `Community 2`, `Community 34`, `Community 35`, `Community 5`, `Community 6`, `Community 3`, `Community 9`, `Date`, `Community 43`, `Community 76`, `Community 13`, `Community 15`, `Community 18`, `Community 21`, `Community 25`, `View`?**
  _High betweenness centrality (0.257) - this node is a cross-community bridge._
- **Why does `WorkspaceModel` connect `Community 0` to `Community 3`, `Community 10`, `Community 11`, `Community 12`, `Community 16`, `Community 17`, `Community 18`, `Community 19`, `Community 20`, `Community 21`, `Community 22`, `Community 24`, `Community 26`, `.send`, `PersistenceState`, `StartScreen`, `View`, `Community 35`, `Overlays.swift`, `Community 43`, `WorkspaceView`, `Community 57`, `Community 118`?**
  _High betweenness centrality (0.212) - this node is a cross-community bridge._
- **Why does `StoryProject` connect `.send` to `Community 0`, `Community 4`, `Community 9`, `Community 10`, `Community 11`, `Community 13`, `Community 16`, `Community 22`, `Community 24`, `View`?**
  _High betweenness centrality (0.060) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `WorkspaceModel` (e.g. with `.appearances()` and `EditorSelection`) actually correct?**
  _`WorkspaceModel` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `NSRange` (e.g. with `.inlineAttributed()` and `.prose()`) actually correct?**
  _`NSRange` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 19 inferred relationships involving `StoryProject` (e.g. with `.archive()` and `.canMove()`) actually correct?**
  _`StoryProject` has 19 INFERRED edges - model-reasoned connections that need verification._
- **What connects `continuous`, `page`, `light` to the rest of the system?**
  _243 weakly-connected nodes found - possible documentation gaps or missing edges._
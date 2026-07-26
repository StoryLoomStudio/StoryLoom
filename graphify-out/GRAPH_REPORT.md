# Graph Report - StoryOS  (2026-07-27)

## Corpus Check
- 143 files · ~102,883 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1640 nodes · 4517 edges · 60 communities (54 shown, 6 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 184 edges (avg confidence: 0.8)
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
- WorkspaceView
- Community 46
- ProseStyler.swift
- AppDelegate
- FlowLayout
- AppCommands
- Date
- Community 57
- TrashViews.swift
- .placement
- .menuImage
- Community 76
- Community 125
- Community 126
- Community 130
- Community 133

## God Nodes (most connected - your core abstractions)
1. `WorkspaceModel` - 206 edges
2. `Glyph` - 123 edges
3. `NSRange` - 118 edges
4. `StoryProject` - 87 edges
5. `StoryDocument` - 66 edges
6. `Coordinator` - 42 edges
7. `InlineParser` - 38 edges
8. `StoryEntity` - 38 edges
9. `ProseStyle` - 36 edges
10. `ManuscriptTextView` - 35 edges

## Surprising Connections (you probably didn't know these)
- `WorkspaceModel` --calls--> `EditorSelection`  [INFERRED]
  StoryOS/WorkspaceModel.swift → StoryOS/ManuscriptEditor.swift
- `EnvironmentValues` --references--> `ProseStyle`  [EXTRACTED]
  StoryOS/WorkspaceView.swift → StoryOS/ProseStyler.swift
- `String` --references--> `NSRange`  [EXTRACTED]
  StoryOS/ProseStyler.swift → StoryOS/TextAnchor.swift
- `StoryLoomApp` --calls--> `RecentProjects`  [INFERRED]
  StoryOS/StoryLoomApp.swift → StoryOS/RecentProjects.swift
- `WorkspaceModel` --calls--> `StoryIndex`  [INFERRED]
  StoryOS/WorkspaceModel.swift → StoryOS/StoryBrain.swift

## Import Cycles
- None detected.

## Communities (60 total, 6 thin omitted)

### Community 1 - "Community 1"
Cohesion: 0.20
Nodes (8): Character, HTMLToMarkdownConverter, Node, String, Bool, Int, Set, String

### Community 2 - "Community 2"
Cohesion: 0.21
Nodes (10): InlineFormat, emphasis, highlight, strikethrough, strong, InlineMarkup, Bool, NSString (+2 more)

### Community 3 - "Community 3"
Cohesion: 0.09
Nodes (26): BarDivider, BinderTrashDrop, CommentRow, EmptyPagePrompt, FormatBar, FormatButton, LibrarySidebar, PageRulerView (+18 more)

### Community 4 - "Community 4"
Cohesion: 0.05
Nodes (63): Foundation, DelimRun, EmphasisKind, bold, boldItalic, italic, ExtensionInlineNode, InlineNode (+55 more)

### Community 5 - "Community 5"
Cohesion: 0.09
Nodes (25): AppKit, NSFontTraitMask, NSTextCheckingResult, LineHeight, double, normal, relaxed, tight (+17 more)

### Community 6 - "Community 6"
Cohesion: 0.14
Nodes (13): NSScrollView, NSTextContentStorage, NSTextLayoutManager, NSTextRange, NSTextStorageDelegate, Coordinator, ManuscriptScrollView, Context (+5 more)

### Community 7 - "Community 7"
Cohesion: 0.13
Nodes (20): Action, Content, Block, Fact, Facts, FilterField, GroupHeader, HighlightedText (+12 more)

### Community 8 - "Community 8"
Cohesion: 0.02
Nodes (99): Glyph, advances, alignCentre, alignEnd, alignJustify, alignStart, annotate, archive (+91 more)

### Community 9 - "Community 9"
Cohesion: 0.10
Nodes (29): Fuzzy, SearchDestination, document, entity, event, note, relationship, snapshot (+21 more)

### Community 10 - "Community 10"
Cohesion: 0.09
Nodes (31): FileManager, LocalizedError, DocumentEntry, LocalProjectRepository, MarkdownDocument, ProjectLoad, ProjectManifest, ProjectRepositoryError (+23 more)

### Community 11 - "Community 11"
Cohesion: 0.09
Nodes (11): DispatchSourceFileSystemObject, EditorCanvas, EditorStatusBar, JumpBar, Double, Never, Set, String (+3 more)

### Community 12 - "Community 12"
Cohesion: 0.07
Nodes (37): CGPoint, CGRect, CGSize, DropDelegate, NSItemProvider, ProposedViewSize, BinderDrag, BinderName (+29 more)

### Community 13 - "Community 13"
Cohesion: 0.12
Nodes (21): CaseIterable, Combine, Identifiable, Sendable, AppAppearance, dark, light, system (+13 more)

### Community 14 - "Community 14"
Cohesion: 0.07
Nodes (29): NSTrackingArea, NSView, BinderContextMenu, BinderMenu, BinderMenuEntry, destructive, item, separator (+21 more)

### Community 15 - "Community 15"
Cohesion: 0.20
Nodes (10): RelationshipKind, belongsTo, conceals, custom, family, knows, locatedIn, loves (+2 more)

### Community 16 - "Community 16"
Cohesion: 0.10
Nodes (8): Error, HistoryReason, ProjectSnapshotRecord, Int, String, Task, URL, WorkspaceError

### Community 17 - "Community 17"
Cohesion: 0.15
Nodes (19): Codable, NSTextAlignment, HighlightColour, amber, mint, rose, sky, PresentationBlock (+11 more)

### Community 18 - "Community 18"
Cohesion: 0.16
Nodes (19): QuietText, AppearanceRow, EntityDossier, EntityList, EntityRow, EventDetail, EventList, EventRow (+11 more)

### Community 19 - "Community 19"
Cohesion: 0.13
Nodes (19): Array, BinderItem, CodingKeys, children, group, id, kind, name (+11 more)

### Community 20 - "Community 20"
Cohesion: 0.25
Nodes (7): Entry, RecentProjects, Any, Bool, String, URL, UserDefaults

### Community 21 - "Community 21"
Cohesion: 0.11
Nodes (6): UUID, ManuscriptNavigator, SceneStrip, StoryDocument, StoryProject, UUID

### Community 22 - "Community 22"
Cohesion: 0.07
Nodes (44): AnyShapeStyle, CodingKey, CodingKeys, answer, id, isAbandoned, kind, question (+36 more)

### Community 23 - "Community 23"
Cohesion: 0.09
Nodes (23): CodingKeys, advancesThreadIDs, archivedDocuments, binder, chapter, documents, id, intention (+15 more)

### Community 24 - "Community 24"
Cohesion: 0.16
Nodes (18): EventCertainty, approximate, disputed, stated, unplaced, FindingDisposition, dismissed, intentional (+10 more)

### Community 25 - "Community 25"
Cohesion: 0.20
Nodes (9): UUID, TrashedPayload, document, entity, event, group, note, relationship (+1 more)

### Community 26 - "Community 26"
Cohesion: 0.06
Nodes (37): Animation, NSFontDescriptor, ColorScheme, Chrome, Color, Icon, IconView, Measure (+29 more)

### Community 28 - ".send"
Cohesion: 0.13
Nodes (20): Hashable, Chapter, DocumentKind, note, scene, DocumentStatus, done, draft (+12 more)

### Community 29 - "PersistenceState"
Cohesion: 0.13
Nodes (14): ExternalChange, LibraryItem, history, manuscript, notes, story, timeline, trash (+6 more)

### Community 30 - "StartScreen"
Cohesion: 0.43
Nodes (6): Chip, EmptyStateView, Void, IconSource, glyph, system

### Community 31 - "View"
Cohesion: 0.06
Nodes (38): Comparable, Int, ContinuityChecker, FindingEvidence, FindingKind, aliasCollision, chronologyInversion, emptyScene (+30 more)

### Community 32 - "EntityKind"
Cohesion: 0.15
Nodes (11): Layout, FlowLayout, HoverRow, StatusDot, Strip, CGFloat, ThreadLinks, GlyphIcon (+3 more)

### Community 33 - "Community 33"
Cohesion: 0.16
Nodes (13): EditorCommand, alignment, blockquote, face, format, heading, highlight, list (+5 more)

### Community 34 - "Community 34"
Cohesion: 0.12
Nodes (12): NSTextContainer, ManuscriptTextView, Any, Bool, Int, NSCoder, NSEvent, NSMenu (+4 more)

### Community 35 - "Community 35"
Cohesion: 0.10
Nodes (30): CryptoKit, ExportError, renderFailed, usePDFWriter, ExportFormat, docx, markdown, pdf (+22 more)

### Community 36 - "Overlays.swift"
Cohesion: 0.05
Nodes (41): Actions, EnvironmentKey, NavigationSplitViewVisibility, NSViewRepresentable, NSWindow, CommandPalette, Coordinator, KeyMonitor (+33 more)

### Community 37 - "FindingSeverity"
Cohesion: 0.15
Nodes (12): ObservableObject, AppSettings, Any, Bool, ColorScheme, Double, UserDefaults, CompositionSettings (+4 more)

### Community 38 - "FindingKind"
Cohesion: 0.24
Nodes (9): Date, StoryComment, Bool, Double, Int, NSString, String, UUID (+1 more)

### Community 39 - "ThreadKind"
Cohesion: 0.11
Nodes (14): Equatable, NSMenuItem, NSTextFinder, NSTextStorageEditActions, EditorCommandRequest, EditorSelection, ManuscriptEditor, NSEdgeInsets (+6 more)

### Community 40 - "WorkspaceView.swift"
Cohesion: 0.29
Nodes (7): EntityKind, character, location, object, organization, symbol, theme

### Community 41 - "AppCommands"
Cohesion: 0.19
Nodes (9): NSSelectionAffinity, NSValue, MarkerRun, Markers, MarkerSide, closing, opening, Int (+1 more)

### Community 42 - "Date"
Cohesion: 0.40
Nodes (3): SnapshotDetail, SnapshotList, String

### Community 45 - "WorkspaceView"
Cohesion: 0.33
Nodes (4): App, Scene, StoryLoomApp, SwiftUI

### Community 46 - "Community 46"
Cohesion: 0.09
Nodes (23): CodingKeys, aliases, certainty, chronologyLabel, comments, dispositions, entities, events (+15 more)

### Community 48 - "ProseStyler.swift"
Cohesion: 0.22
Nodes (8): RecentRow, StartAction, StartScreen, String, Int, NSSize, String, Void

### Community 50 - "AppDelegate"
Cohesion: 0.22
Nodes (7): NSApplication, NSApplicationDelegate, NSObject, AppDelegate, Bool, Notification, URL

### Community 51 - "FlowLayout"
Cohesion: 0.53
Nodes (4): MarkdownInput, Int, NSString, String

### Community 53 - "AppCommands"
Cohesion: 0.25
Nodes (6): Commands, AppCommands, StoryLoomCommand, export, palette, search

### Community 54 - "Date"
Cohesion: 0.38
Nodes (4): ISO8601DateFormatter, JSONDecoder, JSONEncoder, Timestamp

### Community 57 - "Community 57"
Cohesion: 0.16
Nodes (10): NSTextView, NSTextViewDelegate, Coordinator, GrowingText, QuietTextView, Context, Coordinator, Notification (+2 more)

### Community 58 - "TrashViews.swift"
Cohesion: 0.12
Nodes (8): ThreadList, String, TrashedItem, TrashDetail, TrashList, TrashRow, threads, Bool

### Community 59 - ".placement"
Cohesion: 0.50
Nodes (3): FieldRow, InspectorPane, Value

### Community 76 - "Community 76"
Cohesion: 0.13
Nodes (20): ArraySlice, BlockParser, BufferDiff, MarkdownBlock, MarkdownBlockKind, blank, blockLatex, blockquote (+12 more)

### Community 126 - "Community 126"
Cohesion: 0.40
Nodes (4): Modifications, SwiftMarkdownEngine, Third-party code, What was taken, and what was not

## Knowledge Gaps
- **379 isolated node(s):** `continuous`, `page`, `light`, `dark`, `system` (+374 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `WorkspaceModel` connect `Community 11` to `Community 0`, `Community 3`, `Community 10`, `Community 12`, `Community 16`, `Community 17`, `Community 18`, `Community 19`, `Community 20`, `Community 21`, `Community 22`, `Community 24`, `PersistenceState`, `View`, `EntityKind`, `Community 35`, `Overlays.swift`, `FindingSeverity`, `FindingKind`, `ThreadKind`, `Date`, `WorkspaceView`, `ProseStyler.swift`, `AppDelegate`, `AppCommands`, `.document`, `TrashViews.swift`, `.placement`?**
  _High betweenness centrality (0.203) - this node is a cross-community bridge._
- **Why does `NSRange` connect `Community 4` to `Community 1`, `Community 2`, `Community 35`, `Community 34`, `Community 5`, `Community 6`, `ThreadKind`, `FindingKind`, `AppCommands`, `Community 9`, `Community 11`, `Community 76`, `Community 17`, `Community 18`, `FlowLayout`, `View`?**
  _High betweenness centrality (0.172) - this node is a cross-community bridge._
- **Why does `Glyph` connect `Community 8` to `EntityKind`, `Community 2`, `Community 35`, `Community 3`, `Overlays.swift`, `WorkspaceView.swift`, `Community 13`, `Community 15`, `ProseStyler.swift`, `Community 17`, `PersistenceState`, `Community 19`, `Community 22`, `Community 24`, `Community 26`, `.send`, `.menuImage`, `StartScreen`?**
  _High betweenness centrality (0.154) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `WorkspaceModel` (e.g. with `.appearances()` and `EditorSelection`) actually correct?**
  _`WorkspaceModel` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `NSRange` (e.g. with `.inlineAttributed()` and `.prose()`) actually correct?**
  _`NSRange` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 28 inferred relationships involving `StoryProject` (e.g. with `.adopt()` and `.archive()`) actually correct?**
  _`StoryProject` has 28 INFERRED edges - model-reasoned connections that need verification._
- **What connects `continuous`, `page`, `light` to the rest of the system?**
  _379 weakly-connected nodes found - possible documentation gaps or missing edges._
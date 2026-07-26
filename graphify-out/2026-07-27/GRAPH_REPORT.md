# Graph Report - StoryOS  (2026-07-27)

## Corpus Check
- 143 files · ~103,121 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1641 nodes · 4520 edges · 67 communities (61 shown, 6 thin omitted)
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
- Community 43
- CodingKeys
- WorkspaceView
- Community 46
- WorkspaceView.swift
- ProseStyler.swift
- .edit
- AppDelegate
- FlowLayout
- Bool
- AppCommands
- Date
- PersistenceState
- Community 57
- TrashViews.swift
- .placement
- .init
- .menuImage
- Community 76
- Community 125
- Community 126
- Community 130
- Community 133

## God Nodes (most connected - your core abstractions)
1. `WorkspaceModel` - 207 edges
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

## Communities (67 total, 6 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.08
Nodes (11): DispatchSourceFileSystemObject, IndexSet, UUID, ManuscriptNavigator, Bool, Double, Int, Never (+3 more)

### Community 1 - "Community 1"
Cohesion: 0.20
Nodes (8): Character, HTMLToMarkdownConverter, Node, String, Bool, Int, Set, String

### Community 2 - "Community 2"
Cohesion: 0.14
Nodes (18): InlineFormat, emphasis, highlight, strikethrough, strong, InlineMarkup, MarkerRun, Markers (+10 more)

### Community 3 - "Community 3"
Cohesion: 0.12
Nodes (23): BarDivider, EditorCanvas, EditorStatusBar, EmptyPagePrompt, FormatBar, FormatButton, JumpBar, LibrarySidebar (+15 more)

### Community 4 - "Community 4"
Cohesion: 0.09
Nodes (33): DelimRun, EmphasisKind, bold, boldItalic, italic, ExtensionInlineNode, InlineNode, code (+25 more)

### Community 5 - "Community 5"
Cohesion: 0.16
Nodes (14): NSFontTraitMask, ProseStyle, ProseStyler, Any, Bool, CGFloat, ColorScheme, NSAttributedString (+6 more)

### Community 6 - "Community 6"
Cohesion: 0.11
Nodes (20): NSScrollView, NSTextContentStorage, NSTextLayoutManager, NSTextRange, NSTextStorageDelegate, NSTextStorageEditActions, Coordinator, EditorSelection (+12 more)

### Community 7 - "Community 7"
Cohesion: 0.13
Nodes (20): Action, Content, Block, Fact, Facts, FilterField, GroupHeader, HighlightedText (+12 more)

### Community 8 - "Community 8"
Cohesion: 0.02
Nodes (99): Glyph, advances, alignCentre, alignEnd, alignJustify, alignStart, annotate, archive (+91 more)

### Community 9 - "Community 9"
Cohesion: 0.12
Nodes (26): Fuzzy, SearchDestination, document, entity, event, note, relationship, snapshot (+18 more)

### Community 10 - "Community 10"
Cohesion: 0.09
Nodes (30): FileManager, DocumentEntry, LocalProjectRepository, MarkdownDocument, ProjectLoad, ProjectManifest, ProjectRepositoryError, identityMismatch (+22 more)

### Community 11 - "Community 11"
Cohesion: 0.13
Nodes (4): Error, notes, String, Void

### Community 12 - "Community 12"
Cohesion: 0.07
Nodes (37): CGPoint, CGRect, CGSize, DropDelegate, NSItemProvider, ProposedViewSize, BinderDrag, BinderName (+29 more)

### Community 13 - "Community 13"
Cohesion: 0.11
Nodes (22): CaseIterable, Sendable, PageViewMode, continuous, page, HighlightColour, amber, mint (+14 more)

### Community 14 - "Community 14"
Cohesion: 0.07
Nodes (29): NSTrackingArea, NSView, BinderContextMenu, BinderMenu, BinderMenuEntry, destructive, item, separator (+21 more)

### Community 15 - "Community 15"
Cohesion: 0.20
Nodes (10): RelationshipKind, belongsTo, conceals, custom, family, knows, locatedIn, loves (+2 more)

### Community 16 - "Community 16"
Cohesion: 0.11
Nodes (10): SnapshotDetail, String, HistoryReason, ProjectSnapshotRecord, Int, String, ExternalChange, Task (+2 more)

### Community 17 - "Community 17"
Cohesion: 0.19
Nodes (13): NSTextAlignment, PresentationBlock, PresentationLayer, PresentationRun, Bool, Double, Int, Void (+5 more)

### Community 18 - "Community 18"
Cohesion: 0.12
Nodes (24): AnyShapeStyle, QuietText, Strip, AppearanceRow, EntityDossier, EntityList, EntityRow, EventDetail (+16 more)

### Community 19 - "Community 19"
Cohesion: 0.15
Nodes (16): Array, BinderItem, GroupKind, chapter, folder, part, volume, Kind (+8 more)

### Community 20 - "Community 20"
Cohesion: 0.25
Nodes (7): Entry, RecentProjects, Any, Bool, String, URL, UserDefaults

### Community 21 - "Community 21"
Cohesion: 0.15
Nodes (4): StoryProject, String, TrashedItem, UUID

### Community 22 - "Community 22"
Cohesion: 0.07
Nodes (38): CodingKeys, answer, id, isAbandoned, kind, question, Bool, Decoder (+30 more)

### Community 23 - "Community 23"
Cohesion: 0.09
Nodes (23): CodingKeys, advancesThreadIDs, archivedDocuments, binder, chapter, documents, id, intention (+15 more)

### Community 24 - "Community 24"
Cohesion: 0.15
Nodes (19): Codable, EventCertainty, approximate, disputed, stated, unplaced, FindingDisposition, dismissed (+11 more)

### Community 25 - "Community 25"
Cohesion: 0.20
Nodes (9): UUID, TrashedPayload, document, entity, event, group, note, relationship (+1 more)

### Community 26 - "Community 26"
Cohesion: 0.21
Nodes (11): ColorScheme, Color, NSColor, Palette, ReadingTheme, ink, night, paper (+3 more)

### Community 28 - ".send"
Cohesion: 0.14
Nodes (23): Hashable, Identifiable, Chapter, DocumentKind, note, scene, DocumentStatus, done (+15 more)

### Community 29 - "PersistenceState"
Cohesion: 0.17
Nodes (9): ThreadLinks, StoryThread, LibraryItem, history, manuscript, story, threads, timeline (+1 more)

### Community 30 - "StartScreen"
Cohesion: 0.19
Nodes (14): GlyphIcon, Icon, IconSource, glyph, system, IconView, Measure, comfortable (+6 more)

### Community 31 - "View"
Cohesion: 0.06
Nodes (41): Comparable, Int, ContinuityChecker, FindingEvidence, FindingKind, aliasCollision, chronologyInversion, emptyScene (+33 more)

### Community 32 - "EntityKind"
Cohesion: 0.16
Nodes (11): Layout, Chip, EmptyStateView, FlowLayout, HoverRow, StatusDot, CGFloat, Void (+3 more)

### Community 33 - "Community 33"
Cohesion: 0.09
Nodes (20): NSMenuItem, NSTextFinder, EditorCommand, alignment, blockquote, face, format, heading (+12 more)

### Community 34 - "Community 34"
Cohesion: 0.10
Nodes (13): NSSelectionAffinity, NSTextContainer, NSValue, ManuscriptTextView, Any, Bool, Int, NSCoder (+5 more)

### Community 35 - "Community 35"
Cohesion: 0.09
Nodes (32): CryptoKit, LocalizedError, Any, ExportError, renderFailed, usePDFWriter, ExportFormat, docx (+24 more)

### Community 36 - "Overlays.swift"
Cohesion: 0.16
Nodes (16): CommandPalette, PaletteAction, PaletteEntry, PaletteRow, SearchHelp, SearchPanel, SearchRow, Bool (+8 more)

### Community 37 - "FindingSeverity"
Cohesion: 0.13
Nodes (16): ObservableObject, AppAppearance, dark, light, system, AppSettings, Bool, ColorScheme (+8 more)

### Community 38 - "FindingKind"
Cohesion: 0.23
Nodes (8): StoryComment, Bool, Double, Int, NSString, String, UUID, TextAnchor

### Community 39 - "ThreadKind"
Cohesion: 0.22
Nodes (8): NSViewRepresentable, Coordinator, KeyMonitor, Any, Context, Coordinator, Int, NSView

### Community 40 - "WorkspaceView.swift"
Cohesion: 0.29
Nodes (7): EntityKind, character, location, object, organization, symbol, theme

### Community 41 - "AppCommands"
Cohesion: 0.14
Nodes (11): Actions, EnvironmentKey, NavigationSplitViewVisibility, Banner, EnvironmentValues, Notification.Name, ProseStyleKey, Binding (+3 more)

### Community 42 - "Date"
Cohesion: 0.19
Nodes (11): NSFontDescriptor, Chrome, ProseFace, baskerville, georgia, iowan, mono, newYork (+3 more)

### Community 43 - "Community 43"
Cohesion: 0.30
Nodes (6): NSWindow, Coordinator, Bool, Context, NSView, WindowConfigurator

### Community 44 - "CodingKeys"
Cohesion: 0.24
Nodes (6): AppKit, NSTextCheckingResult, NSAttributedString.Key, NSRegularExpression, Patterns, String

### Community 45 - "WorkspaceView"
Cohesion: 0.22
Nodes (6): App, Combine, Scene, SnapshotList, StoryLoomApp, SwiftUI

### Community 46 - "Community 46"
Cohesion: 0.09
Nodes (23): CodingKeys, aliases, certainty, chronologyLabel, comments, dispositions, entities, events (+15 more)

### Community 47 - "WorkspaceView.swift"
Cohesion: 0.29
Nodes (7): CodingKey, CodingKeys, children, group, id, kind, name

### Community 48 - "ProseStyler.swift"
Cohesion: 0.22
Nodes (8): RecentRow, StartAction, StartScreen, String, Int, NSSize, String, Void

### Community 49 - ".edit"
Cohesion: 0.29
Nodes (4): Animation, Motion, Bool, View

### Community 50 - "AppDelegate"
Cohesion: 0.22
Nodes (7): NSApplication, NSApplicationDelegate, NSObject, AppDelegate, Bool, Notification, URL

### Community 51 - "FlowLayout"
Cohesion: 0.53
Nodes (4): MarkdownInput, Int, NSString, String

### Community 52 - "Bool"
Cohesion: 0.29
Nodes (6): BinderTrashDrop, CommentRow, StatusOption, Bool, DropInfo, DropProposal

### Community 53 - "AppCommands"
Cohesion: 0.25
Nodes (6): Commands, AppCommands, StoryLoomCommand, export, palette, search

### Community 54 - "Date"
Cohesion: 0.36
Nodes (5): ISO8601DateFormatter, Date, JSONDecoder, JSONEncoder, Timestamp

### Community 56 - "PersistenceState"
Cohesion: 0.33
Nodes (6): PersistenceState, failed, loading, saved, saving, unsaved

### Community 57 - "Community 57"
Cohesion: 0.16
Nodes (10): NSTextView, NSTextViewDelegate, Coordinator, GrowingText, QuietTextView, Context, Coordinator, Notification (+2 more)

### Community 58 - "TrashViews.swift"
Cohesion: 0.50
Nodes (3): TrashDetail, TrashList, TrashRow

### Community 59 - ".placement"
Cohesion: 0.50
Nodes (3): FieldRow, InspectorPane, Value

### Community 76 - "Community 76"
Cohesion: 0.06
Nodes (50): ArraySlice, Equatable, Foundation, BlockParser, BufferDiff, MarkdownBlock, MarkdownBlockKind, blank (+42 more)

### Community 126 - "Community 126"
Cohesion: 0.40
Nodes (4): Modifications, SwiftMarkdownEngine, Third-party code, What was taken, and what was not

## Knowledge Gaps
- **379 isolated node(s):** `continuous`, `page`, `light`, `dark`, `system` (+374 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `WorkspaceModel` connect `Community 0` to `Community 3`, `Community 6`, `Community 10`, `Community 11`, `Community 12`, `Community 16`, `Community 17`, `Community 18`, `Community 19`, `Community 20`, `Community 21`, `Community 22`, `Community 24`, `.send`, `PersistenceState`, `View`, `EntityKind`, `Community 33`, `Community 35`, `Overlays.swift`, `FindingSeverity`, `FindingKind`, `AppCommands`, `WorkspaceView`, `ProseStyler.swift`, `AppDelegate`, `Bool`, `AppCommands`, `Date`, `.document`, `PersistenceState`, `TrashViews.swift`, `.placement`?**
  _High betweenness centrality (0.204) - this node is a cross-community bridge._
- **Why does `NSRange` connect `Community 2` to `Community 0`, `Community 33`, `Community 34`, `Community 35`, `Community 1`, `Community 4`, `Community 6`, `Community 5`, `FindingKind`, `Community 9`, `Community 76`, `CodingKeys`, `Community 17`, `Community 18`, `FlowLayout`, `View`?**
  _High betweenness centrality (0.172) - this node is a cross-community bridge._
- **Why does `Glyph` connect `Community 8` to `Community 2`, `Community 3`, `Community 13`, `Community 15`, `Community 17`, `Community 18`, `Community 19`, `Community 22`, `Community 24`, `.send`, `StartScreen`, `EntityKind`, `Community 35`, `FindingSeverity`, `WorkspaceView.swift`, `AppCommands`, `ProseStyler.swift`, `PersistenceState`, `.menuImage`?**
  _High betweenness centrality (0.153) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `WorkspaceModel` (e.g. with `.appearances()` and `EditorSelection`) actually correct?**
  _`WorkspaceModel` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `NSRange` (e.g. with `.inlineAttributed()` and `.prose()`) actually correct?**
  _`NSRange` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 28 inferred relationships involving `StoryProject` (e.g. with `.adopt()` and `.archive()`) actually correct?**
  _`StoryProject` has 28 INFERRED edges - model-reasoned connections that need verification._
- **What connects `continuous`, `page`, `light` to the rest of the system?**
  _379 weakly-connected nodes found - possible documentation gaps or missing edges._
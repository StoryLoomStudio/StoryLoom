# Graph Report - StoryOS  (2026-07-25)

## Corpus Check
- 34 files · ~61,695 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1038 nodes · 2913 edges · 57 communities (47 shown, 10 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 146 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- History & Document Navigation
- Project Storage & Snapshots
- Continuity & Conflict Detection
- AppKit Text View Delegate
- Typography & Palette System
- Export Engine & PDF Generator
- Story Threads & Character Arcs
- Story Threads & Character Arcs
- AppKit Text View Delegate
- Markdown Inline Formatting Engine
- Document Model & Chapters
- Manuscript Views & Format Toolbar
- Typography & Palette System
- Typography & Palette System
- CaseIterable Module
- Equatable Module
- NSMenu Module
- App Module
- SettingsView.swift Module
- CodingKeys Module
- Story Threads & Character Arcs
- Codable Module
- Content Module
- RelationshipKind Module
- Manuscript Layout & Scroll Manager
- AppKit Text View Delegate
- AppSettings Module
- Actions Module
- AppKit Module
- .init() Module
- CGRect Module
- NavigationSplitViewVisibility Module
- CodingKey Module
- History & Document Navigation
- PersistenceState Module
- Context Module
- FieldRow Module
- Combine Module
- icon_1024 Module
- icon_128 Module
- icon_16 Module
- icon_256 Module
- icon_32 Module
- icon_512 Module
- icon_64 Module
- StoryEntity
- TextAnchor
- FindingTarget
- AppDelegate
- ProjectRepositoryError
- .apply
- FindingSeverity
- .comment
- Section
- graphify.md
- graphify.md

## God Nodes (most connected - your core abstractions)
1. `String` - 204 edges
2. `WorkspaceModel` - 160 edges
3. `StoryProject` - 74 edges
4. `NSRange` - 63 edges
5. `StoryDocument` - 62 edges
6. `Coordinator` - 38 edges
7. `StoryEntity` - 36 edges
8. `ProseStyle` - 33 edges
9. `StoryThread` - 31 edges
10. `AppSettings` - 30 edges

## Surprising Connections (you probably didn't know these)
- `ExportPanel` --calls--> `ExportProfile`  [INFERRED]
  StoryOS/Overlays.swift → StoryOS/ExportService.swift
- `WorkspaceModel` --calls--> `EditorSelection`  [INFERRED]
  StoryOS/WorkspaceModel.swift → StoryOS/ManuscriptEditor.swift
- `EnvironmentValues` --references--> `ProseStyle`  [EXTRACTED]
  StoryOS/WorkspaceView.swift → StoryOS/ProseStyler.swift
- `StoryloomApp` --calls--> `RecentProjects`  [INFERRED]
  StoryOS/StoryloomApp.swift → StoryOS/RecentProjects.swift
- `WorkspaceModel` --calls--> `StoryIndex`  [INFERRED]
  StoryOS/WorkspaceModel.swift → StoryOS/StoryBrain.swift

## Import Cycles
- None detected.

## Communities (57 total, 10 thin omitted)

### Community 0 - "History & Document Navigation"
Cohesion: 0.13
Nodes (6): EditorCommandRequest, threads, Never, NSTextAlignment, WorkspaceModel, UndoManager

### Community 1 - "Project Storage & Snapshots"
Cohesion: 0.21
Nodes (6): FileManager, LocalProjectRepository, malformedSnapshot, Bool, Data, URL

### Community 2 - "Continuity & Conflict Detection"
Cohesion: 0.24
Nodes (7): Mention, StoryBrain, StoryIndex, Bool, NSString, unichar, UUID

### Community 3 - "AppKit Text View Delegate"
Cohesion: 0.06
Nodes (38): Actions, EnvironmentKey, NavigationSplitViewVisibility, NSViewRepresentable, CommandPalette, Coordinator, ExportPanel, KeyMonitor (+30 more)

### Community 4 - "Typography & Palette System"
Cohesion: 0.05
Nodes (41): Animation, Edge, NSFontDescriptor, WarningRow, Chrome, Color, Measure, comfortable (+33 more)

### Community 5 - "Export Engine & PDF Generator"
Cohesion: 0.07
Nodes (41): CaseIterable, CryptoKit, LocalizedError, Sendable, PageViewMode, continuous, page, ExportError (+33 more)

### Community 6 - "Story Threads & Character Arcs"
Cohesion: 0.06
Nodes (58): AnyShapeStyle, Identifiable, BarDivider, CommentRow, EditorCanvas, EditorStatusBar, EmptyPagePrompt, FormatBar (+50 more)

### Community 7 - "Story Threads & Character Arcs"
Cohesion: 0.11
Nodes (25): Fuzzy, SearchDestination, document, entity, event, note, relationship, snapshot (+17 more)

### Community 8 - "AppKit Text View Delegate"
Cohesion: 0.10
Nodes (22): Equatable, NSLayoutManagerDelegate, NSScrollView, NSTextFinder, NSTextStorageDelegate, Coordinator, EditorSelection, ManuscriptEditor (+14 more)

### Community 9 - "Markdown Inline Formatting Engine"
Cohesion: 0.15
Nodes (15): InlineFormat, emphasis, strong, InlineMarkup, MarkerRun, Markers, MarkerSide, closing (+7 more)

### Community 10 - "Document Model & Chapters"
Cohesion: 0.12
Nodes (22): Codable, Hashable, FindingDisposition, dismissed, intentional, Chapter, DocumentKind, note (+14 more)

### Community 11 - "Manuscript Views & Format Toolbar"
Cohesion: 0.12
Nodes (14): NSSize, NSTextView, NSTextViewDelegate, Coordinator, GroupHeader, GrowingText, QuietTextView, Bool (+6 more)

### Community 12 - "Typography & Palette System"
Cohesion: 0.12
Nodes (18): Action, Content, Block, Chip, EmptyStateView, Fact, Facts, FilterField (+10 more)

### Community 13 - "Typography & Palette System"
Cohesion: 0.11
Nodes (20): NSFontTraitMask, NSTextCheckingResult, LineHeight, double, normal, relaxed, tight, NSAttributedString.Key (+12 more)

### Community 14 - "CaseIterable Module"
Cohesion: 0.33
Nodes (5): AppAppearance, dark, light, system, ColorScheme

### Community 15 - "Equatable Module"
Cohesion: 0.24
Nodes (8): EditorCommand, alignment, blockquote, format, highlight, sceneBreak, NSTextAlignment, Task

### Community 16 - "NSMenu Module"
Cohesion: 0.15
Nodes (10): NSCoder, NSMenu, NSPoint, NSRect, NSTextContainer, ManuscriptTextView, Any, NSEvent (+2 more)

### Community 17 - "App Module"
Cohesion: 0.29
Nodes (6): Entry, RecentProjects, Any, Bool, URL, UserDefaults

### Community 18 - "SettingsView.swift Module"
Cohesion: 0.20
Nodes (11): AppearanceRow, EntityDossier, EntityList, EntityRow, EventDetail, EventList, MentionGroup, NoteEditor (+3 more)

### Community 19 - "CodingKeys Module"
Cohesion: 0.09
Nodes (22): CodingKeys, aliases, certainty, chronologyLabel, comments, dispositions, entities, events (+14 more)

### Community 20 - "Story Threads & Character Arcs"
Cohesion: 0.10
Nodes (21): CodingKeys, advancesThreadIDs, archivedDocuments, chapter, documents, id, intention, kind (+13 more)

### Community 21 - "Codable Module"
Cohesion: 0.15
Nodes (10): EventCertainty, approximate, disputed, stated, unplaced, StoryEvent, Decoder, EventRow (+2 more)

### Community 22 - "Content Module"
Cohesion: 0.33
Nodes (5): Font, HighlightedText, Range, InspectorPane, Text

### Community 23 - "RelationshipKind Module"
Cohesion: 0.14
Nodes (13): RelationshipKind, belongsTo, conceals, custom, family, knows, locatedIn, loves (+5 more)

### Community 24 - "Manuscript Layout & Scroll Manager"
Cohesion: 0.11
Nodes (16): CGGlyph, Foundation, NSLayoutManager, NSSelectionAffinity, NSTextStorageEditActions, NSValue, ProseLayoutManager, Bool (+8 more)

### Community 26 - "AppKit Text View Delegate"
Cohesion: 0.18
Nodes (8): Commands, NSApplication, AppCommands, Bool, StoryloomCommand, export, palette, search

### Community 27 - "AppSettings Module"
Cohesion: 0.16
Nodes (12): ObservableObject, AppSettings, Any, Bool, Double, UserDefaults, FindingSelection, CompositionSettings (+4 more)

### Community 28 - "Actions Module"
Cohesion: 0.18
Nodes (9): DocumentEntry, MarkdownDocument, ProjectManifest, Int, JSONDecoder, JSONEncoder, Set, UUID (+1 more)

### Community 29 - "AppKit Module"
Cohesion: 0.20
Nodes (6): HistoryReason, ProjectSnapshotRecord, Int, Task, URL, WorkspaceError

### Community 30 - ".init() Module"
Cohesion: 0.16
Nodes (7): StoryMetadata, StoryNote, Int, Date, NoteList, StoryComment, UUID

### Community 31 - "CGRect Module"
Cohesion: 0.36
Nodes (6): CGRect, CGSize, Layout, ProposedViewSize, FlowLayout, Subviews

### Community 32 - "NavigationSplitViewVisibility Module"
Cohesion: 0.31
Nodes (6): ContinuityChecker, document, entity, StoryFinding, FindingDetail, StoryProject

### Community 33 - "CodingKey Module"
Cohesion: 0.29
Nodes (7): CodingKey, CodingKeys, answer, id, isAbandoned, kind, question

### Community 34 - "History & Document Navigation"
Cohesion: 0.25
Nodes (7): LibraryItem, history, manuscript, notes, review, story, timeline

### Community 35 - "PersistenceState Module"
Cohesion: 0.17
Nodes (5): IndexSet, ManuscriptNavigator, Bool, Int, Void

### Community 36 - "Context Module"
Cohesion: 0.14
Nodes (14): FindingKind, aliasCollision, chronologyInversion, emptyScene, eventWithoutScene, orphanedComment, participantNotNamed, payoffBeforePromise (+6 more)

### Community 37 - "FieldRow Module"
Cohesion: 0.15
Nodes (7): Error, FieldRow, QuietField, SectionLabel, String, SnapshotDetail, Value

### Community 38 - "Combine Module"
Cohesion: 0.47
Nodes (3): AppKit, Combine, SwiftUI

### Community 46 - "StoryEntity"
Cohesion: 0.13
Nodes (10): EntityKind, character, location, object, organization, symbol, theme, StoryEntity (+2 more)

### Community 47 - "TextAnchor"
Cohesion: 0.27
Nodes (5): Bool, Double, Int, NSString, TextAnchor

### Community 48 - "FindingTarget"
Cohesion: 0.18
Nodes (10): FindingEvidence, FindingTarget, comment, event, thread, UUID, EvidenceRow, FindingList (+2 more)

### Community 49 - "AppDelegate"
Cohesion: 0.20
Nodes (7): App, NSApplicationDelegate, NSObject, Scene, AppDelegate, StoryloomApp, Notification

### Community 50 - "ProjectRepositoryError"
Cohesion: 0.20
Nodes (10): ProjectRepositoryError, identityMismatch, invalidDocumentPath, malformedDocument, malformedManifest, malformedStoryMetadata, missingDocument, missingManifest (+2 more)

### Community 51 - ".apply"
Cohesion: 0.32
Nodes (4): ISO8601DateFormatter, JSONDecoder, JSONEncoder, Timestamp

### Community 52 - "FindingSeverity"
Cohesion: 0.33
Nodes (6): Comparable, Int, FindingSeverity, caution, conflict, question

### Community 55 - "Section"
Cohesion: 0.67
Nodes (3): Section, archived, documents

## Knowledge Gaps
- **186 isolated node(s):** `continuous`, `page`, `light`, `dark`, `system` (+181 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **10 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `String` connect `FieldRow Module` to `History & Document Navigation`, `Project Storage & Snapshots`, `Continuity & Conflict Detection`, `AppKit Text View Delegate`, `Typography & Palette System`, `Export Engine & PDF Generator`, `Story Threads & Character Arcs`, `Story Threads & Character Arcs`, `AppKit Text View Delegate`, `Markdown Inline Formatting Engine`, `Document Model & Chapters`, `Manuscript Views & Format Toolbar`, `Typography & Palette System`, `Typography & Palette System`, `CaseIterable Module`, `NSMenu Module`, `App Module`, `SettingsView.swift Module`, `CodingKeys Module`, `Story Threads & Character Arcs`, `Codable Module`, `Content Module`, `RelationshipKind Module`, `Manuscript Layout & Scroll Manager`, `AppSettings Module`, `Actions Module`, `AppKit Module`, `.init() Module`, `NavigationSplitViewVisibility Module`, `CodingKey Module`, `History & Document Navigation`, `PersistenceState Module`, `Context Module`, `StoryEntity`, `TextAnchor`, `FindingTarget`, `ProjectRepositoryError`, `.apply`, `FindingSeverity`, `.comment`, `.document`?**
  _High betweenness centrality (0.525) - this node is a cross-community bridge._
- **Why does `WorkspaceModel` connect `History & Document Navigation` to `Project Storage & Snapshots`, `Continuity & Conflict Detection`, `AppKit Text View Delegate`, `Typography & Palette System`, `Export Engine & PDF Generator`, `Story Threads & Character Arcs`, `Story Threads & Character Arcs`, `AppKit Text View Delegate`, `Document Model & Chapters`, `App Module`, `SettingsView.swift Module`, `Codable Module`, `Content Module`, `RelationshipKind Module`, `Manuscript Layout & Scroll Manager`, `AppKit Text View Delegate`, `AppSettings Module`, `Actions Module`, `AppKit Module`, `.init() Module`, `NavigationSplitViewVisibility Module`, `History & Document Navigation`, `PersistenceState Module`, `FieldRow Module`, `Combine Module`, `StoryEntity`, `FindingTarget`, `AppDelegate`, `.apply`, `.document`?**
  _High betweenness centrality (0.148) - this node is a cross-community bridge._
- **Why does `NSRange` connect `Manuscript Layout & Scroll Manager` to `Continuity & Conflict Detection`, `Export Engine & PDF Generator`, `FieldRow Module`, `Story Threads & Character Arcs`, `AppKit Text View Delegate`, `Markdown Inline Formatting Engine`, `Typography & Palette System`, `TextAnchor`, `FindingTarget`, `NSMenu Module`, `SettingsView.swift Module`?**
  _High betweenness centrality (0.074) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `String` (e.g. with `.blockquote()` and `.drawBackground()`) actually correct?**
  _`String` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `WorkspaceModel` (e.g. with `.appearances()` and `EditorSelection`) actually correct?**
  _`WorkspaceModel` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 19 inferred relationships involving `StoryProject` (e.g. with `.archive()` and `.canMove()`) actually correct?**
  _`StoryProject` has 19 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `NSRange` (e.g. with `.inlineAttributed()` and `.prose()`) actually correct?**
  _`NSRange` has 3 INFERRED edges - model-reasoned connections that need verification._
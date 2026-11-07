---
target: other editor UI/UX flaws and tiny inconsistencies
total_score: 29
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 1
target_identity: "file:/Users/vibrant/Desktop/Projects/StoryOS/StoryOS/StoryOS/ManuscriptViews.swift"
target_fingerprint: "sha256:3c311860e77ca7d538d84792c51c31ef543729276f054263b869f4fe2a64ffb7"
target_path: /Users/vibrant/Desktop/Projects/StoryOS/StoryOS/StoryOS/ManuscriptViews.swift
timestamp: 2026-11-07T21-22-25Z
slug: storyos-manuscriptviews-swift
---
Method: native macOS visual and source review. I inspected the running StoryLoom window and relevant SwiftUI/AppKit code; the web detector/overlay is not applicable to this native surface.

## Design health: 29/40 — good, with a few concrete workflow inconsistencies

| # | Heuristic | Score | Main observation |
|---|---|---:|---|
| 1 | Visibility of system status | 3 | Save/status cues are present, but project-goal progress stops at 100% even when the book is over target. |
| 2 | Match with the real world | 3 | The manuscript/scene vocabulary fits the writing task. |
| 3 | User control and freedom | 3 | Outline selection, undo, and reversible Trash are strong; filtered results can get out of sync. |
| 4 | Consistency and standards | 2 | Counts inherit the Mac’s Indian digit grouping despite the UK spelling preference. |
| 5 | Error prevention | 3 | Reversible deletion and draft editing reduce risk. |
| 6 | Recognition rather than recall | 3 | Navigation is visible, but long scene names are cut off without a hover reveal. |
| 7 | Flexibility and efficiency | 3 | Shortcuts exist; the outline filter’s scope is unclear. |
| 8 | Aesthetic and minimalist design | 3 | Clear, calm hierarchy; the outline gets dense in a long book. |
| 9 | Error recovery | 3 | Undo and Trash help, though the filter mismatch can look like a missing result. |
| 10 | Help and documentation | 3 | The guide exists; small controls still rely on tooltips or inference. |

## Design specificity verdict

StoryLoom feels authored for manuscript work: scenes, chapters, word counts, and the measured prose column are central rather than generic dashboard chrome. The biggest opportunity is to make the outline and its feedback trustworthy at book scale.

## What’s working

- The three-column library → outline → writing surface keeps “where am I?” and “what am I writing?” visible together.
- The scene outline carries status and word count compactly, which helps scanning a long manuscript.
- The editor’s focused typography and restrained formatting controls keep the prose dominant.

## Priority issues

1. **[P1] Filter logic and empty state disagree.** `ManuscriptViews.swift` considers title, body, chapter, and volume metadata when deciding whether matches exist; the displayed outline matches title/body and group names only. A query matching only chapter/volume metadata can pass the “there are results” check while producing no rows. Also, “Filter structure…” suggests the filter is structural even though it searches prose. Use one shared match/prune function and label the scope clearly.
2. **[P2] Over-target progress is misleading.** The current project has 104,767 words against a 90,000-word target, but the progress value is clamped to 1.0, so the bar/percentage say 100%; the target popover says zero remaining. Keep the bar capped, but show “16% over target” (or the actual excess) instead of implying the count stopped at the goal.
3. **[P2] Number grouping follows the Mac’s regional locale, not the UK writing preference.** The running app shows `1,04,767` in the project and goal counts; `.formatted()` is used without an explicit locale. If the intended workspace convention is UK English, use UK grouping (`104,767`) consistently or make number locale an explicit setting.
4. **[P2] Truncated outline titles have no visual reveal.** Long chapter/scene names end in ellipses in the outline; the row limits the name to one line with tail truncation but no help/tooltip. Add a hover reveal or a lightweight way to widen the outline so authors can distinguish similarly named scenes without opening each one.

## Cognitive load

Moderate: the screen’s three-pane structure and grouped toolbar are learnable, but the filter’s scope is ambiguous and clipped titles force extra context-switching.

## Persona red flags

- **Alex, power user:** filtering for a chapter/volume metadata value can yield a visually blank outline despite the app deciding matches exist; this interrupts fast navigation.
- **Jordan, first-timer:** “Filter structure…” does not communicate that prose content is searched, and a clipped title gives no hint that hovering could reveal the full name.
- **Sam, accessibility-dependent:** row names/status are exposed in combined accessibility labels, which helps. The project/count locale and goal feedback should also be spoken consistently with what the user sees.

## Minor observation

A one-word scene is announced as “1 words” in the scene row’s accessibility label; pluralize “word” for 1. (The visible count itself omits the unit.)

## Questions to consider

- Which should be fixed first: filter correctness, goal-overrun feedback, or UK number formatting?
- Should all four priority fixes be implemented, or should work start with the top two?

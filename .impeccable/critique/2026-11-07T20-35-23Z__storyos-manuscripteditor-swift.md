---
target: editor UI/UX
total_score: 27
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 4
timestamp: 2026-11-07T20-35-23Z
slug: storyos-manuscripteditor-swift
---
Method: dual-agent (A: /root/editor_design_review · B: /root/editor_technical_audit)

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|---|---:|---|
| 1 | Visibility of System Status | 2 | Normal autosave completion is not surfaced in the editor. |
| 2 | Match System / Real World | 4 | Writer concepts and native macOS conventions are well aligned. |
| 3 | User Control and Freedom | 3 | Undo, History, and Trash are strong; focus exit and presentation-layer edits are less clear. |
| 4 | Consistency and Standards | 3 | The workspace is consistent, but the dense icon-only formatter departs from its recognition-led language. |
| 5 | Error Prevention | 2 | Formatting shortcuts can edit manuscript text while metadata has keyboard focus. |
| 6 | Recognition Rather Than Recall | 2 | Formatting requires glyph/tooltip or shortcut recall. |
| 7 | Flexibility and Efficiency | 3 | Excellent native find and shortcuts, but their focus routing is unsafe. |
| 8 | Aesthetic and Minimalist Design | 4 | The prose-first composition is disciplined and distinct. |
| 9 | Error Recovery | 3 | History and conflict recovery are good; external replacement can misapply presentation spans. |
| 10 | Help and Documentation | 1 | Distinct StoryLoom concepts lack at-the-moment guidance. |
| **Total** | | **27/40** | **Solid specialist editor with material workflow and accessibility gaps** |

## Design Specificity Verdict

This is clearly authored for long-form fiction rather than a generic rich-text editor: the measured manuscript column, page-first canvas, thread/payoff language, scene intention, typewriter mode, and Markdown-preserving implementation form a coherent writing environment. Its weakness is not a lack of identity; it is that some advanced behavior is too implicit, and the compact formatting strip asks users to memorize a vocabulary the rest of the product avoids.

The native implementation is not a browser target, so no web overlay was applicable. The installed detector's native guidance says its web `detect.mjs` scan does not apply to Swift/AppKit; no misleading scan was run. A native build could not reach visual inspection because the environment's Swift macro-plugin server returned malformed responses.

## Overall Impression

The quiet core is unusually thoughtful and protects writers well. The immediate opportunity is to make authoring commands safe and clear: do not let keyboard focus cause invisible edits, reduce formatter density, and make persistence/accessibility state legible.

## What's Working

- The library, navigator, canvas, and optional inspector give prose visual priority while retaining project navigation.
- Native find, menus, undo, spell/grammar preferences, marker-aware selection, History, Trash, and conflict recovery respect established macOS writing behavior.
- The empty-scene invitation, measured column, focus mode, and typewriter option support a calm drafting rhythm instead of treating writing as dashboard work.

## Priority Issues

### [P1] Formatting shortcuts can alter the manuscript while a metadata field has focus

**Why it matters:** `Command-B`, `Command-I`, and related commands are enabled whenever a document exists, not when the editor is first responder. A writer editing the scene title or chapter can silently modify a retained text selection in the manuscript. That violates the principle of least surprise and can damage work without any visible cue.

**Fix:** Route Format commands through the responder chain or explicitly gate them on the manuscript editor being focused. Disable the menu items otherwise, and make commands target the current first responder only.

**Suggested command:** `$impeccable harden`

### [P1] The 32-point formatter is overloaded and non-adaptive

**Why it matters:** The fixed horizontal strip exposes about 18 mostly icon-only controls across six concepts. It increases recall burden, risks clipping in a narrow editor pane, and visually overstates rare formatting choices in a prose-first application.

**Fix:** Keep Bold, Italic, Comment, Paragraph Style, and view controls visible. Move alignment, local face/size, highlights, and uncommon block actions into labelled menus; add a width-based overflow variant.

**Suggested command:** `$impeccable distill`

### [P1] Primary reflection and comment fields lack explicit accessible names

**Why it matters:** The inspector's scene questions and comment body use a custom AppKit text view with a visually separate label/placeholder. VoiceOver can arrive at an ambiguous text area, making the app's narrative-planning workflow much harder to use.

**Fix:** Add an accessibility-label/title parameter to `QuietText`, set it on the wrapped `NSTextView`, and pass each question title or a contextual comment label.

**Suggested command:** `$impeccable audit`

### [P1] External replacements can misapply visual formatting and stale selection state

**Why it matters:** Snapshot or disk-driven replacement preserves the caret but does not re-anchor the presentation layer or report the new selection. Underline, colour highlight, face, size, or alignment can appear on unrelated prose; the format bar and comment command can then reflect an old selection.

**Fix:** Re-anchor presentation spans before restyling in `replaceTextPreservingCaret`, persist the corrected layer, and call `reportSelection()` after clamping the selection.

**Suggested command:** `$impeccable harden`

### [P2] Long documents can stutter while typing with comments or focus dimming

**Why it matters:** Each keystroke can clear full-document rendering attributes and resolve every comment anchor by scanning text. This puts document-scale work on the main thread precisely during drafting.

**Fix:** Cache resolved anchors, invalidate only edits that can affect them, and re-render affected/visible ranges rather than sweeping the whole document.

**Suggested command:** `$impeccable optimize`

## Persona Red Flags

**Power writer:** Familiar shortcuts are present, but the focus-routing defect makes them unsafe while editing the Jump Bar. The wide formatter forces lookup for headings, lists, alignment, and local typography when a shortcut is forgotten.

**First-time writer:** The calm empty page works, but Threads, payoff cues, scene questions, mentions, and comments are differentiators with no concise explanation at first use. A novice can remain in plain prose and miss the narrative system.

**Accessibility user:** Scene rows and format buttons have useful labels, but the highest-value open text fields do not have reliable programmatic names. Focus dimming may lower non-focused prose below comfortable contrast, and typewriter scrolling does not honor Reduce Motion.

## Minor Observations

- Surface a quiet autosave result in the status bar; errors and conflicts can remain interruptive.
- In a narrow pane, page mode retains margins/card dimensions that can clip; collapse the treatment or change modes below a viable width.
- Make Focus mode's escape route briefly explicit (for example, “Focus mode · Esc to exit”) before it settles into a quiet labelled control.
- Let high-stakes conflict banner copy wrap or expose details rather than truncating its reassurance.
- Clearly distinguish page-wide type settings from per-selection visual overrides, which are presentation-only.

## Questions to Consider

- Is per-selection face/size formatting a core writer need, or should it live under an explicitly advanced menu?
- Could the first empty scene introduce Threads and the inspector in one dismissible sentence rather than a full onboarding tour?

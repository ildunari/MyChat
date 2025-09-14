# Notes Feature — Architecture & Plan

Updated: 2025-09-14

## Goals
- Markdown-first notes with folders and quick actions.
- Reuse “movable containers” interaction from Home.
- Fast, local search across note titles and content.
- Editor with baseline formatting toolbar; preview via our existing Markdown renderer.
- Future‑proof for AI: line/character metrics, UTF‑16 addressing, search/replace, and unified‑diff editing.

## Data Model (SwiftData)
- `NoteFolder` — name, createdAt, `notes[]` (cascade delete)
- `Note` — title, content (markdown), createdAt, updatedAt, optional `folder`
- Editing/metrics helpers on `Note`:
  - `lineCount`, `characterCount`
  - `lineStartOffsetsUTF16()` → [Int]
  - `replaceUTF16Range(_:with:)`, `regexReplace(...)`

Schema updated in `MyChatApp.swift` to include `Note` and `NoteFolder` in the `Schema([...])`.

## UI Structure
- `NotesHomeView` — entry point with three sections inside movable containers:
  - Folders or Media (toggle via top‑left button)
  - Quick Actions (New Note, New Folder, Import, AI)
  - All Notes (list with search support)
- `NoteEditorView` — title field, formatting toolbar (Bold, Italic, H1, List, Code, Link), Edit/Preview switch.
- Shared `MovableSectionContainer` — extracted to match Home’s draggable/collapsible sections.

Navigation:
- From Home (top‑left “Notes” button) → `NotesHomeView` sheet.
- From Notes list/grid → `NoteEditorView` (push).

## Search
- `.searchable(text:)` on `NotesHomeView` filters by title + content (case‑insensitive).
- Future: consider an on‑save normalized content field for faster filtering or SQLite FTS.

## Markdown Rendering & Editing
- Preview uses our `renderMarkdownAttributed(_:)` pipeline (Down → AttributedString fallback).
- Editor: initial implementation uses SwiftUI `TextEditor` + simple formatting actions that insert markdown tokens.
- Prebuilt Editor Options (evaluated):
  - SwiftDown — SwiftUI Markdown editor with live preview; SPM package, actively maintained. Good fit when we’re ready to add a dependency. [GitHub] (qeude/SwiftDown). See install/usage in README. (SPM: File → Add Packages…) (Retrieved 2025‑09‑14). 
  - RichTextKit — Rich text editor bridging `UITextView`/`NSTextView`. Can be configured to emit Markdown (requires mapping); robust editor surface. (danielsaidi/RichTextKit). (Retrieved 2025‑09‑14).
  - MarkdownTextView — UIKit `UITextView` with Markdown syntax highlighting; older but usable for manual bridging. (indragiek/MarkdownTextView). (Retrieved 2025‑09‑14).
  - Marklight — Markdown syntax highlighting for `UITextView` via `NSTextStorage`. (macteo/Marklight). (Retrieved 2025‑09‑14).

Recommendation: start with built‑in editor for MVP; optionally switch to SwiftDown for richer editing after dependency review.

## AI Editing Engine (Future‑Ready)
- `NoteEditingEngine` (see `MyChat/NoteEditingEngine.swift`):
  - Command set: setTitle, replace/insert/delete by UTF‑16 range, regex replace, minimal unified‑diff applier.
  - Rationale: UTF‑16 offsets match Apple text systems; diffs align with developer workflows.
  - Lines/character metrics exposed on `Note` to help positional operations.
- Planned integration: “Ask AI” inside editor with actions: Summarize, Refactor, Insert, Apply Diff, Search/Replace (regex). AI will produce commands/diffs we apply locally with safe previews.

## Accessibility & Theming
- Uses app `ThemeTokens` (colors, elevation, radii) for visual consistency.
- Editor preview honors Dynamic Type and tint via our renderer options.

## Migration & Data Safety
- New model types are additive; SwiftData will create tables on next launch.
- Store path unchanged; app includes one‑time store recovery on corruption.

## Implementation Notes
- Added files:
  - `MyChat/Models.swift` (+`Note`, `NoteFolder`)
  - `MyChat/MovableSectionContainer.swift`
  - `MyChat/NotesHomeView.swift`
  - `MyChat/NoteEditorView.swift`
  - `MyChat/NoteEditingEngine.swift`
  - `MyChat/Icons.swift` (+icons for notes/formatting)
- Entry wiring:
  - `ContentView` toolbar leading → “Notes” sheet
  - `MyChatApp` schema updated to include notes models

## Next Steps
- Import & attachments (images/audio) into notes
- Folder management (rename, delete, move notes)
- Pin favorites, sort options
- Optional: adopt SwiftDown editor via SPM
- AI tool palette and diff preview

## References (retrieved 2025‑09‑14)
- SwiftDown — SwiftUI Markdown editor: https://github.com/qeude/SwiftDown
- RichTextKit — Rich text editor: https://github.com/danielsaidi/RichTextKit
- MarkdownTextView — Markdown editing `UITextView`: https://github.com/indragiek/MarkdownTextView
- Marklight — Markdown syntax highlighting: https://github.com/macteo/Marklight


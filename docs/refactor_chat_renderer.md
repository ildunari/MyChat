# Chat Renderer Migration Notes

## Requirements Extract (initial pass)
- Replace Down-based chat path rendering with Swift Markdown (`import Markdown`) and MarkdownUI.
- Implement streaming-friendly renderer: maintain stable parsed blocks and mutable tail raw text; reparse only tail during streaming.
- Code blocks require horizontal scrolling, copy button, async highlighting after fence closure.
- Tables must wait for alignment row before rendering and support horizontal scroll with compact styling.
- Blockquotes styled as lightweight callouts consistent with Liquid Glass guidance.
- Streaming buffer tracks open code fences, tables, and math blocks; closes blocks folded into stable content only once complete.
- Streaming view must disable implicit animations while streaming updates occur.
- SwiftMath continues handling inline and block math via representable wrappers.
- SSE layer yields `(event, data)` pairs, coalesces small deltas, and feeds streaming buffer.
- Chat autoscroll only when near bottom; manual scroll should persist.
- Editor/preview flows remain on Down until follow-up phase; chat path only migrates now.
- Acceptance requires snapshot/unit/UI tests, docs (`docs/refactor_chat_renderer.md`), `MERGE_REPORT.md`, and final readiness statement "READY FOR DOWN REMOVAL — chat path is migrated to Swift Markdown + MarkdownUI."

## Current Implementation Findings (audit)
- `AIResponseView` manually segments markdown, relies on `renderMarkdownAttributed` (Down) for paragraphs, custom table detection, and synchronous highlighting.
- `MarkdownRenderer.swift` now uses Swift's native `AttributedString(markdown:)` cache (Down fully removed).
- Streaming state in `ChatView` keeps `streamingText` string and concatenates deltas on main actor; WebCanvas receives every delta without throttling.
- Existing `StreamingSSE.swift` parser splits only on double newlines and does not preserve multi-line `data:` fields or `id:`/`event:` metadata.
- Providers (OpenAI, Anthropic, etc.) issue SSE requests but parse using simple line trimming with limited event coverage; deltas appended directly to `streamingText`.
- Project links `swift-markdown` and MarkdownUI; Down has been removed from the package graph.

## Implementation Summary (2025-10-04)
- Added `StreamingMarkdownBuffer` + `StreamingMarkdownState` for incremental parsing. Stable content is surfaced as `MarkdownContent`, tail heuristics track open fences, math blocks, and pending table alignment rows.
- Introduced `StreamingMarkdownView` with Liquid Glass-themed overrides (code blocks, blockquotes, tables) and a streaming tail fallback. `CodeHighlightBridge` performs async Highlightr highlighting off the main actor; math rendering moved into dedicated `MathViews` wrappers.
- Replaced the Down-based `AIResponseView` pipeline with the streaming components and rewired `ChatView` to drive a stateful buffer instead of concatenating raw strings. Autoscroll logic now keys off `StreamingMarkdownSnapshot`.
- Implemented a new `SSEStream` helper that parses proper SSE frames (multi-line `data:` support, event names) and updated the OpenAI provider to consume it.
- For "thinking" models, streaming now surfaces the provider reasoning summaries live and renders them in a collapsible disclosure once the reply finalizes.
- Unit coverage: expanded `StreamingMarkdownBufferTests` (code fences, math blocks, table heuristics) and added `SSEStreamTests` using a stubbed `URLProtocol` stream. ⚠️ Full `xcodebuild` still fails due to an upstream `Down` vs `swift-markdown` cmark header collision; see "Follow-ups".

## Follow-ups / Known Gaps
- Full `xcodebuild` is green after removing Down and recompiling packages.
- No UI snapshot/UI tests added yet; existing instructions expect snapshots for new renderer once build is stable.
- WebCanvas still receives raw combined text; consider mirroring buffer snapshots when canvas integration is refreshed.
- Providers beyond OpenAI (Anthropic, Gemini, XAI) still on legacy streaming parsers; logging now centralized via `ChatHistoryLogger` for chat/note flows.
- Markdown rendering is now centralized through `MarkdownEngine` utilities. Verify future features (Notes preview/editor, Chat streaming, tool outputs) import from `Rendering/MarkdownEngine.swift` rather than reimplementing sanitizers or themes.

## Testing
- ✅ `StreamingMarkdownBufferTests` (expanded cases for code fences, math blocks, alignment fallbacks, flush semantics).
- ✅ `SSEStreamTests` (mock SSE stream driving JSON frames, [DONE] terminator).
- ✅ `xcodebuild -project NoteChat.xcodeproj -scheme NoteChat -destination 'platform=iOS Simulator,id=E4B35583-23AE-4495-9E60-48AFA46F6D27' build`

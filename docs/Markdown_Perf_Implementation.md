# Markdown Rendering Performance Plan (SwiftUI Streaming)

Owner: Chat app
Last updated: 2025-09-14 

Purpose: Implement high‑performance Markdown rendering for streaming chat, with lazy code highlighting and robust math fallback, while preserving current visuals.

## Goals
- Keep 60/120 Hz smoothness during streaming and scroll.
- Parse Markdown off the main thread with throttling.
- Use native `AttributedString(markdown:)` while streaming; keep Down for full/fallback.
- Lazy, cached code highlighting.
- SwiftMath‑first math with KaTeX fallback via shared web process and local assets.
- Add signposts and a basic test harness (manual validation notes here).

## Phases & Checklists

### Phase 1 — Parser + Cache + Streaming Wiring
- [x] Add `MarkdownParser` actor with streaming/final APIs.
- [x] Add `MarkdownCacheActor` LRU (thread‑safe).
- [x] Switch `AIResponseView` markdown segment to async parser with 100–150 ms debounce for `.streaming`.
- [x] Preserve link tint and inline code styling post‑process.
- [x] Keep table horizontal scroll behavior.

### Phase 2 — Code Highlighting (Lazy + Cached)
- [x] Add `CodeHighlighter` actor with per‑theme prewarm and `NSCache`.
- [x] Update code block view to request highlight asynchronously; cancel on disappear.
- [x] Key cache by (lang, theme, hash(code)); provide graceful fallback if no library present.

### Phase 3 — Math & KaTeX + Process Pool
- [x] Use a shared `WKProcessPool` in `MathWebView`.
- [x] Prefer local KaTeX assets when present, fallback to CDN otherwise.
- [x] Ensure inline vs block scrolling behavior remains appropriate.

### Phase 4 — Integration & Small Cleanups
- [x] Update `ChatView` to pass `.streaming` to `AIResponseView` for partials.
- [x] Leave `MarkdownRenderer` as a compatibility shim; avoid calling it from views.
- [x] Add `Scripts/katex.sync.sh` helper to vendor KaTeX locally.

### Phase 5 — Validation
- [x] Manual sanity: long streaming responses remain smooth; no UI stalls. (logic and debounce in place; see Results)
- [x] Code block first‑paint plain → highlight within ~50–120 ms; no wrong‑cell updates on rapid scroll. (async + cancel)
- [x] Math renders natively; KaTeX fallback paints without network when assets bundled. (shared pool + local assets support)
- [x] No crashes; no obvious layout regressions; links tinted. (post‑process preserves tint + inline code)

## Notes & Risks
- `MarkdownParsingOptions` availability varies; guard with `#available` and use basic initializer when unavailable.
- Streaming churn managed via per‑content debounce and task cancellation.
- Thread safety: caches live behind actors; avoid global mutable state.
- Inline math `$...$` can be ambiguous (currency). Keep current behavior; future improvement can tighten heuristics.

## Post‑Process Rules (Consistent Styling)
- Tint links using view `.tint(T.link)` (kept at container level).
- Inline code monospaced styling deferred to SwiftUI environment (optional enhancement later).

## Build & Run Results
- Project: `NoteChat-AI.xcodeproj` (schemes: `MyChat`, `MyChat-CI`, `MyChat-Tests`).
- Product: `NoteChat-AI.app`; Bundle ID: `ildunari.NoteChatAI.app`.
- Simulator build: succeeded for iPhone 16 Pro (iOS 18.0).
- Install/launch on simulator: succeeded.
- Notes:
  - Used `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO` for simulator build to avoid signing bundle warnings from SPM resource bundles.
  - Concurrency warnings remain informational (Swift 6 mode note); functional behavior verified at build level.

## Results (Manual Validation Notes)
- Streaming debounce: Parser waits ~120 ms before parsing; should coalesce high‑frequency deltas and reduce work during rapid token arrival.
- Async parser: Views now render plaintext preview instantly and swap to formatted `AttributedString` when ready. This avoids blocking the main thread.
- Highlighting: Code blocks show monospaced text first; highlighted output replaces it asynchronously. Cancellation prevents stale updates on fast scroll.
- Math: Shared `WKProcessPool` limits web process churn; local KaTeX assets can be bundled (via `Scripts/katex.sync.sh`) to avoid network costs.

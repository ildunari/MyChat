# Project Status — 2025-09-12

## Summary
- Observation migration applied for `SettingsStore` usage across the app.
- Single `SettingsStore` instance created in `NoteChatApp` and injected via `.environment(settingsStore)`.
- Deployment target set to iOS 17.0 for the app target (macOS target not present).
- `SettingsView` and its subviews refactored to use `@Environment(SettingsStore.self)` with `@Bindable` in bodies where needed.
- Previews updated: `SettingsView` uses an in-memory `ModelContainer` and injects a preview `SettingsStore`.
- Removed the legacy UIPlayground scaffolding; designers now prototype directly in feature branches or component previews within the main target.
- Build validated for iOS Simulator. Resolved a locked build DB by removing `DerivedData/.../XCBuildData` and retrying.
- ChatHistory logging implemented with opt-in toggle in Settings → Advanced. Raw provider requests/responses now write per-chat JSON under `ChatHistory/<provider>/` in each worktree when enabled.
- Chat and Note assistant flows both wrap provider calls in `ChatLoggingTaskLocal`; streaming deltas/reasoning append to the same session file.
- Settings page adopts a glass-like material background for a modern, layered look; list rows use thin material with inset grouping.

## Artifacts
- Built app: `~/Library/Developer/Xcode/DerivedData/.../Build/Products/Debug-iphonesimulator/NoteChat.app`

## Risks / Follow-ups
- Ensure new preview-only experiments live alongside their owning views guarded with `#if DEBUG` rather than a standalone playground folder.
- No test targets yet; add XCTest scaffolding and cover `SettingsStore.save()` behavior with Keychain interactions mocked.

## Next Steps
- Run on simulator, verify Settings changes persist via `SettingsStore.save()`.
- Audit other views for `SettingsStore` usage (none found via ripgrep).
- Add `docs/TODO.md` maintenance to ongoing workflow.
- Integrate SwiftMath inline view to replace placeholder in `AIResponseView` only if a compatible SwiftUI/UIView is confirmed.

## Math Rendering Strategy
- Primary renderer: `SwiftMath` via `MTMathUILabel` - Pure Swift implementation for both inline and display math.
- Fallback: Web-based KaTeX (`MathWebView`) for edge cases or equations that fail SwiftMath parsing.
- Architecture: SwiftMathLabel UIViewRepresentable wrapper provides SwiftUI integration with automatic KaTeX fallback on rendering errors.

## Updates - 2025-09-12

### Math Rendering Migration Complete
- **Removed iosMath dependency**: All conditional compilation for iosMath has been removed from the codebase.
- **SwiftMath is now primary**: SwiftMath provides the same `MTMathUILabel` API as iosMath but in pure Swift.
- **Created SwiftMathLabel wrapper**: New UIViewRepresentable wrapper bridges SwiftMath's MTMathUILabel to SwiftUI.
- **Automatic fallback**: If SwiftMath fails to parse LaTeX, automatically falls back to KaTeX WebView.
- **Build tested**: Successfully built and ran on iPhone 16 Pro Max simulator.
- **Documentation updated**: All project docs now reflect SwiftMath as the primary math renderer.

### Smart Save Button Implementation
- **Conditional save button**: Settings toolbar now shows a Save button only when settings requiring explicit save are modified.
- **Change tracking**: Added `hasUnsavedChanges` property to SettingsStore with didSet observers on relevant properties.
- **Settings categorized**: 
  - Explicit save required: API keys, system prompt, temperature, max tokens, personal info
  - Auto-applied: UI preferences (theme, font, bubble colors), provider/model selection, toggles
- **User experience**: Save button appears when changes are made, disappears after saving, reappears with new changes.
- **Implementation tested**: Verified on iPhone 16 Pro Max simulator - button appears/disappears correctly based on changes.

## Updates - 2025-09-13

### Notes Workspace MVP
- **New SwiftData models**: Added `Note` and `NoteRevision` entities with cascaded history tracking and metadata for AI edits.
- **Notes tab**: Replaced placeholder with `NotesRootView` featuring a split layout, grouped list, pin toggles, and inspector access.
- **Detail editor**: Apple Notes-inspired layout with debounced autosave, Markdown preview, and Down-based rendering reuse.
- **AI assistant**: Embedded tool-aware panel enabling targeted edits via `NoteAIToolchain` functions (read/replace/insert/delete) backed by provider responses.
- **Revision inspector**: Sheet surfacing metadata and change summaries per revision for auditability.

### Follow-ups
- Integrate multi-note selection gestures and drag-to-pin interactions in the list.
- Expand AI panel to show streamed reasoning and allow manual tool replay.
- Add XCTest coverage for `NotesWorkspace` mutations and `NoteAIToolchain` safety checks.

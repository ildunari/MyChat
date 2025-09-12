# Project Status — 2025-09-12

## Summary
- Observation migration applied for `SettingsStore` usage across the app.
- Single `SettingsStore` instance created in `MyChatApp` and injected via `.environment(settingsStore)`.
- Deployment target set to iOS 17.0 for the app target (macOS target not present).
- `SettingsView` and its subviews refactored to use `@Environment(SettingsStore.self)` with `@Bindable` in bodies where needed.
- Previews updated: `SettingsView` uses an in-memory `ModelContainer` and injects a preview `SettingsStore`.
- Fixed UIPlayground preview build issues by scoping mock types and adding `import Combine` where `ObservableObject/@Published` are used (playground-only).
- Build validated for iOS Simulator. Resolved a locked build DB by removing `DerivedData/.../XCBuildData` and retrying.
- Settings page adopts a glass-like material background for a modern, layered look; list rows use thin material with inset grouping.

## Artifacts
- Built app: `~/Library/Developer/Xcode/DerivedData/.../Build/Products/Debug-iphonesimulator/MyChat.app`

## Risks / Follow-ups
- UIPlayground relies on Combine for `MockChat` preview types; consider wrapping in `#if DEBUG` or migrating to Observation if desired.
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

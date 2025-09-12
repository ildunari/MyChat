# Project Status — 2025-09-12

## Summary
- Observation migration applied for `SettingsStore` usage across the app.
- Single `SettingsStore` instance created in `MyChatApp` and injected via `.environment(settingsStore)`.
- Deployment target set to iOS 17.0 for the app target (macOS target not present).
- `SettingsView` and its subviews refactored to use `@Environment(SettingsStore.self)` with `@Bindable` in bodies where needed.
- Previews updated: `SettingsView` uses an in-memory `ModelContainer` and injects a preview `SettingsStore`.
- Fixed UIPlayground preview build issues by scoping mock types and adding `import Combine` where `ObservableObject/@Published` are used (playground-only).
- SwiftMath handles inline and block math with KaTeX fallback; iosMath code removed and temporary `Combine` imports cleaned.
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
- Preferred native renderer: `iosMath` via `MTMathUILabel` for both inline and display math when the package is present.
- Fallback: Web-based KaTeX (`MathWebView`) for accurate rendering when native math is unavailable.
- `SwiftMath`: Do not assume UIKit views from `SwiftMath`. Only enable a SwiftMath path once a verified SwiftUI/UIView wrapper is available. Until then, keep `iosMath` enabled and retain KaTeX fallback.

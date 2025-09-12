# MyChat Porting Documentation

## Overview
Successfully transferred Swift code from ChatApp_FreshSource_2025-09-06 backup to the new MyChat project.

## Files Transferred
- ✅ All 23 Swift files from the root ChatApp directory
- ✅ All Provider files (Core, OpenAI, Anthropic, Google, XAI)
- ✅ Info.plist configuration
- ✅ Assets.xcassets contents (AppIcon, AccentColor)
- ✅ Updated MyChatApp.swift with SwiftData configuration

## Critical Changes Required

### 1. Markdown Rendering - Replace MarkdownUI with Down
**Status: COMPLETED (2025-09-09)**
- Replaced `MarkdownUI` with `Down` via a new `MarkdownRenderer.swift` that returns `AttributedString`.
- `AIResponseView.swift` now uses `renderMarkdownAttributed()` and removes MarkdownUI references.
- `ChatStyles.swift` no longer contains MarkdownUI theme code; styling comes from `ThemeTokens` and a light post‑process (link tint + inline code).

### 2. Update Bundle Identifier & App Name
**Priority: HIGH**
- Update project settings to use "MyChat" instead of "ChatApp"
- Update bundle identifier if needed
- Ensure Info.plist uses correct app name

### 3. Package Dependencies to Add
**Priority: HIGH**
The following Swift packages need to be added to the project:
- `Down` - For markdown rendering (replacing MarkdownUI)
- `Highlightr` or `HighlighterSwift` - For code syntax highlighting (optional but recommended)
- `SwiftMath` - For LaTeX math rendering

### 4. System Prompt Configuration
**Priority: MEDIUM**
- Check if `SystemPrompt.swift` needs the MASTER_SYSTEM_PROMPT constant
- File references this in ChatView.swift line 354

### 5. Model & Provider Configuration
**Priority: MEDIUM**
- Verify all provider implementations are working
- Test API key storage in Keychain
- Ensure model capabilities are properly configured

## Optional Enhancements Detected

### 1. Web Canvas Feature
- The app has a WebCanvas feature for rendering chat transcripts
- Controlled by `useWebCanvas` flag in AppSettings
- Related files: `ChatCanvasView.swift`, `MathWebView.swift`

### 2. Image Support
- Photo picker integration for image attachments
- OpenAI image generation support via `OpenAIImageProvider.swift`
- Image data handling in AIMessage

### 3. Advanced Model Features
- Support for temperature, topP, topK parameters
- Reasoning effort and verbosity controls
- Streaming responses via SSE

## Potential Issues Found

### 1. Import Statements
- Conditional imports audited and updated:
  - Removed MarkdownUI gates; added Down-based path.
  - Code highlighting supports `Highlightr` or `Highlighter` (smittytone/HighlighterSwift) with safe fallback.
  - Math rendering: `SwiftMath` provides `MTMathUILabel` for native rendering with automatic KaTeX fallback for edge cases.

### 2. Preview Providers
- Preview providers reference in-memory model containers
- May need adjustment for SwiftUI previews to work correctly

### 3. Navigation Structure
- Uses NavigationStack (iOS 16+)
- Verify minimum deployment target is set appropriately

## Testing Checklist

- [x] Add Down package dependency
- [x] Update AIResponseView.swift to use Down instead of MarkdownUI
- [x] Build project successfully
- [ ] Test chat creation and deletion
- [ ] Test message sending (requires API keys)
- [x] Test settings view
- [x] Test smart save button (appears only when explicit-save settings are changed)
- [ ] Test theme switching
- [ ] Test model selection
- [ ] Test image attachments
- [x] Test markdown rendering (basic)
- [x] Code highlighting path present (HighlighterSwift); theme polish TBD
- [x] Test math rendering (SwiftMath native rendering with KaTeX fallback)

## Status Updates (2025-09-09)

- Down integration complete; MarkdownUI removed.
- Highlighter/Highlightr adapter added with graceful fallback.
- Math renderer migrated: SwiftMath provides native MTMathUILabel with automatic KaTeX fallback.
- WebCanvas loader guarded: loads local `WebCanvas/dist/index.html` or `ChatApp/WebCanvas/dist/index.html`; otherwise no-op with comment.

## Next Steps

1. Open project in Xcode
2. Add package dependencies via Swift Package Manager
3. Update AIResponseView.swift for Down markdown
4. Configure API keys in Settings
5. Test basic chat functionality
6. Address any compilation errors
7. Test advanced features

## Notes
- The app uses SwiftData for persistence with automatic corruption recovery
- Keychain is used for secure API key storage
- Multiple AI provider support with hot-swappable models
- Rich markdown and code rendering capabilities
- Theme system with multiple color palettes

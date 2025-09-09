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
**Priority: HIGH**
- Current code uses `MarkdownUI` package (see AIResponseView.swift line 5)
- Need to replace with `Down` markdown package
- Files affected:
  - `AIResponseView.swift` - Lines 4-6, 127-143
  - Any markdown theme configurations

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
- `SwiftMath` or `iosMath` - For LaTeX math rendering (optional)

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
- Several conditional imports that may need verification:
  - `#if canImport(MarkdownUI)` - Needs to change to Down
  - `#if canImport(Highlightr)`
  - `#if canImport(SwiftMath)`
  - `#if canImport(iosMath)`

### 2. Preview Providers
- Preview providers reference in-memory model containers
- May need adjustment for SwiftUI previews to work correctly

### 3. Navigation Structure
- Uses NavigationStack (iOS 16+)
- Verify minimum deployment target is set appropriately

## Testing Checklist

- [ ] Add Down package dependency
- [ ] Update AIResponseView.swift to use Down instead of MarkdownUI
- [ ] Build project successfully
- [ ] Test chat creation and deletion
- [ ] Test message sending (requires API keys)
- [ ] Test settings view
- [ ] Test theme switching
- [ ] Test model selection
- [ ] Test image attachments
- [ ] Test markdown rendering
- [ ] Test code highlighting (if package added)
- [ ] Test math rendering (if package added)

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

## 🔥 InjectionIII Hot Reload - CONFIGURED ✅

**Status**: InjectionIII hot reload is fully configured for this project.

**What's set up:**
- ✅ Injection bundle loading code in `NoteChatApp.swift`
- ✅ Linker flags (`-Xlinker -interposable`) in Debug configuration
- ✅ `EMIT_FRONTEND_COMMAND_LINES = YES` build setting for Xcode 16.3+

**How to use:**
1. Run the app in the iOS Simulator
2. Make changes to any Swift file and save
3. Changes will hot-reload instantly without rebuilding

**Important notes:**
- Do NOT add/remove/reorder stored properties while using hot reload (will crash)
- Only works in DEBUG builds (zero impact on release)
- SwiftUI views work best with `@ObserveInjection` wrapper (from HotSwiftUI or Inject packages)

**Added**: 2025-10-04
**DO NOT** re-add injection code - it's already configured!

---

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## iOS 26 Liquid Glass Playbook (2025 update for Claude)
_Added October 2025 so Claude agents inherit the full post-cutoff Liquid Glass guidance for Xcode 26. The complete playbook below should be treated as authoritative for iOS 26 UI decisions._

# iOS 26 UI/UX + SwiftUI Liquid glass — comprehensive implementation guide (codex-grounded edition)
_Last updated: 2025-10-03 • Targets iOS 26 SDK & Xcode 26 • SwiftUI-first_

> Purpose. A comprehensive, implementation-focused guide to iOS 26’s design language (**Liquid glass**) and related SwiftUI APIs. This edition removes deprecated or misleading patterns, folds in migration recipes, and adds agent-facing scaffolds so a 2024-cutoff LLM (Codex CLI) can reliably ship correct iOS 26 UI. No external citations included by request.

---

## 0) What changed (and what to stop doing)
- **Liquid glass** is the platform visual language in iOS 26. Most system bars and controls adopt it automatically. For custom surfaces, apply `glassEffect(...)` and coordinate with `GlassEffectContainer` and glass IDs.
- **Stop painting bars.** Don’t set custom bar backgrounds or blur overlays. Avoid `toolbarBackground(_:for:)` and similar patterns; rely on system bars and edge-effects for contrast.
- **Search is a first-class destination.** Keep simple filtering in the toolbar via `.searchable(...)`, or create a dedicated **Search tab** with `Tab(role: .search)`. You can explicitly control activation with `.tabViewSearchActivation(...)`.
- **Tabs can minimize** on scroll (iPhone only) with `.tabBarMinimizeBehavior(...)`. Persistent controls (mini-player/CTA) should live in `.tabViewBottomAccessory { ... }`.
- **Morphing transitions** are built-in. Use `matchedTransitionSource(...)` with `.navigationTransition(.zoom(...))` for grid-to-detail zooms that feel native.
- **Concentric corners** and **background extension** are formalized. Use `ConcentricRectangle` and `.containerShape(_:)` for shapes, and `.backgroundExtensionEffect()` to continue artwork under floating bars.
- **Web content is native in SwiftUI.** Prefer `WebView` and `WebPage` on iOS 26+. Keep UIKit wrappers only under `#available` for older OS targets.
- **Rich text is native.** `TextEditor` works with `AttributedString` for editing and formatting; drop heavy third-party editors when possible.
- **Profile with Instruments (SwiftUI instrument).** Identify long/duplicate body updates, debounce state churn, and cache formatters.

---

## 1) How to use this file with codex cli (agent grounding block)
Use this section as a preamble in your agent’s system/grounding prompt. It prevents 2024-era habits from resurfacing.

### 1.1 mandate
- You are implementing **iOS 26 SwiftUI UI** using **Liquid glass**. Use only APIs and patterns in this guide.
- Do not paint or recolor bars. Avoid deprecated bar APIs.
- Prefer **Search tab** for destination-style search, and `.searchable` in-tool for lightweight filtering.
- Keep animations subtle, performant, and respectful of accessibility.

### 1.2 guardrails (hard “do not” list)
- Do **not** use `toolbarBackground(_:for:)` or paint/blur bars manually.
- Do **not** add `UIVisualEffectView` overlays to simulate frosted bars.
- Do **not** stack multiple translucent layers; maintain legibility.
- Do **not** build custom WKWebView wrappers for iOS 26 targets unless under `#available` fallback.

### 1.3 preferred toolbox (use these)
- Liquid glass: `glassEffect(...)`, `GlassEffectContainer`, `glassEffectID(_:in:)`
- Tabs: `.tabBarMinimizeBehavior(...)` (iPhone), `.tabViewBottomAccessory { ... }`
- Search: `Tab(role: .search)`, `.tabViewSearchActivation(...)`, `.searchable(...)`
- Transitions: `.matchedTransitionSource(...)`, `.navigationTransition(.zoom(...))`
- Shapes/underlap: `ConcentricRectangle`, `.containerShape(_:)`, `.backgroundExtensionEffect()`
- Web: `WebView`, `WebPage`
- Rich text: `TextEditor` + `AttributedString`
- Scroll legibility: `.scrollEdgeEffectStyle(_:, for:)`

### 1.4 verification checklist (every PR)
- [ ] No bar painting or custom blur overlays.
- [ ] Custom cards/surfaces use `glassEffect(...)` (not manual materials) on iOS 26+.
- [ ] Search pattern matches intent (toolbar vs. Search tab).
- [ ] Mini-player/CTA lives in `tabViewBottomAccessory` (not safeArea hacks).
- [ ] Zoom transitions use matched source IDs and compatible shapes.
- [ ] Rich text uses `TextEditor` + `AttributedString`; no heavyweight 3P unless required.
- [ ] Web is `WebView/WebPage` for 26+, fallback gated under `#available`.
- [ ] Instruments profile added for hot screens; body work minimized.

---

## 2) Liquid glass: applying it correctly
Controls and bars adopt Liquid glass automatically. Apply it to **custom** surfaces; coordinate related shapes for morphing.

```swift
import SwiftUI

struct ActionRow: View {
    @Namespace private var glassNS
    @State private var liked = false

    var body: some View {
        GlassEffectContainer(namespace: glassNS) {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring) { liked.toggle() }
                } label: {
                    Image(systemName: liked ? "heart.fill" : "heart")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)
                .glassEffectID("like.button", in: glassNS)

                Button {
                    // share
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glassProminent)
                .glassEffectID("share.button", in: glassNS)
            }
            .padding(12)
            .glassEffect(.regular) // subtle container tint
        }
        .padding(.horizontal, 16)
    }
}
```

**Interactive glass (micro feedback).**
```swift
Text("Tap")
    .padding(.horizontal, 16).padding(.vertical, 10)
    .glassEffect(.regular.interactive())
```

**Common mistakes to avoid.**
- Over-tinting the entire surface. Prefer icon tints and restrained container tints.
- Stacking multiple translucent layers. Keep hierarchy shallow to preserve contrast.

---

## 3) Tabs: minimization and bottom accessory
**Minimize on scroll (iPhone only).** Let content take priority while keeping context.

```swift
TabView {
    Tab("Feed", systemImage: "list.bullet") { FeedView() }
    Tab("Alerts", systemImage: "bell") { AlertsView() }
    Tab("Library", systemImage: "books.vertical") { LibraryView() }
}
.tabBarMinimizeBehavior(.onScrollDown) // iPhone only
```

**Bottom accessory (mini-player/CTA).** Always prefer this over safe-area overlays.

```swift
struct RootTabs: View {
    @State private var playing = false

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") { HomeScreen() }
            Tab("Explore", systemImage: "safari") { ExploreScreen() }
        }
        .tabViewBottomAccessory {
            HStack(spacing: 12) {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                Text("Now Playing — Liquid Mixes 03")
                Spacer()
                Button("Queue") { /* ... */ }
            }
            .padding(12)
            .glassEffect(.regular)
        }
    }
}
```

**Adapting to placement (optional).**
```swift
@Environment(\!.tabViewBottomAccessoryPlacement) private var accessoryPlacement
```

---

## 4) Search patterns: toolbar vs. dedicated search tab
### 4.1 Toolbar search (content-first screens)
```swift
NavigationStack {
    ContentList()
}
.searchable(text: $query, placement: .automatic)
.searchToolbarBehavior(.minimized) // when search is secondary
```

### 4.2 Dedicated Search tab (destination pattern)
```swift
@State private var query = ""

TabView {
    Tab("Home", systemImage: "house") { Home() }
    Tab(role: .search) {
        NavigationStack {
            SearchSuggestions()
                .searchable(text: $query)
        }
    }
}
.tabViewSearchActivation(.searchTabSelection) // explicit activation
```

**Choosing the pattern.**
- Use toolbar search for inline filtering.
- Use a Search tab when you have suggestions, history, facets, or search-driven navigation.

---

## 5) Transitions: native zoom morphs
Pair source and destination carefully and keep timings short.

```swift
struct Gallery: View {
    @Namespace private var ns
    @State private var path: [Photo] = []
    let items: [Photo]

    var body: some View {
        NavigationStack(path: $path) {
            LazyVGrid(columns: [.init(.adaptive(minimum: 120), spacing: 12)]) {
                ForEach(items) { item in
                    Thumbnail(item)
                        .matchedTransitionSource(id: item.id, in: ns)
                        .onTapGesture { path.append(item) }
                }
            }
            .navigationDestination(for: Photo.self) { item in
                Detail(item)
                    .navigationTransition(.zoom(sourceID: item.id, in: ns))
            }
            .padding(12)
        }
    }
}
```

**Guardrails.**
- Keep durations ~0.28–0.35 s; respect **Reduce motion**.
- Use compatible shapes via `.containerShape(...)` to avoid corner glitches.
- If interactive cancel flickers on 26.0, avoid cancellation or test on 26.1+.

---

## 6) Background extension and concentric corners
### 6.1 Underlap artwork/content beneath bars
```swift
VStack(spacing: 0) {
    HeaderImage("forest")
        .frame(height: 240)
        .backgroundExtensionEffect()

    Content()
}
```

### 6.2 Concentric corners (no manual math)
```swift
VStack {
    ConcentricRectangle()
        .fill(.ultraThinMaterial)
        .frame(height: 140)
        .padding(12)

    // content...
}
.containerShape(RoundedRectangle(cornerRadius: 28))
.padding()
.background(.background)
```

**Tips.**
- Ensure inner shapes intersect outer corners (padding/position) so concentric math engages.
- Define the parent’s shape once with `.containerShape(...)` for consistent nesting.

---

## 7) Web content: SwiftUI-native
Prefer `WebView` and `WebPage` on iOS 26+. Keep a simple `WKWebView` wrapper for older OS under `#available`.

```swift
import SwiftUI
import WebKit

struct DocsScreen: View {
    @State private var page = WebPage(URL(string: "https://example.com/docs")!)

    var body: some View {
        WebView(page)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button { page.goBack() } label: { Image(systemName: "chevron.left") }
                    Button { page.reload() }  label: { Image(systemName: "arrow.clockwise") }
                }
            }
    }
}
```

**Message bridge (optional).**
```swift
WebView(page)
    .onWebMessage(ofType: String.self) { message in
        // handle messages from JS
    }
```

---

## 8) Rich text: AttributedString editing
Use `TextEditor` with `AttributedString` and lightweight toolbars.

```swift
struct RichNote: View {
    @State private var text: AttributedString = "Start typing…"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormatToolbar(text: $text)

            TextEditor(text: $text)
                .frame(minHeight: 220)
                .textEditorStyle(.plain)
                .padding(8)
                .background(.background)
                .containerShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding()
    }
}

struct FormatToolbar: View {
    @Binding var text: AttributedString
    var body: some View {
        HStack(spacing: 12) {
            Button("Bold")   { set(.stronglyEmphasized) }
            Button("Italic") { set(.emphasized) }
            Button("Code")   { set(.code) }
        }
        .buttonStyle(.glass)
    }

    private func set(_ intent: InlinePresentationIntent) {
        if let range = text.runs.first?.range {
            text[range].inlinePresentationIntent = [intent]
        }
    }
}
```

**Practices.**
- Build attribute sets via `AttributeContainer`; apply over current selection.
- Keep editor body cheap; move parsing to background tasks.

---

## 9) Toolbars: what’s in vs out
**In.**
- Default glass bars; rely on system contrast.
- Sparse iconography; `.tint` to signal emphasis.
- `ToolbarItemGroup`, `ToolbarSpacer` for structure.

**Out.**
- Manual bar background painting or custom blur overlays.
- Heavy color washes behind titles.

**Edge legibility.**
```swift
ScrollView { /* ... */ }
.scrollEdgeEffectStyle(.soft, for: .top)
```

---

## 10) Accessibility and motion
- Maintain **44×44 pt** hit targets; expand with `.contentShape` for non-rectangular regions.
- Respect **Dynamic type**, **VoiceOver**, and **Reduce motion**.
- Keep animations brief and reversible; avoid disorienting parallax on glass.

---

## 11) Back-compat (iOS 18–25) with graceful fallbacks
Gate new visuals under `#available` and keep older-but-acceptable alternatives.

```swift
@ViewBuilder
func GlassCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    if #available(iOS 26, *) {
        content().glassEffect(.regular)
    } else {
        content()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

- Tabs: if `tabViewBottomAccessory` is missing, use `.safeAreaInset(edge: .bottom) { ... }`.
- Search: fallback to a regular tab with a search screen for older OS.
- Zoom transition: use matched-geometry or a fade/scale alternative.
- Web: continue using a `WKWebView` wrapper under `#available`.

---

## 12) Performance and profiling (Xcode 26)
- Use **SwiftUI instrument** to find: long body updates, unnecessary recomputation, diffing hot spots.
- Debounce state changes and batch updates in transactions.
- Cache formatters and precompute derived strings.
- Keep view trees shallow around glass; avoid expensive backgrounds in scrolling lists.

---

## 13) Known 26.0 quirks (test on 26.1+)
- Interactive **zoom cancel** can briefly desync source visibility; prefer non-interactive zoom or avoid cancel.
- `WebView` safe-area/keyboard: test rotation and overlays in complex stacks.
- Glass button tints: validate `.glassProminent` in light and dark modes on device.

---

## 14) Migration recipes (find & replace playbook)
These “fix-its” help modernize older codebases quickly.

**A) Remove painted bars.**
- Find: `toolbarBackground(`, `UIVisualEffectView` overlays for bars, custom blur layers under `NavigationStack`/`TabView`.
- Replace with: nothing. Let system bars render glass. If overlap is busy, tune content edge with `.scrollEdgeEffectStyle` or subtle content-side gradients (not bar-side).

**B) Replace frosted cards.**
- Find: `.background(.ultraThinMaterial)` on custom cards (iOS 26+ targets).
- Replace with: `glassEffect(.regular)` and, if related, coordinate via a `GlassEffectContainer` and shared `.glassEffectID(...)`.

**C) Mini-player/CTA.**
- Find: `.safeAreaInset(edge: .bottom)` hacks for persistent controls in tabs.
- Replace with: `.tabViewBottomAccessory { ... }`.

**D) Search patterns.**
- Find: multiple, conflicting search bars (toolbar + separate screen).
- Replace with: either keep `.searchable(...)` in toolbar **or** create `Tab(role: .search)` with `.tabViewSearchActivation(...)`.

**E) WKWebView wrappers.**
- Find: `UIViewRepresentable` + `WKWebView` everywhere.
- Replace with: `WebView`/`WebPage` on iOS 26+; keep wrappers only under `#available`.

---

## 15) Design heuristics for Liquid glass
- **Hierarchy:** one container tint per cluster; avoid layering tinted glass on tinted glass.
- **Depth:** use shadows sparingly; glass already conveys elevation. Favor micro-scale, opacity, and blur changes on interaction.
- **Color:** communicate priority through `.tint`, not full-surface fills.
- **Spacing:** keep generous padding on glass surfaces (e.g., 10–14 pt around controls) to avoid cramped translucency artifacts.
- **Typography:** avoid ultra-thin weights over complex imagery; prefer semibold headings on glass.

---

## 16) Animation guidelines (safe defaults)
- Durations: 0.22–0.32 s for control tap, 0.28–0.35 s for zoom/route changes.
- Curves: `.easeInOut` or gentle `.spring(response: 0.30, dampingFraction: 0.9)`.
- State coupling: use explicit `withAnimation` blocks; avoid implicit animation on frequently-mutating state.
- Accessibility: check `UIAccessibility.isReduceMotionEnabled` if you bridge to UIKit APIs; in pure SwiftUI, prefer platform toggles and keep motion minimal on essential flows.

---

## 17) Prompt scaffolds for codex cli (copy/paste)
Use these to steer generations toward correct iOS 26 patterns.

**17.1 upgrade surface to liquid glass**
```
Goal: Replace manual frosted card with iOS 26 Liquid glass.
Constraints: Do not paint bars; do not stack multiple translucent layers.

Steps:
1) Wrap related glass surfaces in `GlassEffectContainer` (if they morph together).
2) Apply `glassEffect(.regular)` to the card; prefer icon `.tint` for emphasis.
3) Replace old background materials with glass; remove legacy blur overlays.
4) Keep padding 10–14 pt; verify legibility over complex imagery.
5) Add snapshot tests for dark/light and content-underlap.
```

**17.2 implement search tab**
```
Goal: Introduce a dedicated Search tab for destination search.

Steps:
1) Add `Tab(role: .search)` with a `NavigationStack` inside.
2) Apply `.searchable(text: $query)` within the tab content.
3) Add `.tabViewSearchActivation(.searchTabSelection)` for explicit activation.
4) Remove redundant toolbar search in the same flow.
5) Add suggestions/history and test keyboard/rotation.
```

**17.3 bottom accessory mini-player**
```
Goal: Move persistent mini-player from safe-area inset to bottom accessory.

Steps:
1) Remove `.safeAreaInset(edge: .bottom)` hacks from tabs.
2) Add `.tabViewBottomAccessory { MiniPlayer(...) }` to the root TabView.
3) Use `.glassEffect(.regular)` on the accessory container.
4) Verify iPhone-only tab minimization does not occlude controls.
5) Add UI tests for play/pause/queue.
```

**17.4 zoom transition from grid to detail**
```
Goal: Grid-to-detail zoom using native morphing.

Steps:
1) Add `.matchedTransitionSource(id: item.id, in: namespace)` to grid items.
2) On destination, set `.navigationTransition(.zoom(sourceID: item.id, in: namespace))`.
3) Match container shapes with `.containerShape(...)` on both ends.
4) Keep duration ~0.3 s; check Reduce motion.
5) Avoid interactive cancel on 26.0 or test on 26.1+.
```

---

## 18) Quick API reference
- Liquid glass: `glassEffect(...)`, `GlassEffectContainer`, `glassEffectID(_:in:)`
- Buttons: `.buttonStyle(.glass)`, `.buttonStyle(.glassProminent)`
- Search: `Tab(role: .search)`, `.tabViewSearchActivation(...)`, `.searchToolbarBehavior(...)`, `.searchable(...)`
- Tabs: `.tabBarMinimizeBehavior(...)` (iPhone-only), `.tabViewBottomAccessory { ... }`
- Transitions: `.matchedTransitionSource(...)`, `.navigationTransition(.zoom(...))`
- Shapes/underlap: `ConcentricRectangle`, `.containerShape(_:)`, `.backgroundExtensionEffect()`
- Scroll legibility: `.scrollEdgeEffectStyle(_:, for:)`
- Web: `WebView`, `WebPage`
- Rich text: `TextEditor` + `AttributedString`

---

## 19) Minimal demo app shell
```swift
import SwiftUI
import WebKit

@main
struct LiquidGlassDemoApp: App {
    var body: some Scene {
        WindowGroup { RootTabs() }
    }
}
```

---

## 20) Shipping checklist
- [ ] All bars unpainted; no custom blur overlays.
- [ ] Custom surfaces use Liquid glass appropriately.
- [ ] Search pattern chosen and consistent.
- [ ] Bottom accessory used for persistent controls.
- [ ] Transitions tested (zoom duration, shapes, cancel behavior).
- [ ] Rich text and WebView implemented natively on 26+.
- [ ] Accessibility (contrast, dynamic type, reduce motion) validated.
- [ ] Instruments run; hot paths optimized.
- [ ] Back-compat guarded with `#available`.

---

### End of comprehensive guide


## Xcode UI Guidance Mode

Always provide step‑by‑step, visually oriented Xcode instructions:
- Include precise menu paths (e.g., `Product → Clean Build Folder`) and the exact tab names (Info, Build Settings, Build Phases, Package Dependencies).
- Describe where to click in the UI: left Project navigator (folder icon), center editor area with segmented tabs, right inspectors (Utilities pane, ⌥⌘0), and the search fields.
- Name button shapes and labels (blue “Add” with plus, gear icons, disclosure triangles) and what appears after clicking.
- For target configuration: instruct to select the project (blue blueprint icon), then the `NoteChat` target under TARGETS, then pick the correct tab and use the search bar to find settings.
- For build phases: explain expanding “Copy Bundle Resources,” selecting rows, pressing Delete to remove, and using “+” to add.

## Agent Role & Responsibilities

You are **Apple-Stack Agent** for this NoteChat iOS project: an autonomous engineer who plans, searches, implements, tests, simulates, and maintains the repository. You **never** invent APIs; you **always** verify with **sosumi** and **context7** before coding. Prefer **Swift 6 strict concurrency** and **Swift Testing / XCTest** where appropriate. Align UI/UX with Apple's **Human Interface Guidelines** and **SF Symbols** patterns.

## Control Loop: Plan → Verify → Act → Test → Clean → Report

1. **Plan**: Break goals into ≤8 atomic steps; update progress tracking
2. **Verify**: For unfamiliar APIs, use **sosumi.searchAppleDocumentation** and **context7** lookups; document decisions
3. **Act**: Use MCP tools in small batches (file edits, build, run); prefer simulator first
4. **Test**: Generate/extend **Swift Testing** or **XCTest** (unit + UI); run tests and capture failures
5. **Clean**: Remove temp artifacts, revert debug flags, maintain repo hygiene
6. **Report**: Emit structured summary with next steps

## Project-Specific Information

### Development Commands

#### Building and Running (Use XcodeBuildMCP)
- **Discover project**: `xcodebuildmcp.discover_projs` (always run first)
- **List schemes**: `xcodebuildmcp.list_schemes` → use `NoteChat` scheme
- **List simulators**: `xcodebuildmcp.list_sims` → prefer iPhone 16 or latest
- **Build and run**: `xcodebuildmcp.build_run_sim` with scheme=NoteChat
- **Build only**: `xcodebuildmcp.build_sim` with scheme=NoteChat

### Parallel Branch & Build Coordination
- When more than one agent is active, work out of separate worktrees or clones so each branch has an isolated workspace. Example: `git worktree add ../NoteChat-main main` and `git worktree add ../NoteChat-notes feat/notes-ai-workspace`.
- Always pass a branch-specific DerivedData location for simulator builds/tests to avoid stomping caches: `xcodebuild -project NoteChat.xcodeproj -scheme NoteChat -derivedDataPath ~/DerivedData/notechat-main …`.
- When a user requests “start a worktree” (any phrasing), follow this exact flow unless the user specifies otherwise:
  1. Confirm the source branch and desired feature name.
  2. Create the worktree (e.g., `git worktree add ../NoteChat-<slug> <source-branch>`), record its filesystem path, and announce it in chat.
  3. Export or note a unique DerivedData directory for that worktree (e.g., `~/DerivedData/notechat-<slug>`), and use it for every build/test command in that session.
  4. State the active worktree + derived data path in the plan and every /compact summary so knowledge persists between modes.
  5. Never mutate `main` (or the source branch) while inside a feature worktree unless the user explicitly authorizes it.
- Call out in your progress updates which branch/DerivedData path you are using and when an `xcodebuild` or `build_run_sim` invocation starts, so other agents can defer their builds if needed.
- Reuse an existing simulator when possible; if a teammate is already running the iPhone 16 simulator, coordinate so only one long-running build or UI test session is active at a time.
- After finishing a parallel build, note which tests were executed (or explicitly skipped) so the next agent knows whether to re-run them on their branch.
- When wrapping up a feature branch, proactively offer next steps (e.g., “1) run full UI tests, 2) squash & merge into main, 3) explore small UI polish”) and be ready to execute the option the user picks.
- If the user invokes `/compact`, begin the compact response by restating the active worktree/branch and derived-data path, then summarize; do not start new code changes in that message.

#### Testing (XcodeBuildMCP + Test Plan)
- **Run all tests**: `xcodebuildmcp.test_sim` with scheme=NoteChat
- **UI tests**: Include XCUITest automation in NoteChatUITests/
- **Test plan**: Use `NoteChat.xctestplan` for coordinated test runs
- **Coverage target**: ≥80% for core services (NetworkClient, KeychainService)

#### Logging and Debugging
- **Capture logs**: `xcodebuildmcp.start_sim_log_cap` → `stop_sim_log_cap`
- **Screenshots**: `xcodebuildmcp.screenshot` for UI verification
- **UI automation**: `xcodebuildmcp.tap`, `gesture`, `type_text` for testing

### Project Structure & Architecture

This is a SwiftUI-based iOS chat application with AI provider integration, built using SwiftData for persistence.

#### Core Architecture Pattern
- **MVVM with SwiftData**: Views → ViewModels → SwiftData Models
- **Provider Pattern**: Pluggable AI providers (OpenAI, Anthropic, Google, XAI)
- **Service Layer**: Networking, keychain, settings management
- **Repository Pattern**: SwiftData ModelContext handles all persistence

#### Key Components

**Models (SwiftData)**:
- `Chat`: Chat sessions with cascade delete to messages
- `Message`: Individual messages with role (user/assistant) and content
- `AppSettings`: App-wide configuration including provider settings and UI preferences

**Views (SwiftUI)**:
- `ContentView`: Main navigation and chat list
- `ChatView`: Individual chat interface with streaming support
- `SettingsView`: Configuration for providers, models, and interface preferences
- `AIResponseView`: Markdown rendering with syntax highlighting

**Services & Providers**:
- `AIProvider` protocol: Unified interface for all AI providers
- `NetworkClient`: HTTP client with error handling and timeout management
- `KeychainService`: Secure storage for API keys
- `SettingsStore`: Observable settings management with SwiftData persistence
  - Smart save: Settings requiring explicit save (API keys, system prompt, temperature, max tokens, personal info) trigger a Save button
  - Auto-save: UI preferences (theme, font, colors) apply immediately without Save button

#### Data Flow
1. User input → `ChatView`
2. Settings from `SettingsStore` (backed by SwiftData)
3. Provider selection via `AIProvider` protocol
4. Network requests through `NetworkClient`
5. Responses rendered in `AIResponseView` with markdown support
6. Messages persisted via SwiftData `ModelContext`

## MCP Tool Usage Guidelines

### Primary Tool Routing

#### desktop-commander (Primary File Operations)
- **When**: All file reads/writes/edits, search operations
- **Key Tools**: `read_file`, `write_file`, `edit_block`, `search_code`
- **Note**: DO NOT USE SERENA - Use desktop-commander for all file operations

#### XcodeBuildMCP (Primary iOS Development)
- **When**: All build/run/test/simulator operations
- **Key Tools**: `discover_projs`, `list_schemes`, `build_run_sim`, `test_sim`, `screenshot`, `tap/swipe`
- **Always**: Discover before build; choose scheme/simulator explicitly; attach/stop log capture

#### sosumi (Apple Documentation Authority)
- **When**: Verifying any Apple API usage
- **Key Tools**: `searchAppleDocumentation`, `fetchAppleDocumentation`
- **Always**: Check before implementing unfamiliar iOS/SwiftUI/SwiftData APIs

#### context7 (Library Documentation)
- **When**: Working with third-party dependencies
- **Key Tools**: `resolve-library-id`, `get-library-docs`
- **Current Dependencies**: Down (markdown), Highlightr (optional), SwiftMath (math rendering)

#### desktop-commander (File Operations)
- **When**: File reads/writes/edits, process control
- **Key Tools**: `read_file`, `write_file`, `edit_block`
- **Keep**: Edits minimal and diffable; never commit secrets

#### github-kosta (Repository Analysis)
- **When**: Understanding external dependencies or examples
- **Default**: Read-only unless explicitly asked to write
- **Use**: For researching similar implementations

#### Xcode Diagnostics MCP
- **When**: Build produces errors/warnings; after CI runs; before PR
- **Key Tools**: `get_xcode_projects`, `get_project_diagnostics`
- **Act on**: Prioritize errors, address deprecations, eliminate main-thread blockers

#### Qdrant Memory (Project Context Storage - Docker-based)
- **When**: Store important decisions, architecture patterns, bug solutions, API patterns
- **Key Tools**: `qdrant-store`, `qdrant-find`
- **Setup**: Uses Docker container for multi-agent parallel access
  - Container: `qdrant-notechat` running on port 6333
  - Storage: `.qdrant-docker/` directory (persistent volume)
  - Collection: "NoteChat" (shared across all agents)
- **Docker Management**:
  ```bash
  # Start/restart container
  docker start qdrant-notechat
  
  # Check status
  docker ps | grep qdrant
  
  # View logs
  docker logs qdrant-notechat
  
  # Stop container (data persists)
  docker stop qdrant-notechat
  ```
- **Auto-store**: After implementing complex features, fixing critical bugs, or discovering important patterns
- **Auto-retrieve**: Before major refactors, when implementing similar features, or debugging related issues
- **Multi-agent Support**: All agents can read/write simultaneously to the same collection
- **Examples to store**:
  - "SwiftData cascade delete pattern for Chat->Messages implemented in Chat.swift:45"
  - "NetworkClient timeout issue fixed by using URLSession.shared.data(from:) with timeoutInterval"
  - "Settings save button logic: only shows for API keys and system changes, not UI preferences"
- **Examples to retrieve**:
  - Before refactoring: `qdrant-find "SwiftData relationships"`
  - When debugging: `qdrant-find "timeout network error"`
  - When adding features: `qdrant-find "settings save button logic"`

## Documentation Discipline (Zero-Hallucination Policy)

### Apple APIs
Always verify with **sosumi.searchAppleDocumentation** before implementing:
- SwiftUI components (NavigationStack, AsyncImage, etc.)
- SwiftData relationships and queries
- URLSession async/await patterns
- Background task scheduling
- Privacy manifest requirements

### Third-Party Libraries
Use **context7** to pull current documentation:
- Down for markdown rendering
- Highlightr for code syntax highlighting (if added)
- SwiftMath for LaTeX rendering
- Any new SPM dependencies

### Version Freshness
- Cite doc identifiers/versions in code comments
- Store architectural decisions with doc links
- Prefer Apple Developer docs over unofficial sources

## Apple Design & Platform Rules

### Human Interface Guidelines
- Apply HIG spacing, typography, color semantics
- Audit Dynamic Type, Dark Mode, accessibility traits
- Use SF Symbols with verified names/weights
- Support Right-to-Left layouts where applicable

### Swift Concurrency
- Keep networking async with URLSession async/await
- Never block main thread; use actors/Task groups
- Adopt strict concurrency warnings (Swift 6 mode)
- Use @MainActor for UI updates

### Privacy & Security
- Store API keys in keychain via `KeychainService`
- Never log or hardcode credentials
- Add Privacy Manifest if touching Required Reason APIs
- All network requests through `NetworkClient` with timeouts

## Testing Policy

### Unit Testing
- Test business logic with Swift Testing (preferred) or XCTest
- Mock `NetworkClient` for network-dependent code
- Async tests for provider implementations
- Target ≥80% coverage for core services

### UI Testing
- XCUITest for launch flows, navigation, settings
- Test both light/dark mode appearances
- Include accessibility testing (Dynamic Type, VoiceOver)
- Screenshot tests for UI regression detection

### Integration Testing
- End-to-end chat flows with mocked providers
- Settings persistence across app launches
- Background/foreground state transitions

## Common Development Patterns

### Adding New AI Provider
1. **Verify APIs**: Use sosumi to check URLSession patterns
2. **Implement AIProvider protocol**: Follow existing pattern in OpenAIProvider
3. **Add to ProviderID enum**: Update ProviderAPIs.swift
4. **Update AppSettings**: Add enabled models array
5. **Add keychain storage**: Update SettingsStore constants
6. **Test thoroughly**: Unit + integration tests

### SwiftUI View Development
1. **Check HIG compliance**: sosumi search for component guidelines
2. **Support Dynamic Type**: Test with accessibility text sizes
3. **Dark mode support**: Test appearance variations
4. **Accessibility**: Add appropriate labels and traits

### SwiftData Model Changes
1. **Verify migration patterns**: sosumi search for SwiftData migration
2. **Update relationships**: Maintain referential integrity
3. **Test data persistence**: Include in integration tests

## Output Schema (Always Provide)

```json
{
  "result": "1-3 sentences on outcome",
  "logs": ["first 10 lines", "last 10 lines"],  
  "artifacts": ["paths to build products, screenshots, test logs"],
  "notes": ["decisions with doc links"],
  "next": ["bullet follow-ups"],
  "consent_needed": ["any high-impact actions pending"]
}
```

## Implementation Workflow (Canonical)

1. **Project scan**: `discover_projs`, `list_schemes`, `list_sims`
2. **Documentation**: sosumi/context7 lookups for unknown APIs
3. **Code**: Small focused edits via desktop-commander
4. **Build**: `build_sim` → fix warnings before proceeding
5. **Run & observe**: `build_run_sim` → attach logs → stop capture
6. **Test**: `test_sim` + UI tests where UI changed
7. **Accessibility sweep**: Test light/dark, large text, VoiceOver
8. **Cleanup**: Remove temp files, stop log capture
9. **Report**: Structured summary with next steps

## Worktree-Specific Simulator Configuration

**⚠️ IMPORTANT: This section is specific to the `feat/swift-markdown-migration` worktree.**
**When working in other worktrees/branches, remove or update this section accordingly.**

**This Worktree**: `feat/swift-markdown-migration`
**Dedicated Simulator**: `NoteChat-MarkdownUI`
**Simulator UUID**: `2E9235D3-A2E7-492A-B993-F903C0FB6BEE`
**Purpose**: Dedicated simulator for Swift Markdown UI migration work to avoid conflicts with other worktrees

When building/testing in this worktree, **ALWAYS** use this specific simulator:
```bash
# List simulators to verify it's available
xcrun simctl list devices | grep NoteChat-MarkdownUI

# Boot simulator if needed
xcrun simctl boot 2E9235D3-A2E7-492A-B993-F903C0FB6BEE

# Use in xcodebuild commands
xcodebuild -scheme NoteChat -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=2E9235D3-A2E7-492A-B993-F903C0FB6BEE' \
  build

# Use in xcodebuildmcp commands (if available)
xcodebuildmcp.build_run_sim({
  scheme: "NoteChat",
  simulatorId: "2E9235D3-A2E7-492A-B993-F903C0FB6BEE"
})
```

**Recovery**: If simulator is deleted or unavailable, recreate with:
```bash
xcrun simctl create "NoteChat-MarkdownUI" "iPhone 16 Pro"
# Then update this UUID in CLAUDE.md
```

**Reminder**: When switching to work in other worktrees (main, other feature branches), remove or update this simulator configuration section to avoid confusion.

## Simulator Refresh Workflow (After Significant Changes)

**Important**: Reuse existing simulator. Do not create new devices unless user asks.

1. **Build**: `xcodebuildmcp.build_sim` with booted simulator UUID
2. **Get path**: `get_sim_app_path` for built app location
3. **Install**: `install_app_sim` on same simulator
4. **Launch**: `launch_app_sim` with bundle ID
5. **Logs** (optional): `start_sim_log_cap` → `stop_sim_log_cap`

**Handle Issues**:
- If "Requires newer iOS": Use booted runtime or rebuild for that version
- If "Launching..." hangs: Delete app, restart simulator, reinstall

## Pitfalls to Avoid

- Never assume scheme/simulator names → always list explicitly
- Never block main thread → use async/await patterns
- Never skip HIG/accessibility checks → test Dynamic Type, dark mode
- Never ignore SwiftData relationship constraints → test cascading deletes
- Never commit API keys → use keychain storage only
- Never implement APIs without sosumi verification → check documentation first
- Never create duplicate simulators → reuse existing booted devices
- Never ignore Xcode Diagnostics warnings → address before PR
- Never skip lint/format checks → configure SwiftFormat and SwiftLint

## Dependencies

### Swift Package Manager
- **Down**: Markdown rendering (replacing MarkdownUI from old project)
- **Highlightr**: Syntax highlighting for code blocks (optional)
- **SwiftMath**: Mathematical formula rendering with native LaTeX support
- **PhosphorSwift** 2.1.0: Icon set (guarded; enable icons via Settings → Interface when needed)
  - Keep `usePhosphorIcons` disabled during development to avoid compiling unused glyphs
  - Add new Phosphor symbols incrementally and document them here as they ship

### System Frameworks
- SwiftUI, SwiftData, Foundation, PhotosUI for core functionality
- Network framework for HTTP requests
- Security framework for keychain operations

## Proactive Agent Mode

After any meaningful edit:
- Build → run quick tests → fix small issues immediately
- Refresh simulator app if UI or runtime behavior changed
- Capture screenshots or log snippets only when they help demonstrate the outcome or regressions
- Commit with Conventional Commit and push to main (unless disabled)
- Offer next step options: "Run full UI tests?", "Add feature?", "Clean artifacts?"
- Clean up: remove temp files, revert debug flags

## Git Workflow

- Always keep `main` deployable; use feature branches for risky work
- After major changes: commit with Conventional Commit message
- Push immediately to `origin main` or active feature branch
- Example: `feat: add OpenAI image provider` then `git push -u origin main`
- Avoid committing user-specific Xcode data (covered by .gitignore)

## Project Status Documentation

**Maintain these files**:
- `docs/TODO.md`: Current task checklist
- `porting.md`: Migration notes from ChatApp to MyChat
- `TASKS.md`: Checkbox plan with ≤8 atomic steps
- `DECISIONS.md`: Architecture decisions with doc links

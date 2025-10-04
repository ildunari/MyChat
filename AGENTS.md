# Repository Guidelines

This guide helps contributors work efficiently in this SwiftUI iOS project.

## iOS 26 Liquid Glass Playbook (2025 update for agents)
_Added October 2025 to provide post-cutoff guidance for iOS 26. The following section is the full Liquid Glass playbook so every agent can execute Xcode 26 workstreams accurately._

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


## Project Structure & Module Organization
- `NoteChat/`: App code — views (`ChatView.swift`, `SettingsView.swift`, `ContentView.swift`), services (`NetworkClient.swift`, `KeychainService.swift`), providers (`AIProvider.swift`, `OpenAIProvider.swift`, `OpenAIImageProvider.swift`), models (`Models.swift`, `Item.swift`), app entry (`NoteChatApp.swift`), config (`Info.plist`), assets (`Assets.xcassets/`), entitlements.
- `NoteChatTests/`: Unit tests (XCTest) - TO BE CREATED
- `NoteChatUITests/`: UI tests (XCUITest) - TO BE CREATED
- `NoteChat.xcodeproj/`: Xcode project
- `NoteChat.xctestplan`: Test plan - TO BE CREATED

## Build, Test, and Development Commands
- Open in Xcode: `open NoteChat.xcodeproj`.
- Build (CLI): `xcodebuild -project NoteChat.xcodeproj -scheme NoteChat build`.
- Run tests (CLI): `xcodebuild test -project NoteChat.xcodeproj -scheme NoteChat -destination 'platform=iOS Simulator,name=iPhone 16'`.
- Run a specific test: `xcodebuild test -only-testing:NoteChatTests/YourTestName …` (adjust names). Use `xcrun simctl list devices` to pick an available simulator.

## Parallel Branch & Build Strategy
- **Separate worktrees or clones**: keep each branch in its own folder (`git worktree add ../NoteChat-main main`, `git worktree add ../NoteChat-notes feat/notes-ai-workspace`) so agents can work concurrently without constant checkouts.
- **Unique DerivedData per branch**: pass `-derivedDataPath ~/DerivedData/notechat-<branch>` (or set Xcode's Derived Data location) before running builds/tests to prevent cache corruption.
- **Unique simulator per worktree**: Each worktree should use its own dedicated simulator to prevent conflicts:
  - **This worktree** (`NoteChat-chat-feature`): Use `NoteChat-Test-160630` (UUID: `338A0A25-078B-4918-803E-7B48D8AFF77D`)
  - Always reference this simulator by UUID in build commands
  - See `.simulator-id` file for quick reference
  - Recovery: If deleted, recreate with `xcrun simctl create "NoteChat-Test-160630" "iPhone 16 Pro Max"` and update `.simulator-id`
- **Announce long builds**: when you kick off `xcodebuild`/`build_run_sim`, mention the branch and derived data path in your update so teammates can pause other builds; call out when the run finishes.
- **Simulator coordination**: reuse the existing iPhone 16 simulator; only one agent should hold it for UI tests at a time. If you must reset, note it in the hand-off.
- **Record test coverage**: after completing your work, document which tests/smoke flows you executed (or skipped) so the next agent knows what remains.
- **Cache recovery**: if you hit `disk I/O error` on the shared DerivedData, delete that branch's folder (e.g. `rm -rf ~/Library/Developer/Xcode/DerivedData/NoteChat-*`) and rebuild using your branch-specific path.
- **Worktree requests**: when a lead says “start a worktree” (any wording), do the following by default:
  1. Confirm which branch to base from and the feature name.
  2. Create the worktree (`git worktree add ../NoteChat-<slug> <base>`) and announce the path so others can find it.
  3. Set/record a unique DerivedData location for that worktree and reuse it for all builds/tests until the worktree is closed.
  4. Log the active worktree and derived data path in plans, status updates, summaries, and compact responses so future steps inherit the context.
  5. Avoid touching `main` (or the base branch) while inside the feature worktree unless explicitly instructed.
- **Finish strong**: when wrapping a task, offer optional follow-ups (e.g., extra polish, merge + squash, regression run) and be ready to execute whichever option the lead picks.
- **/compact etiquette**: every /compact reply should start with the current worktree/branch and derived data path; never introduce new code edits in that compressed message.

## Project Status & Docs
- **Migration Notes**: `porting.md` (migration from ChatApp to NoteChat)
- **Rolling TODO**: `docs/TODO.md` (checklist; keep fresh)

Update flow per session:
- Read `porting.md` for migration status
- Pick TODOs from `docs/TODO.md` when created
- After changes: update Status Snapshot + Decision Log; adjust TODOs
- Include test notes and screenshots in your summary output

## Coding Style & Naming Conventions
- Indentation: 4 spaces; trim trailing whitespace.
- Swift: camelCase for vars/functions; PascalCase for types; one primary type per file.
- View files end with `View` (e.g., `SettingsView.swift`). Use `// MARK:` to group sections and extensions.
- Prefer value types (`struct`), dependency injection via initializers, and immutable state where practical.

## Testing Guidelines
- Frameworks: XCTest + XCUITest. Keep tests fast and isolated from network; mock `NetworkClient`.
- Naming: Mirror target type with `Tests` suffix (e.g., `NetworkClientTests`). UI tests live in `NoteChatUITests`.
- Coverage: Aim ≥80% for core services (`NetworkClient`, `KeychainService`). Use the provided `.xctestplan` for full-suite runs.

## Commit & Pull Request Guidelines
- Use Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`.
- PRs include: concise summary, scope, before/after screenshots for UI changes, test steps, linked issues, and potential risks/roll-back plan.

## Security & Configuration Tips
- Never hardcode API keys; store secrets with `KeychainService` and expose configuration via Settings.
- Do not commit secrets or personal data; review `Info.plist` diffs carefully.
- Network code belongs in `NetworkClient`; add timeouts, error handling, and avoid blocking the main thread.

## Agent Behavior (Xcode & MCP)
- Control loop: Plan → Ask (if missing context) → Execute (small, safe batches) → Verify (build/test pass + logs) → Summarize → Confirm for high‑impact actions.
- Tool routing (use in this order):
  - `XcodeBuildMCP`: primary for build/test/run, simulators, logs. Prefer:
    - List sims: `list_sims` → pick available iOS version.
    - Build: `build_sim` or `build_macos` with `scheme=NoteChat`.
    - Run on sim: `build_run_sim` (set `simulatorName='iPhone 16'` or discover via `list_sims`).
    - Logs: `start_sim_log_cap` / `stop_sim_log_cap`; screenshots via `screenshot` when debugging UI.
  - `Context7` (docs retrieval): resolve library IDs, then fetch focused docs. Examples:
    - `resolve-library-id('down')` → `get-library-docs(topic='markdown parsing', tokens=4000)`.
    - `resolve-library-id('NSHipster/sosumi.ai')` → `get-library-docs(topic='swift examples', tokens=4000)`.
  - Desktop Commander: fallback for local file ops only (never external writes without consent).
- Documentation hygiene: prefer Apple Developer docs; augment with Context7 and the `sosumi.ai` repo for Apple‑platform nuances; cite sources in summaries when used.
- Safety & permissions: dry‑run first (e.g., `show_build_settings`), confirm before Level ≥3 actions (launching, installing, deleting, system changes). Provide previews and clear revert steps.
- Pitfalls to avoid: assuming a specific simulator, running CocoaPods/Fastlane if not present, modifying signing without confirmation, or blocking the main thread in SwiftUI.
- Output contract for actions: include `plan`, `commands`, `artifacts` (e.g., build paths, screenshots), `next`, and `consent_needed`.

### Git Workflow
- Always keep `main` deployable. Use feature branches for risky work.
- After any major change or addition: commit with a Conventional Commit message and push immediately to `origin main` (or the active feature branch, then PR to `main`).
- Example: `feat: integrate Down markdown parser` then `git push -u origin main`.
- Avoid committing user-specific Xcode data; `.gitignore` covers common noise (DerivedData, `xcuserdata`, logs).

## Xcode UI Guidance Mode
- Default to highly detailed, user-facing instructions for any Xcode action.
- Always include: exact menu path (e.g., `File → Packages → Reset Package Caches`), the sidebar/toolbar location, tab names, button shapes/labels (e.g., blue “Add” button with plus icon), and what to expect on screen.
- Describe the left navigator (project navigator icon: folder), center editor tabs (Info, Build Settings, Build Phases, Package Dependencies), and the right inspector (Option-⌘-1).
- For target settings: tell the user to select the project (blue icon), then the target under “TARGETS”, then the tab (e.g., Build Settings), and where the search field is.
- When removing items from build phases: specify the exact phase (“Copy Bundle Resources”), how to expand it (twist-down triangle), how to select an item, and to press Delete to remove.
- When adding items: specify the plus button at the bottom of the list, the search field, the product name, and the expected item (e.g., “PhosphorSwift” library) to add.

## Agent Role & Responsibilities
- You are the Apple-Stack Agent for this iOS app: plan, verify, implement, test, and maintain. Never invent APIs; verify Apple APIs with `sosumi` and libraries with `context7` before coding. Prefer Swift 6 strict concurrency and XCTest/Swift Testing where appropriate. Align UI with Apple HIG and SF Symbols.

## Smart Control Loop
- Plan: Break work into ≤8 atomic steps; keep a live plan via the `update_plan` tool.
- Verify: Use `sosumi.searchAppleDocumentation` and `context7.get-library-docs` for any unfamiliar API.
- Act: Make small, reversible edits; build and run on a simulator first.
- Test: Run unit/UI tests; capture failures and screenshots.
- Clean: Remove temporary artifacts and debug flags.
- Report: Summarize results with commands run, artifacts, next steps.

## Live Plan & Updates (Always-On)

To keep the human in the loop at all times, follow these rules in every session:

- Start With a Plan: Before running tools or editing files, post a short plan (5–8 bullets) in chat. Mark exactly one step as in_progress. Use `update_plan` to keep it live.
- Maintain a TODO: Alongside the plan, list the concrete TODO items you will complete. Update statuses as you go (completed/in_progress/pending).
- Progress Pings: For long operations (builds, tests, multi‑file patches), post brief 1–2 sentence progress updates so the user knows what’s happening.
- Summaries: After changes, summarize what changed, where, and why, with paths and any artifacts (build logs, screenshots). Include immediate next steps.
- Ask vs Act: Ask only when a decision would materially change behavior, dependencies, or migration direction. Otherwise, proceed and report.
- Exceptions: For truly trivial actions (single quick read or one‑liner), you may combine plan + result in one message—but still state the mini‑plan first.

## MCP Tooling & Routing
- XcodeBuildMCP: Primary for build/test/run/simulators/logs.
  - Discover: `discover_projs` → `list_schemes` (use `NoteChat`) → `list_sims`.
  - Build/Run: `build_sim` / `build_run_sim` with explicit simulator (e.g., `iPhone 16`).
  - Logs/UI: `start_sim_log_cap` → `stop_sim_log_cap`; `screenshot`, `tap`, `gesture`, `type_text` for UI automation.
- Xcode Diagnostics MCP: Fast visibility into errors/warnings from the latest build logs.
  - List projects: `xcode-diagnostics.get_xcode_projects()` → pick the NoteChat entry.
  - Fetch diagnostics: `xcode-diagnostics.get_project_diagnostics({ project_dir_name: "<DerivedDataName>", include_warnings: true })`.
  - Use when: builds produce errors/warnings; after CI runs; before PR to ensure zero critical issues.
  - Act on output: prioritize errors, address deprecations, and eliminate main-thread blockers; re-run `build_sim` to confirm.
- sosumi (Apple docs authority): Verify SwiftUI/SwiftData/URLSession/Background tasks and privacy manifest details.
- context7 (Library docs): Resolve library IDs, fetch focused docs for Down/Highlightr/SwiftMath or any new SPM packages.
- Desktop Commander: Fallback for local file ops and process control when native editing isn't enough. Keep edits minimal and diffable.
- GitHub MCP: Use for repository intel (branches, files, issues, PRs) and to validate remotes/auth. Push via standard `git` CLI; MCP ensures auth context.
- Qdrant Memory (qdrant-NoteChat): Project-scoped vector storage for patterns, decisions, and solutions.
  - Store: `qdrant-store` important fixes, patterns, architecture decisions with file:line references.
  - Retrieve: `qdrant-find` before refactoring, debugging similar issues, or implementing related features.
  - Auto-use: Store after complex implementations; retrieve before major changes.

## Zero‑Hallucination Verification
- Apple APIs: Verify with `sosumi.searchAppleDocumentation` before implementing or changing platform APIs.
- Third‑party libs: Verify with `context7.get-library-docs` and cite versions in code comments when relevant.
- Version freshness: Prefer official Apple docs; add short notes/links for architectural decisions.

## Canonical Implementation Workflow
1. Discover: `discover_projs`, `list_schemes`, `list_sims`.
2. Documentation: sosumi/context7 lookups for unknown APIs.
3. Code: Small focused edits; avoid blocking the main thread.
4. Build: `build_sim` → fix warnings before proceeding.
5. Run & Observe: `build_run_sim` → attach logs → `stop_sim_log_cap`.
6. Test: `xcodebuild test -project NoteChat.xcodeproj -scheme NoteChat -destination 'platform=iOS Simulator,name=iPhone 16'` (or use `NoteChat.xctestplan`); include UI tests where UI changed.
7. Accessibility: Verify Dynamic Type, dark mode, VoiceOver.
8. Cleanup: Remove temp files/log captures.
9. Report: Structured summary with artifacts and next steps.

## GitHub Updates (MCP‑Authenticated Pushes)
- Prepare commit:
  - `git add -A`
  - `git commit -m "feat: <concise summary>"`
- Push (direct or via feature branch):
  - Direct to main: `git push origin main`
  - Feature branch: `git checkout -b feat/<topic>` → commit → `git push -u origin feat/<topic>`
- Authentication: The GitHub MCP integration provides the token; pushes via `git` use this identity automatically.
- Verify with GitHub MCP (optional):
  - Repo info: `github_repo_info(repo_url: "https://github.com/<org>/<repo>")`
  - Branches: `github_list_branches(...)`
  - PR status: `github_list_pulls(...)`
- Open PR (if using feature branches): create via GitHub UI or your CLI; link to build/test artifacts and include screenshots for UI changes.

## Simulator Refresh (After Significant Changes)
- Reuse existing simulator. Do not create new devices unless user asks.
- Flow (assumes an already booted device from `list_sims`):
  1) Build: `xcodebuildmcp.build_sim({ projectPath: "<proj>", scheme: "NoteChat", simulatorId: "<BOOTED_UUID>" })`
  2) Path: `get_sim_app_path({ projectPath: "<proj>", scheme: "NoteChat", platform: 'iOS Simulator', simulatorId: '<BOOTED_UUID>' })`
  3) Install: `install_app_sim({ simulatorUuid: '<BOOTED_UUID>', appPath: '<from step 2>' })`
  4) Launch: `launch_app_sim({ simulatorUuid: '<BOOTED_UUID>', bundleId: 'com.yourcompany.NoteChat' })`
  5) Optional logs: `start_sim_log_cap({ simulatorUuid: '<BOOTED_UUID>', bundleId: 'com.yourcompany.NoteChat', captureConsole: true })` → `stop_sim_log_cap(...)` and attach head/tail.
- Handle pitfalls proactively:
  - If "Requires newer iOS": pick the booted runtime or rebuild for that runtime version; don't spin up a new device.
  - If "Launching…" hangs: delete the app on the same device, restart that simulator, then reinstall/launch.
  - Never create duplicate sims; prefer the single booted device.

## Proactive Agent Mode (Default)
- After any meaningful edit:
  - Build → run quick tests (`xcodebuild test` or `test_sim`), fix small issues now.
  - Refresh the simulator app if UI or runtime behavior changed (see section above).
  - Capture 1–2 screenshots and 10/10 log lines for the report.
  - Commit with Conventional Commit and push to `main` (or feature branch) automatically unless user disabled auto‑push for the task.
- Offer "next step" options unprompted, e.g., "Run full UI tests?", "Add Down markdown parser?", "Add reset data toggle?", and be ready to execute.
- Clean up artifacts: remove temporary files, revert debug flags, and ensure `.gitignore` noise isn't added.

## Pitfalls to Avoid
- Assuming scheme/simulator names: always list explicitly and pick a concrete simulator.
- Blocking the main thread: keep networking and heavy work off the main actor.
- Skipping HIG/accessibility: validate Dynamic Type, dark mode, and VoiceOver.
- SwiftData integrity: maintain relationships and test cascading deletes.
- Secrets: never commit API keys; rely on `KeychainService` and Settings.

## Output Contract for Tasks
- Plan: current steps and status.
- Commands: exact invocations used.
- Artifacts: paths to builds, logs, screenshots.
- Next: immediate follow‑ups and risks.
- Consent needed: any high‑impact actions awaiting approval.

---

## Codebase Map (Repo‑Specific)

- App Entry
  - `NoteChat/NoteChatApp.swift` — Configures SwiftData `ModelContainer` with a persistent store in Application Support and a one‑time recovery path if the SQLite store is corrupted.

- Data Models (SwiftData)
  - `NoteChat/Models.swift`
    - `Chat { id, title, createdAt, messages[] }` (cascade delete to messages)
    - `Message { id, role(user|assistant), content, createdAt, chat }`
    - `AppSettings { defaultProvider, defaultModel, defaultSystemPrompt, defaultTemperature, defaultMaxTokens, <enabled models per provider>, interfaceTheme, interfaceFontStyle, interfaceTextSizeIndex, chatBubbleColorID, promptCachingEnabled, useWebCanvas }`

- Views (SwiftUI)
  - `NoteChat/ContentView.swift` — Chat list (NavigationStack), creates initial chat on first launch.
  - `NoteChat/ChatView.swift` — Chat screen with suggestions, photo picker attachments, streaming responses, model menu in toolbar.
  - `NoteChat/AIResponseView.swift` — Segments assistant content into Markdown, Code, and Math blocks; uses Down-backed MarkdownRenderer and optional syntax highlighting.
  - `NoteChat/ChatUI.swift` — `SuggestionChips`, `InputBar` components.
  - `NoteChat/ChatStyles.swift` — Shared visual constants for chat; Markdown theming handled via Down output styling.
  - `NoteChat/MathWebView.swift` — KaTeX WebView fallback for math rendering.
  - `NoteChat/ChatCanvasView.swift` — WebCanvas feature for transcript rendering.
  - `NoteChat/SettingsView.swift` — Providers, default chat, and interface settings flows (nested screens).

- Settings & Services
  - `NoteChat/SettingsStore.swift` — ObservableObject bridging SwiftData `AppSettings` with Keychain; primes from `Env/DevSecrets.env` in Debug via `EnvLoader`.
  - `NoteChat/EnvLoader.swift` — Loads `DevSecrets.env` from bundle (Debug) to ease local development.
  - `NoteChat/KeychainService.swift` — Save/read/delete API keys securely.
  - `NoteChat/SystemPrompt.swift` — Master system prompt rules for the assistant.

- Providers & Networking
  - `NoteChat/Providers/Core/AIProvider.swift` — Chat provider protocols, including advanced + streaming interfaces.
  - `NoteChat/Providers/Core/ProviderAPIs.swift` — Key verification and model listing for OpenAI/Anthropic/Google/XAI.
  - `NoteChat/Providers/Core/ProviderCapabilities.swift` — Model capabilities configuration.
  - `NoteChat/Providers/Core/StreamingSSE.swift` — Server-sent events streaming support.
  - `NoteChat/Providers/OpenAI/OpenAIProvider.swift` — Implements OpenAI API with streaming.
  - `NoteChat/Providers/Anthropic/AnthropicProvider.swift` — Anthropic Claude implementation.
  - `NoteChat/Providers/Google/GoogleProvider.swift` — Google Gemini implementation.
  - `NoteChat/Providers/XAI/XAIProvider.swift` — X.AI Grok implementation.
  - `NoteChat/OpenAIImageProvider.swift` — Image generation via OpenAI.
  - `NoteChat/NetworkClient.swift` — Shared URLSession with sane timeouts; `get`/`postJSON` helpers.

- UI Components & Helpers
  - `NoteChat/Icons.swift` — SF Symbol icon helpers.
  - `NoteChat/ThemeTokens.swift` — Theme system with color palettes.
  - `NoteChat/FlowLayout.swift` — Custom layout for flowing content.
  - `NoteChat/ToolCallBubble.swift` — Tool call display component.
  - `NoteChat/ModelCapabilities.swift` — Model-specific capabilities and limits.

- Assets & Config
  - `NoteChat/Assets.xcassets/` — App icons and colors.
  - `NoteChat/Info.plist` — App metadata and capabilities.

- Tests (TO BE CREATED)
  - `NoteChatTests/*` — Unit test target scaffold.
  - `NoteChatUITests/*` — UI test target scaffold.
  - `NoteChat.xctestplan` — Test plan for coordinated runs.

## Build & Dependencies Snapshot

### Package Management Policy (SPM)
- Always add/modify Swift packages via Xcode’s UI: `File → Add Packages…`.
- Do not add packages via terminal (`swift package`, `xcodebuild -resolvePackageDependencies`) or by hand‑editing `project.pbxproj`/`Package.resolved`.
- Pin versions using Xcode’s “Dependency Rule” controls; prefer “Up to Next Major Version” unless the task specifies otherwise. For Down we currently track branch `master`.
- Troubleshooting only through Xcode: use `File → Packages → Reset Package Caches`, then `Resolve Package Versions`. Never delete `DerivedData` or caches from scripts without confirmation.
- After adding a package, explicitly add the required product to the `NoteChat` target under `Frameworks, Libraries, and Embedded Content`.

- Schemes: `NoteChat` (primary)
- SPM Dependencies (present):
  - **Down** (branch master): Markdown parsing and rendering (replaced MarkdownUI)
  - **HighlighterSwift** (product: Highlighter) 1.1.7: Code syntax highlighting (optional)
  - **SwiftMath** 1.7.3: Mathematical formula rendering with native LaTeX support
  - **PhosphorSwift** 2.1.0: Icon set (optional)
    - Default builds should rely on SF Symbol fallbacks (`SettingsStore.usePhosphorIcons = false`)
    - When adding new Phosphor glyphs, flip the `Phosphor Icon Pack` toggle in Settings, verify the icon, then document it below
    - Keep this bullet updated with newly enabled Phosphor identifiers so future builds opt-in intentionally
- Quick build check: `xcodebuild -project NoteChat.xcodeproj -scheme NoteChat -destination 'generic/platform=iOS Simulator' build`

## Key Flows

- Chat Send
  1) User types in `InputBar` → `

## Tooling Expectations
- Use the built-in Codex editing tools for file modifications whenever possible.
- If additional filesystem automation is required, prefer Desktop Commander (DC) commands for reads, writes, searches, and targeted edits.
- Avoid ad-hoc scripting (e.g., inline Python editors) for routine edits; reserve them only when explicitly requested.

# Repository Guidelines

This guide helps contributors work efficiently in this SwiftUI iOS project.

## Project Structure & Module Organization
- `MyChat/`: App code — views (`ChatView.swift`, `SettingsView.swift`, `ContentView.swift`), services (`NetworkClient.swift`, `KeychainService.swift`), providers (`AIProvider.swift`, `OpenAIProvider.swift`, `OpenAIImageProvider.swift`), models (`Models.swift`, `Item.swift`), app entry (`MyChatApp.swift`), config (`Info.plist`), assets (`Assets.xcassets/`), entitlements.
- `MyChatTests/`: Unit tests (XCTest) - TO BE CREATED
- `MyChatUITests/`: UI tests (XCUITest) - TO BE CREATED
- `MyChat.xcodeproj/`: Xcode project
- `MyChat.xctestplan`: Test plan - TO BE CREATED

## Build, Test, and Development Commands
- Open in Xcode: `open MyChat.xcodeproj`.
- Build (CLI): `xcodebuild -project MyChat.xcodeproj -scheme MyChat build`.
- Run tests (CLI): `xcodebuild test -project MyChat.xcodeproj -scheme MyChat -destination 'platform=iOS Simulator,name=iPhone 16'`.
- Run a specific test: `xcodebuild test -only-testing:MyChatTests/YourTestName …` (adjust names). Use `xcrun simctl list devices` to pick an available simulator.

## Project Status & Docs
- **Migration Notes**: `porting.md` (migration from ChatApp to MyChat)
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
- Naming: Mirror target type with `Tests` suffix (e.g., `NetworkClientTests`). UI tests live in `MyChatUITests`.
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
    - Build: `build_sim` or `build_macos` with `scheme=MyChat`.
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
  - Discover: `discover_projs` → `list_schemes` (use `MyChat`) → `list_sims`.
  - Build/Run: `build_sim` / `build_run_sim` with explicit simulator (e.g., `iPhone 16`).
  - Logs/UI: `start_sim_log_cap` → `stop_sim_log_cap`; `screenshot`, `tap`, `gesture`, `type_text` for UI automation.
- Xcode Diagnostics MCP: Fast visibility into errors/warnings from the latest build logs.
  - List projects: `xcode-diagnostics.get_xcode_projects()` → pick the MyChat entry.
  - Fetch diagnostics: `xcode-diagnostics.get_project_diagnostics({ project_dir_name: "<DerivedDataName>", include_warnings: true })`.
  - Use when: builds produce errors/warnings; after CI runs; before PR to ensure zero critical issues.
  - Act on output: prioritize errors, address deprecations, and eliminate main-thread blockers; re-run `build_sim` to confirm.
- sosumi (Apple docs authority): Verify SwiftUI/SwiftData/URLSession/Background tasks and privacy manifest details.
- context7 (Library docs): Resolve library IDs, fetch focused docs for Down/Highlightr/SwiftMath or any new SPM packages.
- Desktop Commander: Fallback for local file ops and process control when native editing isn't enough. Keep edits minimal and diffable.
- GitHub MCP: Use for repository intel (branches, files, issues, PRs) and to validate remotes/auth. Push via standard `git` CLI; MCP ensures auth context.

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
6. Test: `xcodebuild test -project MyChat.xcodeproj -scheme MyChat -destination 'platform=iOS Simulator,name=iPhone 16'` (or use `MyChat.xctestplan`); include UI tests where UI changed.
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
  1) Build: `xcodebuildmcp.build_sim({ projectPath: "<proj>", scheme: "MyChat", simulatorId: "<BOOTED_UUID>" })`
  2) Path: `get_sim_app_path({ projectPath: "<proj>", scheme: "MyChat", platform: 'iOS Simulator', simulatorId: '<BOOTED_UUID>' })`
  3) Install: `install_app_sim({ simulatorUuid: '<BOOTED_UUID>', appPath: '<from step 2>' })`
  4) Launch: `launch_app_sim({ simulatorUuid: '<BOOTED_UUID>', bundleId: 'com.yourcompany.MyChat' })`
  5) Optional logs: `start_sim_log_cap({ simulatorUuid: '<BOOTED_UUID>', bundleId: 'com.yourcompany.MyChat', captureConsole: true })` → `stop_sim_log_cap(...)` and attach head/tail.
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
  - `MyChat/MyChatApp.swift` — Configures SwiftData `ModelContainer` with a persistent store in Application Support and a one‑time recovery path if the SQLite store is corrupted.

- Data Models (SwiftData)
  - `MyChat/Models.swift`
    - `Chat { id, title, createdAt, messages[] }` (cascade delete to messages)
    - `Message { id, role(user|assistant), content, createdAt, chat }`
    - `AppSettings { defaultProvider, defaultModel, defaultSystemPrompt, defaultTemperature, defaultMaxTokens, <enabled models per provider>, interfaceTheme, interfaceFontStyle, interfaceTextSizeIndex, chatBubbleColorID, promptCachingEnabled, useWebCanvas }`

- Views (SwiftUI)
  - `MyChat/ContentView.swift` — Chat list (NavigationStack), creates initial chat on first launch.
  - `MyChat/ChatView.swift` — Chat screen with suggestions, photo picker attachments, streaming responses, model menu in toolbar.
  - `MyChat/AIResponseView.swift` — Segments assistant content into Markdown, Code, and Math blocks; uses Down-backed MarkdownRenderer and optional syntax highlighting.
  - `MyChat/ChatUI.swift` — `SuggestionChips`, `InputBar` components.
  - `MyChat/ChatStyles.swift` — Shared visual constants for chat; Markdown theming handled via Down output styling.
  - `MyChat/MathWebView.swift` — KaTeX WebView fallback for math rendering.
  - `MyChat/ChatCanvasView.swift` — WebCanvas feature for transcript rendering.
  - `MyChat/SettingsView.swift` — Providers, default chat, and interface settings flows (nested screens).

- Settings & Services
  - `MyChat/SettingsStore.swift` — ObservableObject bridging SwiftData `AppSettings` with Keychain; primes from `Env/DevSecrets.env` in Debug via `EnvLoader`.
  - `MyChat/EnvLoader.swift` — Loads `DevSecrets.env` from bundle (Debug) to ease local development.
  - `MyChat/KeychainService.swift` — Save/read/delete API keys securely.
  - `MyChat/SystemPrompt.swift` — Master system prompt rules for the assistant.

- Providers & Networking
  - `MyChat/Providers/Core/AIProvider.swift` — Chat provider protocols, including advanced + streaming interfaces.
  - `MyChat/Providers/Core/ProviderAPIs.swift` — Key verification and model listing for OpenAI/Anthropic/Google/XAI.
  - `MyChat/Providers/Core/ProviderCapabilities.swift` — Model capabilities configuration.
  - `MyChat/Providers/Core/StreamingSSE.swift` — Server-sent events streaming support.
  - `MyChat/Providers/OpenAI/OpenAIProvider.swift` — Implements OpenAI API with streaming.
  - `MyChat/Providers/Anthropic/AnthropicProvider.swift` — Anthropic Claude implementation.
  - `MyChat/Providers/Google/GoogleProvider.swift` — Google Gemini implementation.
  - `MyChat/Providers/XAI/XAIProvider.swift` — X.AI Grok implementation.
  - `MyChat/OpenAIImageProvider.swift` — Image generation via OpenAI.
  - `MyChat/NetworkClient.swift` — Shared URLSession with sane timeouts; `get`/`postJSON` helpers.

- UI Components & Helpers
  - `MyChat/Icons.swift` — SF Symbol icon helpers.
  - `MyChat/ThemeTokens.swift` — Theme system with color palettes.
  - `MyChat/FlowLayout.swift` — Custom layout for flowing content.
  - `MyChat/ToolCallBubble.swift` — Tool call display component.
  - `MyChat/ModelCapabilities.swift` — Model-specific capabilities and limits.

- Assets & Config
  - `MyChat/Assets.xcassets/` — App icons and colors.
  - `MyChat/Info.plist` — App metadata and capabilities.

- Tests (TO BE CREATED)
  - `MyChatTests/*` — Unit test target scaffold.
  - `MyChatUITests/*` — UI test target scaffold.
  - `MyChat.xctestplan` — Test plan for coordinated runs.

## Build & Dependencies Snapshot

### Package Management Policy (SPM)
- Always add/modify Swift packages via Xcode’s UI: `File → Add Packages…`.
- Do not add packages via terminal (`swift package`, `xcodebuild -resolvePackageDependencies`) or by hand‑editing `project.pbxproj`/`Package.resolved`.
- Pin versions using Xcode’s “Dependency Rule” controls; prefer “Up to Next Major Version” unless the task specifies otherwise. For Down we currently track branch `master`.
- Troubleshooting only through Xcode: use `File → Packages → Reset Package Caches`, then `Resolve Package Versions`. Never delete `DerivedData` or caches from scripts without confirmation.
- After adding a package, explicitly add the required product to the `MyChat` target under `Frameworks, Libraries, and Embedded Content`.

- Schemes: `MyChat` (primary)
- SPM Dependencies (present):
  - **Down** (branch master): Markdown parsing and rendering (replaced MarkdownUI)
  - **HighlighterSwift** (product: Highlighter) 1.1.7: Code syntax highlighting (optional)
  - **SwiftMath** 1.7.3 and/or **iosMath**: Mathematical formula rendering (optional)
  - **PhosphorSwift** 2.1.0: Icon set
- Quick build check: `xcodebuild -project MyChat.xcodeproj -scheme MyChat -destination 'generic/platform=iOS Simulator' build`

## Key Flows

- Chat Send
  1) User types in `InputBar` → `ChatView.send()` inserts a user `Message`.
  2) Settings resolved from `SettingsStore` → provider constructed (OpenAI/Anthropic/Google/XAI).
  3) Messages mapped to `AIMessage` (text + optional image parts via `PhotosPicker`).
  4) Streaming path updates `streamingText`; final reply is inserted as assistant `Message`.
  5) Title autoupdates from first user message if default.

- Settings
  - `SettingsView` edits `SettingsStore` fields; on save, writes SwiftData + Keychain.
  - Providers screen verifies API keys and lists models via `ProviderAPIs`.

- Rendering
  - Markdown (Down → AttributedString with tinted links and inline-code styling), code highlighting (Highlightr/Highlighter when available, monospaced fallback), math via iosMath or SwiftMath branch with KaTeX fallback.

## Migration Notes (from ChatApp to MyChat)

- **Critical**: Replace MarkdownUI with Down package in AIResponseView.swift
- **Dependencies**: Add Down via SPM, optionally add Highlightr and SwiftMath
- **Bundle ID**: Update to use MyChat identifiers
- See `porting.md` for complete migration checklist

## Troubleshooting Notes

- Provider streaming errors are surfaced with friendly messages (401/403/404/429/5xx).
- If chat persistence breaks, `MyChatApp` attempts a one‑time SQLite store cleanup and re‑init.
- If math doesn't render, ensure optional math packages are installed or WebView fallback is working.
- No API keys? In Debug, add values to `Env/.env` (copied to bundle as `DevSecrets.env`) to prime Keychain on first run.

## Immediate TODOs (from porting.md)

- [x] Add Down package dependency via SPM
- [x] Update AIResponseView.swift to use Down instead of MarkdownUI
- [x] Update ChatStyles.swift (MarkdownUI theme removed)
- [x] Add Highlighter adapter path (Highlightr/Highlighter)
- [x] Fix math renderer tiers (iosMath → label, SwiftMath → KaTeX fallback, else KaTeX)
- [x] Build project successfully on simulator
- [ ] Test basic chat functionality with API keys
- [ ] Add UI polish for code themes (optional)
- [ ] Create test targets (MyChatTests, MyChatUITests)
- [ ] Create MyChat.xctestplan

## Decision Log

- 2025-09-08: Migrated from ChatApp to MyChat, pending Down markdown integration
- Package change: MarkdownUI → Down for markdown rendering

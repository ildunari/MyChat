# TODO — MyChat (Observation Migration)

- [x] Set iOS deployment target to 17.0 (Observation requires iOS 17+/macOS 14+)
- [x] Replace `MyChatApp.swift` to create one `SettingsStore` and inject via `.environment(...)`
- [x] Remove Combine usage specific to `SettingsStore` (no `ObservableObject/@Published`)
- [x] Update `SettingsView` and nested views to read via `@Environment(SettingsStore.self)`
- [x] Use `@Bindable var store = store` in bodies where bindings like `$store.*` are needed
- [x] Update `ContentView` to present `SettingsView()` (no custom context injection)
- [x] Fix `SettingsView` preview with in-memory `ModelContainer` and `.environment(store)`
- [x] Build project; resolve DerivedData lock by clearing `XCBuildData` and retry

Next

- [ ] Audit other views for any lingering `SettingsStore` references (none found beyond SettingsView)
- [ ] Consider moving UIPlayground types off Combine or isolate with `#if DEBUG`
- [ ] Run on simulator (iPhone 16) and sanity-check settings flows
- [ ] Add unit tests scaffolding for `SettingsStore` persistence when test targets are created


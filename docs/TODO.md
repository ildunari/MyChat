# TODO (Rolling)

Updated: 2025-09-09

- [x] Replace MarkdownUI with Down and wire renderer
- [x] Add code highlighting adapter (Highlightr/Highlighter) with fallback
- [x] Fix math renderer tiers (iosMath preferred; SwiftMath branch compiles; KaTeX fallback)
- [x] Guard WebCanvas asset loading; no crash when absent
- [ ] Add unit test target `MyChatTests` (NetworkClient + parser tests)
- [ ] Add UI test target `MyChatUITests`
- [ ] Create `MyChat.xctestplan`
- [ ] Code theme polish (choose light/dark code themes)
- [ ] Verify math with iosMath installed (block + inline)
- [ ] Remove temporary `Combine` imports once Observation migration completes
- [ ] Integrate SwiftMath inline view to replace placeholder in `AIResponseView`


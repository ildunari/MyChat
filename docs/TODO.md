# TODO (Rolling)

Updated: 2025-09-09

- [x] Replace MarkdownUI with Down and wire renderer
- [x] Add code highlighting adapter (Highlightr/Highlighter) with fallback
- [x] Fix math renderer tiers (SwiftMath with KaTeX fallback)
- [x] Guard WebCanvas asset loading; no crash when absent
- [ ] Add unit test target `MyChatTests` (NetworkClient + parser tests)
- [ ] Add UI test target `MyChatUITests`
- [ ] Create `MyChat.xctestplan`
- [ ] Code theme polish (choose light/dark code themes)
- [ ] Verify math rendering with SwiftMath and KaTeX fallback (block + inline)
- [x] Remove temporary `Combine` imports once Observation migration completes
- [x] Integrate SwiftMath inline view to replace placeholder in `AIResponseView`

## Notes (new)

- [x] Add SwiftData models: `Note`, `NoteFolder`
- [x] Notes Home with movable sections (Folders/Media toggle, Quick Actions, All Notes)
- [x] Search across note titles and content
- [x] Markdown editor MVP with formatting toolbar + preview
- [x] AI editing engine skeleton (search/replace, regex, minimal unified diff)
- [ ] Folder management (rename, delete, move)
- [ ] Import/attachments (images, audio)
- [ ] Evaluate integrating SwiftDown editor via SPM
- [ ] Unit tests for `NoteEditingEngine`

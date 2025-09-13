
# SevenThemes.xcassets

Drag this .xcassets folder into your Xcode project.
Each theme has prefixed color names (e.g., `Saffron-Accent`, `Teal-Bg`).

**Light/Dark:** Most colors are dynamic; Accent/Fill/Press are identical in both modes by design.
`*-AccentTint` swaps to a darker tint variant in Dark.

**Status colors** are duplicated in every theme group for convenience:
`*-SuccessFill` #2F855A · `*-WarningFill` #A05B00 · `*-ErrorFill` #C62828

## Example (SwiftUI)
```
let c = Color("Saffron-Accent")
let bg = Color("Saffron-Bg")
Text("Primary").padding().background(Color("Saffron-Surface"))
    .tint(Color("Saffron-Accent"))
// Primary button:
Button("Go"){}.buttonStyle(.borderedProminent).tint(Color("Saffron-AccentFill"))
```

## Mapping
- Accent: brand tint for glyphs/links/outlines
- AccentFill: filled primary buttons
- AccentPress: pressed/active shade
- AccentTint: subtle chips/selections (dynamic)
- Bg / Surface / Elevated: backgrounds
- Separator: hairline borders
- Text / TextSecondary: labels
- SuccessFill / WarningFill / ErrorFill: semantic states

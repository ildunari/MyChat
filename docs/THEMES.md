# App Themes (Accessible Palettes)

This document records seven calm‑but‑characterful iOS color themes and the guardrails we apply. The app’s `ThemeTokens` maps these palettes into SwiftUI colors (`bg`, `surface`, `surfaceElevated`, `accent`, `accentSoft`, text, borders, shadow). All views inherit tokens from the environment via `AppThemeView`.

See Apple HIG: Color, Materials, Buttons, Dark Mode for best practices.

Palettes available in Settings → Interface → Appearance → Theme Palette:

1) Saffron & Graphite
   - Accent #FF8A3D, Fill #AA4D00, Press #9A3F00
   - AccentTint #FFE7D3 (Dark: #2B1A10)
   - Neutrals (Light): Bg #F8F9FB, Surface #FFFFFF, Elevated #F2F4F7

2) Teal & Slate
   - Accent #2BB8A3, Fill #0B7467, Press #085E54
   - AccentTint #DFF6F3 (Dark: #0F2A28)

3) Indigo & Sand
   - Accent/Fill #5965D3, Press #4A55B9
   - AccentTint #E4E7FF (Dark: #1A1C37)
   - Bg #FAF7F2, Surface #FFFFFF, Elevated #F4EFE8

4) Forest & Linen
   - Accent/Fill #3F7D4E, Press #32663E
   - AccentTint #DDEEE2 (Dark: #122418)
   - Bg #F7F5EF, Surface #FFFFFF, Elevated #EFECE3

5) Plum & Mist
   - Accent/Fill #7D5BA6, Press #684B8A
   - AccentTint #E9DEF4 (Dark: #20182A)
   - Bg #F7F6FA, Surface #FFFFFF, Elevated #F1EEF6

6) Rosewood & Smoke
   - Accent #C45B7F, Fill #A44D6A, Press #8F405B
   - AccentTint #F6E1EA (Dark: #2A1A22)
   - Bg #F8F8FA, Surface #FFFFFF, Elevated #F3F3F6

7) Aqua & Ink
   - Accent #2BAED2, Fill #137A92, Press #0F6174
   - AccentTint #DDF3F8 (Dark: #10242A)
   - Bg #F5FAFB, Surface #FFFFFF, Elevated #EEF6F8

Status colors (functional, independent of theme):
- SuccessFill #2F855A, WarningFill #A05B00, ErrorFill #C62828 (white on‑color).

Guidelines used:
- Use color sparingly; let neutrals do the heavy lifting.
- Keep contrast ≥ 4.5:1 for small text, ≥ 3:1 for large/icon UI.
- Preserve semantic red/amber/green for status.
- Support blur/vibrancy when placing text over materials.
- Keep accent coverage ~5–10% at rest; prefer AccentTint for selection chips.

Developer notes:
- `ThemeTokens` exposes: `bg`, `surface`, `surfaceElevated`, `accent`, `accentSoft`, `text`, `textSecondary`, `borderSoft`, `borderHard`, `shadow`, corner radii.
- The bottom DockTabBar highlight uses `tokens.accent` for the rounded selection tile; the bar itself uses `tokens.surface` and removes bottom lines.
- When adding a new section to Home, ensure it:
  - Inherits tokens via `.environment(\.tokens)` (automatic in `AppThemeView`).
  - Supports collapse/expand.
  - Supports reordering (grab handle – coming soon generalized helper).
  - Confines its scroll height (≤ 1/3 of viewport) and fits at least two rows.


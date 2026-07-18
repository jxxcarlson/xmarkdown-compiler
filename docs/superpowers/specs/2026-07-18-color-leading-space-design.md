# Color leading space — design

## Goal

Shade the leading-whitespace region of each editor line with a faint
theme-colored background band, making indentation depth easier to read. The
existing vertical indent-guide bars remain and sit on top of the band.

## Scope

- **File:** `DemoTOC+Sync/assets/editor.js` only.
- No Elm changes, no new theme field, no Elm rebundle.
- Reuses the existing `--cm-indent-guide` CSS variable (deep blue light /
  deep orange dark), so the band tracks the theme automatically.

## Behavior

- For every line, let `w` = number of leading space characters.
- If `w > 0`, the line gets a background band spanning column `0 → w` chars
  (offset by `GUIDE_OFFSET_PX` to match the guide bars), filled with the theme
  color at reduced strength:
  `color-mix(in srgb, var(--cm-indent-guide) 22%, transparent)`.
- The existing vertical guide bars (drawn for `levels = floor(w / 2) > 0`)
  render *after* the band in the same style string, so they appear on top.
- A line with 1 leading space gets a band but no bar; this is intended.

## Implementation

Extend the two existing functions:

- `indentGuideStyle(levels, w)` — prepend a band layer as the first
  `background-image`: solid fill `${w}ch 100%` at `${GUIDE_OFFSET_PX}px 0`,
  followed by the existing `levels` bar layers.
- `buildIndentGuides(state)` — decorate any line with `w > 0` (was
  `levels > 0`); pass both `levels` and `w` to `indentGuideStyle`.

Band and bars are emitted in one style string on one line decoration, so there
is no `style`-attribute merge conflict.

## Risks

- `color-mix` requires a current browser (Chrome/Safari/Firefox). Acceptable
  for this dev demo.

## Verification

Load the demo, type nested/indented source, confirm in both light and dark
themes that:
1. a faint band appears behind leading spaces,
2. the vertical guide bars still show on top,
3. the band color matches the current theme.

# Editor Indentation Guides — Design

**Date:** 2026-07-16
**Status:** Approved, ready for implementation planning

## Goal

Display faint vertical lines in the editor to make indented text easier to
read — VS Code–style indentation guides. Guide color is determined by the
active theme (light/dark).

## Decisions

| Question | Decision |
|----------|----------|
| Visual model | Line per indent level (VS Code style): a vertical line at each indent stop the line sits under; nested lines show stacked guides. |
| Indent unit | 2 spaces per level. Guides at character columns 0, 2, 4, … |
| Code/verbatim/math blocks | Show guides everywhere — no context suppression. |
| Active-level highlight | No. All guides use one uniform faint theme color. Recomputed only on document change, not on cursor movement. |

## Architecture

The feature extends the **existing theme-color pipeline** already used for
`--cm-fg` / `--cm-bg`. No new architectural mechanism is introduced — one new
color field rides the existing rails.

```
Render.Theme (indentGuide : Color)
        │  ToggleTheme  (DemoTOC+Sync/src/Main.elm)
        ▼
Ports.setThemeColors { fg, bg, indentGuide }     ← add one field
        │
        ▼
app.js  →  documentElement.style.setProperty('--cm-indent-guide', …)
        │
        ▼
editor.js  indentGuideField  reads var(--cm-indent-guide) in a per-line background
```

## Components

### 1. Editor decoration (`DemoTOC+Sync/assets/editor.js`)

Add a new CodeMirror `StateField` named `indentGuideField`, modeled on the
existing `syncHighlightField` / `markdownSyntax` fields in the same file.

- Triggers: on field `create()` and on any transaction where `tr.docChanged`.
  Between doc changes, map the existing decoration set through `tr.changes`
  (same pattern as the other fields).
- For each line: count leading spaces `w`; compute `levels = Math.floor(w / 2)`.
- If `levels > 0`, attach a `Decoration.line` whose inline `attributes.style`
  paints `levels` thin (1px) vertical bars using a comma-separated
  `background-image` of `linear-gradient`s. Each bar is positioned at character
  column `2 * i` for `i` in `0 .. levels - 1`, expressed in `ch` units, colored
  `var(--cm-indent-guide, <faint fallback>)`, with `background-repeat: no-repeat`
  and `background-size: 1px 100%`.
- Register the field in the `extensions` array inside `connectedCallback`.
- Rebuild the bundle: `node build-editor.js` (produces `assets/editor-bundle.js`,
  which `assets/index.html` actually loads).

**Alignment:** the content font is monospace (`editor.js` `.cm-content`
`font-family`), so `1ch` equals one character advance and bars land on the
character grid. `.cm-line` / `.cm-content` left padding introduces a small
constant pixel offset between the padding box (background origin) and the first
glyph; this offset is tuned by eye during verification.

**Rejected alternatives:**
- `@replit/codemirror-indentation-markers` npm package — adds a dependency and
  its color is set at construction, not driven by a CSS variable, so it does not
  fit the theme pipeline cleanly.
- Absolutely-positioned `<div>` guide widgets — more DOM churn than uniform,
  non-interactive guides require.

The background-gradient approach is the lightest option and matches the
decoration-field style already present in `editor.js`.

### 2. Theme model (`src/Render/Theme.elm`)

- Add `indentGuide : Color` to the `ThemedStyles` record type.
- Set it in `lightTheme` (a faint dark, low-alpha color) and `darkTheme`
  (a faint light, low-alpha color).

### 3. Theme push (`DemoTOC+Sync/src/Main.elm`)

- In the `ToggleTheme` handler, add
  `indentGuide = currentTheme.indentGuide |> Color.toCssString`
  to the `Ports.setThemeColors` payload record.
- Note: `Ports.setThemeColors`' record type (`DemoTOC+Sync/src/Ports.elm`)
  must gain the `indentGuide : String` field.

### 4. Port handler (`DemoTOC+Sync/assets/app.js`)

- In the `setThemeColors` subscription, add
  `document.documentElement.style.setProperty('--cm-indent-guide', colors.indentGuide);`

## Data flow / lifecycle

- On page load, `setThemeColors` is not yet fired (matches current behavior for
  `--cm-fg` / `--cm-bg`). The CSS-var **fallback** in `editor.js` keeps guides
  correct for the default (light) theme until the first `ToggleTheme`.
- On `ToggleTheme`, the new `indentGuide` value is pushed and
  `--cm-indent-guide` updates; existing decorations restyle automatically
  because they reference the CSS variable rather than a baked-in color.

## Edge cases

- Blank lines and zero-indent lines → no decoration.
- Line wrapping is enabled (`EditorView.lineWrapping`). A line-level background
  repeats under wrapped rows of the same line, giving the desired continuation
  appearance.
- Code / math / verbatim lines receive guides by design (show-everywhere).

## Testing & verification

- **Elm side** (regression net): `elm make src/XMarkdown/API.elm
  src/XMarkdown/Types.elm src/Render/Theme.elm --output=/dev/null` and
  `npx elm-test` must pass. The compiler enforces the new `ThemedStyles` field
  and the `setThemeColors` payload/record shape.
- **JS / visual side** (no unit harness): run the app via
  `DemoTOC+Sync/run.sh`, open a document with nested indentation, and confirm:
  guides appear at the correct columns, align with characters, and read as faint
  in both light and dark themes. Tune the alignment pixel offset and the
  faint-color alpha here.

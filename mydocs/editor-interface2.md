# The Editor ↔ Main Interface — Addendum: Indentation Guides & Leading-Space Shading

*Companion to [`editor-interface.md`](editor-interface.md). Read that first — this
document adds two related editor cues (faint vertical indentation guides plus a
tinted band behind each line's leading whitespace) and only describes what
changed. Section numbers below mirror the base document.
Reference implementation: `DemoTOC+Sync/`.*

---

## 0. What these features do

Two cues share one machinery. The editor draws a faint vertical line at each
indentation stop, and shades the leading-whitespace region behind it with a
tinted band, so nested / indented source is easier to scan (the way VS Code
draws indent guides):

```
- item one
│ nested a
│ │ deeper
│ │ deeper 2
│ nested b
text at margin
```

- **Indent unit:** 2 spaces. A line indented by `w` leading spaces gets
  `floor(w / 2)` bars, at character columns `0, 2, 4, …`.
- **Leading-space band.** Any line with `w > 0` leading spaces also gets a
  faint background band spanning exactly those `w` columns, painted *behind*
  the bars. A line with 1 leading space gets a band but no bar.
- **Uniform, not active-aware.** Bars and band use one faint color. They are
  recomputed only when the document changes — never on cursor movement.
- **Drawn everywhere**, including inside code / math / verbatim lines (there is
  no context suppression).
- **Color follows the theme.** Both cues ride the *existing* `setThemeColors`
  port pipeline, so no new channel was added — just one more color. The band
  reuses the guide color at reduced strength via CSS `color-mix`, so there is
  no second theme field.

The whole feature is one CSS variable (`--cm-indent-guide`) fed by one theme
field, plus one CodeMirror `StateField` that paints per-line backgrounds.
Nothing about the four communication channels in Section 1 of the base
document changed: no new attribute, no new event, no new port.

---

## 1(c). Ports — `setThemeColors` gains one field

`DemoTOC+Sync/src/Ports.elm:13` — the record type grew a third field:

```elm
port setThemeColors : { fg : String, bg : String, indentGuide : String } -> Cmd msg
```

`indentGuide` is a CSS color string (produced by `Color.toCssString`). On theme
toggle app.js sets it as the `--cm-indent-guide` variable, exactly as it
already did for `--cm-fg` / `--cm-bg`. This is still a styling convenience, not
part of the essential sync interface.

---

## 2.9 The indent-guide `StateField` (new)

A self-contained decoration field in `DemoTOC+Sync/assets/editor.js`
(lines 278–342), sitting alongside `syncHighlightField`. It uses only imports
already present (`StateField`, `Decoration`, `EditorView`) — no new imports,
no new dependency.

```js
const INDENT_UNIT = 2;      // spaces per indent level        (editor.js:282)
const GUIDE_OFFSET_PX = 4;  // horizontal alignment nudge      (editor.js:283)

function indentGuideStyle(levels, w) {
    // First a faint band across the `w` leading spaces, then `levels` 1px bars
    // at char columns 0, 2, 4, ... painted on top of it.
    // Monospace font => 1ch == one character advance, so bars land on the grid.
    const images = [], positions = [], sizes = [];
    if (w > 0) {
        // Reuse the theme guide color at reduced strength — no second theme field.
        const band = "color-mix(in srgb, var(--cm-indent-guide, rgba(0,0,0,0.15)) 22%, transparent)";
        images.push(`linear-gradient(${band}, ${band})`);
        positions.push(`${GUIDE_OFFSET_PX}px 0`);
        sizes.push(`${w}ch 100%`);
    }
    const bar = "linear-gradient(var(--cm-indent-guide, rgba(0,0,0,0.15)), var(--cm-indent-guide, rgba(0,0,0,0.15)))";
    for (let i = 0; i < levels; i++) {
        images.push(bar);
        positions.push(`calc(${i * INDENT_UNIT}ch + ${GUIDE_OFFSET_PX}px) 0`);
        sizes.push("1px 100%");
    }
    return `background-image: ${images.join(", ")};` +
        `background-position: ${positions.join(", ")};` +
        `background-size: ${sizes.join(", ")};` +
        `background-repeat: no-repeat;`;
}

function buildIndentGuides(state) {
    const decorations = [], doc = state.doc;
    for (let n = 1; n <= doc.lines; n++) {
        const line = doc.line(n), text = line.text;
        let w = 0;
        while (w < text.length && text[w] === " ") w++;
        const levels = Math.floor(w / INDENT_UNIT);
        if (w > 0) {   // band draws from w > 0; bars from levels > 0, inside the style fn
            decorations.push(
                Decoration.line({ attributes: { style: indentGuideStyle(levels, w) } }).range(line.from)
            );
        }
    }
    return Decoration.set(decorations);
}

const indentGuideField = StateField.define({
    create: (state) => buildIndentGuides(state),
    update(deco, tr) {
        if (tr.docChanged) return buildIndentGuides(tr.state);  // recompute on edits only
        return deco.map(tr.changes);                            // otherwise just remap
    },
    provide: (f) => EditorView.decorations.from(f),
});
```

Design notes worth keeping in mind if you touch it:

- **Band and bars share one style string.** Both are emitted as
  `background-image` layers on the *same* `Decoration.line`, band first (so the
  bars paint on top). Splitting them into two decorations would race on the
  `style` attribute — keep them in the one `indentGuideStyle` call.
- **Band width is exact.** The band is sized `${w}ch`, covering every leading
  space including a trailing odd one (`w` not a multiple of `INDENT_UNIT`),
  whereas the bars only reach `floor(w / 2)` stops.
- **Line decorations must be sorted by position.** They are, because lines are
  iterated `n = 1 … doc.lines` and `line.from` is monotonically increasing — so
  no explicit `sort` flag is needed.
- **`Decoration.line` paints the whole line box.** With `EditorView.lineWrapping`
  on, the background repeats under wrapped continuation rows, which is the
  desired look.
- **Full-document rebuild on every `docChanged`.** This is deliberate (the spec
  chose uniform, cursor-independent guides). For very large documents it is the
  obvious first thing to make incremental if profiling ever demands it.

### Registration

Add it to the `extensions` array in `connectedCallback`, after
`syncHighlightField` and before the `keymap` (editor.js:480–483):

```js
EditorView.lineWrapping,
syncHighlightField,
indentGuideField,      // ← new
keymap.of([ ... ]),
```

---

## 2.8 Glue (app.js) — set the new variable

`DemoTOC+Sync/assets/app.js:62`, inside the existing `setThemeColors`
subscription:

```js
app.ports.setThemeColors.subscribe((colors) => {
    document.documentElement.style.setProperty('--cm-fg', colors.fg);
    document.documentElement.style.setProperty('--cm-bg', colors.bg);
    document.documentElement.style.setProperty('--cm-indent-guide', colors.indentGuide);  // ← new
});
```

Because the guide color is read from `--cm-indent-guide` at paint time (with a
light-theme fallback baked into the gradient string), existing guide
decorations restyle automatically on toggle — no need to rebuild them.

---

## Theme model (`Render.Theme`)

`src/Render/Theme.elm` — `ThemedStyles` gained an `indentGuide : Color` field
(line 90), set in both themes. This single color drives both the guide bars and
(via `color-mix`) the leading-space band:

```elm
-- lightTheme (Theme.elm:154)
, indentGuide = Color.rgba 0.1 0.1 0.45 0.8   -- deep blue on a light background

-- darkTheme (Theme.elm:171)
, indentGuide = Color.rgba 0.95 0.45 0.1 1.0  -- deep orange on a dark background
```

`Main.elm`'s `ToggleTheme` handler (line 206) converts it into the port payload:

```elm
, indentGuide = currentTheme.indentGuide |> Color.toCssString
```

---

## Tuning knobs — for anyone who wants to change the look

Three independent dials control the look. Change any and re-verify visually
(`cd DemoTOC+Sync && ./run.sh`, then paste indented text). All are pure
presentation and touch no sync logic.

### A. Horizontal alignment — `GUIDE_OFFSET_PX`

- **File / location:** `DemoTOC+Sync/assets/editor.js:283`
  (`const GUIDE_OFFSET_PX = 4;`).
- **What it does:** a fixed pixel offset added to every bar's `calc()` position
  (`calc(<col>ch + GUIDE_OFFSET_PX px)`, editor.js:303) and to the band's left
  edge (editor.js:297), so the two cues line up. Each bar sits at
  `column * 1ch` from the line's left padding edge; this constant nudges the
  whole set left/right to line the bars up with the character grid, compensating
  for CodeMirror's `.cm-line` left padding. It does **not** change the *spacing*
  between bars (that is `INDENT_UNIT`, in `ch`), only where the set starts.
- **How to change:** raise it to move all bars right, lower it (including
  negative values) to move them left. Whole pixels are fine.
- **⚠️ Rebuild required.** `editor.js` is bundled to the git-ignored
  `editor-bundle.js`, which is what the page actually loads. After editing, run
  `cd DemoTOC+Sync && node build-editor.js`. (`./run.sh` does not rebuild the
  editor bundle for you — it only recompiles Elm.)

*Related dial:* `INDENT_UNIT` (editor.js:282, `= 2`) sets both the spaces per
level and the `ch` gap between bars. Only change it if the source's indentation
convention itself changes; it is not a cosmetic knob.

### B. Color (bars *and* band) — the `indentGuide` theme color

- **File / location:** `src/Render/Theme.elm` — `lightTheme.indentGuide`
  (line 154) and `darkTheme.indentGuide` (line 171).
- **What it does:** `Color.rgba r g b a` sets the hue and opacity of the guide
  bars. The current defaults are deep blue (`0.1 0.1 0.45 0.8`) on light and
  deep orange (`0.95 0.45 0.1 1.0`) on dark. This *same* color also feeds the
  leading-space band, so changing it re-tints both cues at once. Raise the alpha
  toward `1.0` for bolder bars; lower it to fade them.
- **How to change:** edit the r/g/b/a in whichever theme(s) you want. Keep light
  and dark independently legible against their backgrounds.
- **Rebuild:** Elm only — `./run.sh`'s elm-watch recompiles automatically, or
  run `cd DemoTOC+Sync && npx elm make src/Main.elm --output=assets/main.js`.
  No bundle rebuild needed for a color-only change.
- **Fallback caveat:** the gradient/`color-mix` strings in `editor.js:295` and
  `editor.js:301` hard-code `rgba(0,0,0,0.15)` as the value used *before the
  first theme toggle* (when `--cm-indent-guide` is not yet set). This is a
  neutral placeholder, not the light-theme color, so the bars and band shift to
  the real theme color on the first toggle — expected.

### C. Band strength — the `color-mix` percentage

- **File / location:** `DemoTOC+Sync/assets/editor.js:295`
  (`... var(--cm-indent-guide, …) 22%, transparent)`).
- **What it does:** the band is the guide color mixed with `transparent`; `22%`
  is how much guide color shows through. Raise it for a stronger band, lower it
  to fade the band while leaving the bars at full strength.
- **⚠️ Rebuild required.** `editor.js` is bundled to the git-ignored
  `editor-bundle.js`. After editing, run `cd DemoTOC+Sync && node build-editor.js`.

---

## 4. Interface contract — new row

Add to the quick-reference table in the base document:

| Contract item | Value | Producer | Consumer |
|---|---|---|---|
| Indent-guide color variable | `--cm-indent-guide` | app.js (from `setThemeColors.indentGuide`) | editor.js `indentGuideField` — guide bars + leading-space band |

And the updated `setThemeColors` shape wherever the base document shows it:

```elm
port setThemeColors : { fg : String, bg : String, indentGuide : String } -> Cmd msg
```

---

## 5. Pitfalls — additions

10. **Rebuild the editor bundle after any `editor.js` change**, including a
    `GUIDE_OFFSET_PX` tweak. The page loads `editor-bundle.js` (git-ignored,
    generated); `node build-editor.js` regenerates it. Editing `editor.js`
    alone changes nothing you can see.
11. **The fallback is a neutral placeholder, not the light theme.** The guide
    color has an `rgba(0,0,0,0.15)` fallback in `editor.js:295`/`:301` for the
    pre-first-toggle state; bars and band jump to the real theme color on the
    first toggle. This is expected — no need to keep it matched to `Theme.elm`.
12. **The band and bars must stay in one style string.** They are layered
    `background-image`s on a single `Decoration.line`; do not split them into
    two decorations or they will fight over the `style` attribute.

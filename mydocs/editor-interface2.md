# The Editor ↔ Main Interface — Addendum: Indentation Guides

*Companion to [`editor-interface.md`](editor-interface.md). Read that first — this
document adds one feature (faint vertical indentation guides in the editor) and
only describes what changed. Section numbers below mirror the base document.
Reference implementation: `DemoTOC+Sync/`.*

---

## 0. What this feature does

The editor draws a faint vertical line at each indentation stop, so nested /
indented source is easier to scan (the way VS Code draws indent guides):

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
- **Uniform, not active-aware.** All guides use one faint color. Guides are
  recomputed only when the document changes — never on cursor movement.
- **Drawn everywhere**, including inside code / math / verbatim lines (there is
  no context suppression).
- **Color follows the theme.** It rides the *existing* `setThemeColors` port
  pipeline, so no new channel was added — just one more color.

The whole feature is one CSS variable (`--cm-indent-guide`) fed by one new
theme field, plus one CodeMirror `StateField` that paints per-line
backgrounds. Nothing about the four communication channels in Section 1 of the
base document changed: no new attribute, no new event, no new port.

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
(lines 279–331), sitting alongside `syncHighlightField`. It uses only imports
already present (`StateField`, `Decoration`, `EditorView`) — no new imports,
no new dependency.

```js
const INDENT_UNIT = 2;      // spaces per indent level        (editor.js:282)
const GUIDE_OFFSET_PX = 4;  // horizontal alignment nudge      (editor.js:283)

function indentGuideStyle(levels) {
    // Paint `levels` 1px vertical bars at char columns 0, 2, 4, ...
    // Monospace font => 1ch == one character advance, so bars land on the grid.
    const images = [], positions = [], sizes = [];
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
        if (levels > 0) {
            decorations.push(
                Decoration.line({ attributes: { style: indentGuideStyle(levels) } }).range(line.from)
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
`syncHighlightField` and before the `keymap` (editor.js:471–473):

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
(line 76), set in both themes:

```elm
-- lightTheme (Theme.elm:134)
, indentGuide = Color.rgba 0 0 0 0.15   -- faint dark line on a light background

-- darkTheme (Theme.elm:149)
, indentGuide = Color.rgba 1 1 1 0.15   -- faint light line on a dark background
```

`Main.elm`'s `ToggleTheme` handler (line 178) converts it into the port payload:

```elm
, indentGuide = currentTheme.indentGuide |> Color.toCssString
```

---

## Tuning knobs — for anyone who wants to change the look

Two independent dials control the guides. Change either and re-verify visually
(`cd DemoTOC+Sync && ./run.sh`, then paste indented text). Both are safe to
change — they are pure presentation and touch no sync logic.

### A. Horizontal alignment — `GUIDE_OFFSET_PX`

- **File / location:** `DemoTOC+Sync/assets/editor.js:283`
  (`const GUIDE_OFFSET_PX = 4;`).
- **What it does:** a fixed pixel offset added to every bar's `calc()` position
  (`calc(<col>ch + GUIDE_OFFSET_PX px)`, editor.js:294). Each bar sits at
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

### B. Faintness (color) — the `indentGuide` theme color

- **File / location:** `src/Render/Theme.elm` — `lightTheme.indentGuide`
  (line 134) and `darkTheme.indentGuide` (line 149).
- **What it does:** the fourth argument of `Color.rgba r g b a` is the alpha
  (opacity). `0.15` reads as a faint hairline. Increase toward `1.0` for a
  bolder line; decrease toward `0.0` to fade it out. The r/g/b set the hue —
  black (`0 0 0`) on light, white (`1 1 1`) on dark — change those to tint the
  guides (e.g. a faint blue).
- **How to change:** edit the alpha (and/or r/g/b) in whichever theme(s) you
  want. Keep light and dark independently legible against their backgrounds.
- **Rebuild:** Elm only — `./run.sh`'s elm-watch recompiles automatically, or
  run `cd DemoTOC+Sync && npx elm make src/Main.elm --output=assets/main.js`.
  No bundle rebuild needed for a color-only change.
- **Fallback caveat:** the gradient string in `editor.js:291` hard-codes
  `rgba(0,0,0,0.15)` as the value used *before the first theme toggle* (when
  `--cm-indent-guide` is not yet set). If you change the light default in
  `Theme.elm`, update this fallback to match, or the guides will visibly shift
  color on the first toggle.

---

## 4. Interface contract — new row

Add to the quick-reference table in the base document:

| Contract item | Value | Producer | Consumer |
|---|---|---|---|
| Indent-guide color variable | `--cm-indent-guide` | app.js (from `setThemeColors.indentGuide`) | editor.js `indentGuideField` gradient |

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
11. **Keep the fallback in sync with the light theme.** The guide color has a
    `rgba(0,0,0,0.15)` fallback in `editor.js:291` for the pre-first-toggle
    state; if you change `lightTheme.indentGuide`, change the fallback too.

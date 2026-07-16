# Editor Indentation Guides Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show faint, theme-colored vertical lines at each 2-space indent stop in the CodeMirror editor so nested/indented source is easier to read.

**Architecture:** Extend the existing theme-color pipeline. `Render.Theme` gains one `indentGuide : Color`; `ToggleTheme` pushes it through the `setThemeColors` port; `app.js` writes it to the `--cm-indent-guide` CSS variable; a new CodeMirror `StateField` in `editor.js` paints per-line background gradients that read that variable.

**Tech Stack:** Elm (shared `src/` + `DemoTOC+Sync` app), CodeMirror 6 (`@codemirror/state`, `@codemirror/view`), esbuild bundling, avh4/elm-color.

## Global Constraints

- Indent unit is **2 spaces** per level. Guides at character columns 0, 2, 4, …
- Guides are **uniform** (one faint color), recomputed **only on document change**, not on cursor movement.
- Guides appear on **every** indented line (no code/math/verbatim suppression).
- Regression net (per repo `CLAUDE.md`): the Elm compiler + `npx elm-test`. There is no JS unit-test harness — the editor decoration is verified by rebuilding the bundle cleanly and by manual visual check.
- **Commits are deferred:** per the user's standing preference, do not commit any code until the user has visually verified the feature in the running app. All commits happen in the final task.
- Modify `elm.json` dependencies only via `elm-json` (not needed here — no new deps).

---

### Task 1: Add `indentGuide` to the theme model

**Files:**
- Modify: `src/Render/Theme.elm` (shared by the root package and `DemoTOC+Sync` via its `../src` source dir)

**Interfaces:**
- Consumes: nothing.
- Produces: `ThemedStyles.indentGuide : Color`, present in both `lightTheme` and `darkTheme`.

- [ ] **Step 1: Add the field to the `ThemedStyles` record type**

In `src/Render/Theme.elm`, the type alias currently ends:

```elm
    , highlight : Color
    , border : Color
    }
```

Change it to:

```elm
    , highlight : Color
    , border : Color
    , indentGuide : Color
    }
```

- [ ] **Step 2: Set the field in `lightTheme`**

`lightTheme` currently ends:

```elm
    , highlight = indigo200
    , border = gray300
    }
```

Change it to:

```elm
    , highlight = indigo200
    , border = gray300
    , indentGuide = Color.rgba 0 0 0 0.15
    }
```

- [ ] **Step 3: Set the field in `darkTheme`**

`darkTheme` currently ends:

```elm
    , highlight = indigo500
    , border = gray700
    }
```

Change it to:

```elm
    , highlight = indigo500
    , border = gray700
    , indentGuide = Color.rgba 1 1 1 0.15
    }
```

- [ ] **Step 4: Verify the shared package compiles and tests pass**

Run from the repo root (`/Users/carlson/dev/elm-work/scripta/xmarkdown`):

```bash
elm make src/XMarkdown/API.elm src/XMarkdown/Types.elm src/Render/Theme.elm --output=/dev/null
npx elm-test
```

Expected: both succeed with no errors. (`Color` is already imported in `Render.Theme`; `ThemedStyles` has only two record literals — `lightTheme` and `darkTheme` — both now updated, so no "missing field" errors.)

Do **not** commit yet (see Global Constraints).

---

### Task 2: Push the guide color through the port to a CSS variable

**Files:**
- Modify: `DemoTOC+Sync/src/Ports.elm:13`
- Modify: `DemoTOC+Sync/src/Main.elm` (`ToggleTheme` handler, ~lines 174-178)
- Modify: `DemoTOC+Sync/assets/app.js` (`setThemeColors` subscription, ~lines 58-62)

**Interfaces:**
- Consumes: `ThemedStyles.indentGuide : Color` from Task 1; `Color.toCssString` (already used in this file, produces an `rgba(...)` string).
- Produces: the `--cm-indent-guide` CSS variable on `document.documentElement`, set whenever the theme is toggled. Consumed by Task 3.

- [ ] **Step 1: Extend the `setThemeColors` port record type**

In `DemoTOC+Sync/src/Ports.elm`, line 13 currently reads:

```elm
port setThemeColors : { fg : String, bg : String } -> Cmd msg
```

Change it to:

```elm
port setThemeColors : { fg : String, bg : String, indentGuide : String } -> Cmd msg
```

- [ ] **Step 2: Add the field to the `ToggleTheme` payload**

In `DemoTOC+Sync/src/Main.elm`, the `ToggleTheme` handler builds:

```elm
                themeCmd =
                    Ports.setThemeColors
                        { fg = currentTheme.text |> Color.toCssString
                        , bg = currentTheme.background |> Color.toCssString
                        }
```

Change it to:

```elm
                themeCmd =
                    Ports.setThemeColors
                        { fg = currentTheme.text |> Color.toCssString
                        , bg = currentTheme.background |> Color.toCssString
                        , indentGuide = currentTheme.indentGuide |> Color.toCssString
                        }
```

(`currentTheme` here is the `ThemedStyles` record — `lightTheme` or `darkTheme` — selected in the same `let`.)

- [ ] **Step 3: Set the CSS variable in the port handler**

In `DemoTOC+Sync/assets/app.js`, the subscription currently reads:

```javascript
    app.ports.setThemeColors.subscribe((colors) => {
        console.log("Setting theme colors:", colors);
        document.documentElement.style.setProperty('--cm-fg', colors.fg);
        document.documentElement.style.setProperty('--cm-bg', colors.bg);
    });
```

Change it to:

```javascript
    app.ports.setThemeColors.subscribe((colors) => {
        console.log("Setting theme colors:", colors);
        document.documentElement.style.setProperty('--cm-fg', colors.fg);
        document.documentElement.style.setProperty('--cm-bg', colors.bg);
        document.documentElement.style.setProperty('--cm-indent-guide', colors.indentGuide);
    });
```

- [ ] **Step 4: Verify the app compiles**

Run from `DemoTOC+Sync`:

```bash
cd DemoTOC+Sync
npx elm make src/Main.elm --output=/dev/null
```

Expected: success with no errors. (Elm ports are structurally typed; the record passed in `Main.elm` must exactly match the port's record — all three fields now line up.)

Do **not** commit yet.

---

### Task 3: Paint the indentation guides in the editor

**Files:**
- Modify: `DemoTOC+Sync/assets/editor.js` (add a `StateField`, register it in `connectedCallback`)
- Rebuild: `DemoTOC+Sync/assets/editor-bundle.js` via `node build-editor.js` (this bundle is what `assets/index.html` loads)

**Interfaces:**
- Consumes: `--cm-indent-guide` CSS variable from Task 2 (with a light-theme fallback baked in so guides are correct before the first theme toggle). Uses `StateField`, `Decoration`, `EditorView` — all already imported at the top of `editor.js`.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Add the indent-guide `StateField` and helpers**

In `DemoTOC+Sync/assets/editor.js`, insert the following block immediately **before** the `const lightTheme = EditorView.theme(` line (i.e. after the `xmarkdownSyntax` field's `});`):

```javascript
// Indentation guides: faint vertical lines at each 2-space indent stop, so
// nested/indented source is easier to scan. The bar color comes from the theme
// via the --cm-indent-guide CSS variable (set by app.js on theme change); the
// fallback matches the light theme so guides are correct before the first toggle.
const INDENT_UNIT = 2; // spaces per indent level
const GUIDE_OFFSET_PX = 4; // aligns the first bar with the .cm-line left padding; tuned by eye

function indentGuideStyle(levels) {
    // Paint `levels` 1px-wide vertical bars at character columns 0, 2, 4, ...
    // Monospace font => 1ch == one character advance, so bars land on the grid.
    const images = [];
    const positions = [];
    const sizes = [];
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
    const decorations = [];
    const doc = state.doc;
    for (let n = 1; n <= doc.lines; n++) {
        const line = doc.line(n);
        const text = line.text;
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
    create(state) {
        return buildIndentGuides(state);
    },
    update(deco, tr) {
        // Guides depend only on line indentation, so recompute on doc changes.
        if (tr.docChanged) {
            return buildIndentGuides(tr.state);
        }
        return deco.map(tr.changes);
    },
    provide: (f) => EditorView.decorations.from(f),
});
```

- [ ] **Step 2: Register the field in the editor's extensions**

In `connectedCallback`, the `extensions` array currently contains:

```javascript
                        EditorView.lineWrapping,
                        syncHighlightField,
                        keymap.of([
```

Change it to:

```javascript
                        EditorView.lineWrapping,
                        syncHighlightField,
                        indentGuideField,
                        keymap.of([
```

- [ ] **Step 3: Rebuild the editor bundle**

Run from `DemoTOC+Sync`:

```bash
cd DemoTOC+Sync
node build-editor.js
```

Expected: no output and exit code 0 (esbuild writes `assets/editor-bundle.js`). If esbuild prints errors, they are JS syntax errors in the new block — fix and re-run.

- [ ] **Step 4: Confirm the bundle picked up the new field**

Run from `DemoTOC+Sync`:

```bash
grep -c "indentGuideField" assets/editor-bundle.js
```

Expected: a number `>= 1` (the identifier appears in the freshly built bundle).

Do **not** commit yet.

---

### Task 4: Visual verification in the app, tuning, and commit

**Files:**
- Possibly tune: `DemoTOC+Sync/assets/editor.js` (`GUIDE_OFFSET_PX`), and if adjusted, rebuild via `node build-editor.js`
- Possibly tune: `src/Render/Theme.elm` (`indentGuide` alpha in `lightTheme` / `darkTheme`)

**Interfaces:**
- Consumes: everything from Tasks 1-3.
- Produces: the committed feature.

- [ ] **Step 1: Run the app**

Run from `DemoTOC+Sync`:

```bash
cd DemoTOC+Sync
./run.sh
```

This starts elm-watch + a static server on port 8200 and opens Firefox at `http://localhost:8200/index.html`.

- [ ] **Step 2: Load an indented document and inspect the guides**

In the editor, type or paste nested content, e.g.:

```
- item one
  nested a
    deeper
    deeper 2
  nested b
text at margin
```

Confirm:
- A faint vertical line appears at each indent stop (one bar at 2-space indent, two stacked bars at 4-space indent, none on the un-indented line).
- Bars align with the character grid (sitting just left of the indented text, not through the glyphs).

- [ ] **Step 3: Tune alignment if needed**

If the bars sit too far left/right of the character columns, adjust `GUIDE_OFFSET_PX` in `DemoTOC+Sync/assets/editor.js`, then rebuild:

```bash
node build-editor.js
```

and reload the browser. Repeat until aligned.

- [ ] **Step 4: Verify both themes**

Click the theme toggle (the toolbar theme-toggle button). Confirm guides are faint-but-visible against **both** the light and dark backgrounds. If a guide is too strong or too faint, adjust the `indentGuide` alpha in `src/Render/Theme.elm` (`lightTheme` / `darkTheme`), let elm-watch recompile, and reload.

- [ ] **Step 5: Final regression check**

Run from the repo root:

```bash
elm make src/XMarkdown/API.elm src/XMarkdown/Types.elm src/Render/Theme.elm --output=/dev/null
npx elm-test
```

Expected: both pass.

- [ ] **Step 6: Commit (only after the user confirms the app looks right)**

```bash
cd /Users/carlson/dev/elm-work/scripta/xmarkdown
git add src/Render/Theme.elm \
        "DemoTOC+Sync/src/Ports.elm" \
        "DemoTOC+Sync/src/Main.elm" \
        "DemoTOC+Sync/assets/app.js" \
        "DemoTOC+Sync/assets/editor.js" \
        "DemoTOC+Sync/assets/editor-bundle.js"
git commit -m "feat: theme-colored indentation guides in the editor

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:**
- VS Code line-per-level guides → Task 3 (`buildIndentGuides` draws one bar per level).
- 2-space indent unit → `INDENT_UNIT = 2` (Task 3); Global Constraints.
- Show everywhere (no code/math suppression) → Task 3 walks every line unconditionally.
- Uniform color, recompute on doc change only → Task 3 `update` recomputes on `tr.docChanged`, maps otherwise.
- Theme-driven color via the existing pipeline → Task 1 (`ThemedStyles.indentGuide`), Task 2 (port → `--cm-indent-guide`), Task 3 (CSS var in the gradient).
- Light + dark colors + fallback → Task 1 (both themes), Task 3 (CSS-var fallback), Task 4 Step 4 (verify both).
- Edge cases (blank/zero-indent, line wrapping) → Task 3 (`levels > 0` guard; line-level background repeats under wrapped rows).
- Verification (elm compiler + elm-test + manual visual) → Tasks 1, 2, 4.

**Placeholder scan:** No TBD/TODO/"handle edge cases"/vague steps — every code step shows exact code; every command shows expected output.

**Type consistency:** `indentGuide` is a `Color` in `ThemedStyles` (Task 1), converted with `Color.toCssString` to the `indentGuide : String` port field (Task 2), read as `colors.indentGuide` in `app.js` (Task 2), and consumed as the `--cm-indent-guide` CSS variable in `editor.js` (Task 3). Names align across all tasks: `indentGuideField`, `buildIndentGuides`, `indentGuideStyle`, `INDENT_UNIT`, `GUIDE_OFFSET_PX`.

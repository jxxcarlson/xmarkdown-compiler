®# How RL Sync Works


RL sync is the **preview → editor** direction: you click rendered text in the preview, and the source editor (CodeMirror) selects, highlights, and scrolls to the corresponding source. Here's how it works end to end.


# Notes

The text beginning in the next section describes how RL sync works in the current  (6/23/2026) version of scripta-v4 (/Users/carlson/dev/elm-work/scripta/scripta-app-v4).  We are interested in implementing RL sync using new xmarkdown compiler plus some possible additions to it.  The test implementation of the browser code is the DemoTOC+Sync folder. 

Since the compiler is in Elm, so will be those additions.  An important part of this work is intercepting various evens in the DOM using Elm code.  For this you will need to use the elm/browser package (see https://package.elm-lang.org/packages/elm/browser/latest/). The function 

```
onClick : Decoder msg -> Sub msg
```

is of particular interest in handling click events.


# The big picture

RL sync is **almost entirely JavaScript-driven**. Unlike LR sync (Ctrl-S, which routes through Elm), an RL click never goes through the Elm update loop — the click handler reads attributes off the rendered DOM and drives the CodeMirror instance directly. Elm only gets involved for the *debug footer* and for keeping rendered-element metadata fresh between reparses.

There are two participating formats with different capabilities:

| | Scripta | MiniLaTeX |
|---|---|---|
| granularity | word-level + block-level | whole-paragraph |
| markers used | `id` (line) + `data-begin`/`data-end` (columns) | `data-line` + `data-lines` |
| why | AST carries true source positions | AST has no positions; render diverges from source |

(Markdown emits no markers, so it has no RL sync at all.)

# The markers on rendered elements

Sync depends on attributes the renderers emit into the DOM, all inside the container `#__RENDERED_TEXT__` (`Editor.renderedTextId`, `frontend/src/Editor.elm:11`):

- **Scripta expressions** — `Render/Utility.elm:15` (`rlSync`): emits `id="e-<line>.<tok>"` (the 0-indexed source line) plus `data-begin`/`data-end` = within-line **column** offsets.
- **Scripta blocks** — `Render/Utility.elm:40` (`rlBlockSync`): emits `id="<line>-<idx>"` plus `data-begin`/`data-end`/`data-lines` (line span).
- **MiniLaTeX paragraphs** — `MiniLatex/EditSimple.elm:157`: emits `data-line` (0-indexed start line) and `data-lines` (= lineCount−1). These line ranges come from `Internal/Paragraph.elm` `logicalParagraphifyWithLines`, computed *outside* the AST by the paragraphifier FSM.

# The click flow (`frontend/codemirror-element.js`, `setupRLSync` IIFE)

1. **Capture the click** — a capture-phase `click` listener (~line 27214) on `#__RENDERED_TEXT__`. `findPositionElement` walks up from `e.target` to the nearest ancestor carrying `data-begin` (Scripta) **or** `data-line` (MiniLaTeX).

2. **Decode the source line** — `parseLineNumber(id)` (~27133): for `e-N.T` or `N-I` ids it takes `N` and returns `N+1` (CodeMirror lines are 1-indexed).

3. **Pick a precision level:**
   - **MiniLaTeX branch** (`data-line` present): `firstLine = data-line + 1`, `lastLine = firstLine + data-lines` → highlight the whole source line range. Robust, never matches rendered text against source.
   - **Scripta block** (`data-lines > 0`): whole-line block highlight.
   - **Scripta word-level** (the default for inline): `document.caretRangeFromPoint()` + `wordBoundsAt()`/`offsetInElement()` map the clicked rendered word to a source column; falls back to the expression's `data-begin..data-end` if that fails.

4. **Drive the editor** — `highlightInEditor(line, begin, end, numLines)` (~27150) grabs `document.querySelector('codemirror-editor').editor`, converts line+column to absolute `from`/`to`, and dispatches a CodeMirror transaction with two custom effects exposed by the element: `setSyncHighlight({from,to})` (the `.cm-sync-highlight` decoration) and `scrollToCenter(from)`.

5. **Drag-select** — a `mouseup` handler (~27309) extends this to dragging across rendered text → mapping the selection back to an editor range (Scripta only).

# What the recent commit changed (`feat(rl-sync): emit structured single-change edit`)

This is the subtler half — keeping markers correct **while you type**, so an RL click immediately after editing lands on the right source position without waiting for the debounced reparse.

- `sendText(editor, edit)` (~26196) now attaches a structured `edit` to the `text-change` CustomEvent. When a keystroke is a *single* change, CodeMirror's `iterChanges` (~26675) builds `edit = { offset, removed, inserted }`; multi-change edits send `null`.
- Elm decodes it: `Editor.editDecoder` (`Editor.elm:36`) → `onTextChange` tries `InputTextEdited` first, else plain `InputText` (`NewViewHelper/EditorColumn.elm:411`).
- `Main.elm:2018` `InputTextEdited edit source` calls `Scripta.applyEdit edit` on `model.parsedDoc`, then defers to `InputText`.
- `Scripta.applyEdit` (`Scripta.elm:287`) → `Edit/Map.elm:24` `applyEditToForest`: computes char-delta and line-delta and **shifts** every block's offsets/line-numbers/ids that sit after the edit point, growing the block the edit lands inside — **without reparsing**. So `data-begin`/`data-end`/`id` stay valid per-keystroke; the debounced full reparse (`Constants.reparseDelayMs`) catches up later.

# The debug footer

`codemirror-element.js` builds detail strings (`rlScriptaWordDetail`, `rlScriptaBlockDetail`, `rlScriptaDragDetail`, ~27087) and emits a unified `sync-debug` CustomEvent → Elm `GotSyncDebug` stores it in `model.lastSyncMsg` (`SyncDebugMsg` = direction/format/trigger/detail, `AppTypes.elm:72`). `NewView.elm:332` renders it as an **admin-only** footer like `[RL · Scripta · click] line 5 cols 12–18 word 'hello'`.

# Reference docs

The authoritative architecture write-up is `docs/editor-preview-sync.md` (§2 covers RL specifically). Pure RL logic is unit-tested in `frontend/tests/rl-sync-test.js`.

One note: the line numbers above are into the **built bundle** `frontend/codemirror-element.js`; the design doc refers to functions by name precisely because those numbers drift. The function names (`setupRLSync`, `findPositionElement`, `parseLineNumber`, `highlightInEditor`) are the stable handles.

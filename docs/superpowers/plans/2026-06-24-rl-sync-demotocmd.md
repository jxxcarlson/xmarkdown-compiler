# RL Sync (rendered → editor) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Click rendered text in DemoTOC+Sync → CodeMirror paints a background highlight over the corresponding source span (phrase-level for inline, line-range for blocks) and scrolls it into view.

**Architecture:** Clicks already route through Elm as `MarkupMsg`. A new pure `ScriptaV2.Sync` module maps `SendMeta`/`SendLineNumber` → a `SyncHighlight` (line + columns), JSON-encoded into a `highlight` attribute on `<codemirror-editor>`; `editor.js` applies a `StateField` decoration + scroll. Inline `onClick` gains `stopPropagation` so phrase clicks beat the enclosing block.

**Tech Stack:** Elm 0.19.1 (`elm/html`, `elm/json`), CodeMirror 6 (esm.sh), plain CSS.

## Global Constraints

- v1 granularity: **phrase-level** for inline (using populated `begin`/`end` columns), **line-range** for blocks. No word-level (no `caretRangeFromPoint`).
- Highlight is a **background decoration** (`StateField`, class `.cm-sync-highlight`, color `var(--cm-sync-highlight-bg)`), never a selection. Clears on edit and on Escape.
- **Elm-driven:** the only new JS is the decoration/scroll application in `editor.js`.
- Mapping logic lives in a **new `ScriptaV2.Sync`** module (added to `elm.json` `exposed-modules`). `ScriptaV2.Editor` only renders the attribute.
- Inline `onClick` uses **`stopPropagation`** (behavior-only change in `Render/Expression.elm`; rendered output unchanged).
- **Editor-only** for v1 — no rendered-side highlight.
- Indexing: inline `id` line is **0-indexed** → CM `line = line0 + 1`; inline `begin/end` are **inclusive** columns → editor uses `to = from + colEnd + 1`; block `SendLineNumber.begin` treated as **0-indexed** → CM `line = begin + 1`, `lineCount = end - begin`. The `fromMsg` unit tests are the source of truth.
- `expressionIdPrefix` = `"e-"` (`ScriptaV2.Config`).
- Compiler regression net must pass after every task:
  `elm make src/ScriptaV2/APISimple.elm src/ScriptaV2/API.elm src/ScriptaV2/Types.elm src/ScriptaV2/Msg.elm src/ScriptaV2/Language.elm src/Render/Theme.elm src/ScriptaV2/Editor.elm src/ScriptaV2/Sync.elm --output=/dev/null` then `npx elm-test`.
- Demo build gate: `cd DemoTOC+Sync && elm make src/Main.elm --output=assets/main.js` → `Success!`.
- DemoTOC+Sync is served over **HTTP** for manual testing (`./run.sh`); ES modules don't load over `file://`.

---

### Task 1: `ScriptaV2.Sync` — pure click→highlight mapping

**Files:**
- Create: `src/ScriptaV2/Sync.elm`
- Modify: `elm.json` (add `"ScriptaV2.Sync"` to `exposed-modules`)
- Test: `tests/SyncTest.elm`

**Interfaces:**
- Consumes: `ScriptaV2.Msg.MarkupMsg(..)` (`SendMeta { begin, end, index, id }`, `SendLineNumber { begin, end }`); `ScriptaV2.Config.expressionIdPrefix : String` (`"e-"`).
- Produces:
  - `type alias SyncHighlight = { line : Int, colBegin : Int, colEnd : Int, lineCount : Int, tick : Int }`
  - `fromMsg : Int -> MarkupMsg -> Maybe SyncHighlight`
  - `encode : SyncHighlight -> String`
  - `highlightAttribute : Maybe SyncHighlight -> List (Html.Attribute msg)`

- [ ] **Step 1: Write the failing tests**

Create `tests/SyncTest.elm`:

```elm
module SyncTest exposing (suite)

import Expect
import ScriptaV2.Msg exposing (MarkupMsg(..))
import ScriptaV2.Sync as Sync
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "ScriptaV2.Sync"
        [ test "SendMeta: 0-indexed id line -> CM line+1, keeps inclusive columns" <|
            \_ ->
                Sync.fromMsg 7 (SendMeta { begin = 6, end = 14, index = 4, id = "e-12.4" })
                    |> Expect.equal (Just { line = 13, colBegin = 6, colEnd = 14, lineCount = 0, tick = 7 })
        , test "SendLineNumber: 0-indexed begin -> CM line+1, lineCount = end-begin" <|
            \_ ->
                Sync.fromMsg 3 (SendLineNumber { begin = 4, end = 6 })
                    |> Expect.equal (Just { line = 5, colBegin = 0, colEnd = 0, lineCount = 2, tick = 3 })
        , test "SendMeta with unparseable id -> Nothing" <|
            \_ ->
                Sync.fromMsg 1 (SendMeta { begin = 0, end = 0, index = 0, id = "bogus" })
                    |> Expect.equal Nothing
        , test "non-RL message -> Nothing" <|
            \_ ->
                Sync.fromMsg 1 (SelectId "x")
                    |> Expect.equal Nothing
        , test "encode produces compact ordered JSON" <|
            \_ ->
                Sync.encode { line = 13, colBegin = 6, colEnd = 14, lineCount = 0, tick = 7 }
                    |> Expect.equal "{\"line\":13,\"colBegin\":6,\"colEnd\":14,\"lineCount\":0,\"tick\":7}"
        ]
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx elm-test tests/SyncTest.elm`
Expected: FAIL — `I cannot find module ScriptaV2.Sync`.

- [ ] **Step 3: Write the module**

Create `src/ScriptaV2/Sync.elm`:

```elm
module ScriptaV2.Sync exposing (SyncHighlight, fromMsg, encode, highlightAttribute)

{-| Maps rendered-text clicks (as MarkupMsg) into a source-span highlight the
CodeMirror editor can apply (RL sync: rendered → editor).

@docs SyncHighlight, fromMsg, encode, highlightAttribute

-}

import Html
import Html.Attributes
import Json.Encode as E
import ScriptaV2.Config as Config
import ScriptaV2.Msg exposing (MarkupMsg(..))


{-| A source span to highlight in the editor.

  - `line` is 1-indexed (CodeMirror lines).
  - `colBegin`/`colEnd` are within-line columns, `colEnd` inclusive. Both 0 for
    a whole-line / block highlight.
  - `lineCount` is 0 for a single-line phrase, > 0 for a block line range.
  - `tick` is a monotonic counter so repeat clicks on the same span re-trigger
    the editor (the attribute value changes, so Elm re-pushes it).

-}
type alias SyncHighlight =
    { line : Int
    , colBegin : Int
    , colEnd : Int
    , lineCount : Int
    , tick : Int
    }


{-| Map a MarkupMsg to a highlight. `Nothing` for messages that are not RL
clicks, or when the id cannot be parsed (better no highlight than a wrong one).
-}
fromMsg : Int -> MarkupMsg -> Maybe SyncHighlight
fromMsg tick msg =
    case msg of
        SendMeta m ->
            lineFromId m.id
                |> Maybe.map
                    (\line0 ->
                        { line = line0 + 1
                        , colBegin = m.begin
                        , colEnd = m.end
                        , lineCount = 0
                        , tick = tick
                        }
                    )

        SendLineNumber r ->
            Just
                { line = r.begin + 1
                , colBegin = 0
                , colEnd = 0
                , lineCount = r.end - r.begin
                , tick = tick
                }

        _ ->
            Nothing


{-| Parse the 0-indexed source line from an expression id of the form
`"e-<line>.<tok>"`. Returns Nothing on any shape mismatch.
-}
lineFromId : String -> Maybe Int
lineFromId id =
    if String.startsWith Config.expressionIdPrefix id then
        id
            |> String.dropLeft (String.length Config.expressionIdPrefix)
            |> String.split "."
            |> List.head
            |> Maybe.andThen String.toInt

    else
        Nothing


{-| Compact JSON for the `highlight` custom-element attribute. Key order is
fixed so it is easy to assert in tests.
-}
encode : SyncHighlight -> String
encode h =
    E.encode 0
        (E.object
            [ ( "line", E.int h.line )
            , ( "colBegin", E.int h.colBegin )
            , ( "colEnd", E.int h.colEnd )
            , ( "lineCount", E.int h.lineCount )
            , ( "tick", E.int h.tick )
            ]
        )


{-| The `highlight` attribute to splat onto the editor node, or `[]` when there
is nothing to highlight.
-}
highlightAttribute : Maybe SyncHighlight -> List (Html.Attribute msg)
highlightAttribute mh =
    case mh of
        Just h ->
            [ Html.Attributes.attribute "highlight" (encode h) ]

        Nothing ->
            []
```

- [ ] **Step 4: Expose the module**

In `elm.json`, add `"ScriptaV2.Sync"` to `exposed-modules` (after `"ScriptaV2.Editor"`):

```json
        "Render.Theme",
        "ScriptaV2.Editor",
        "ScriptaV2.Sync"
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `npx elm-test tests/SyncTest.elm`
Expected: PASS — 5 tests.

- [ ] **Step 6: Run the compiler regression net**

Run:
```bash
elm make src/ScriptaV2/APISimple.elm src/ScriptaV2/API.elm src/ScriptaV2/Types.elm src/ScriptaV2/Msg.elm src/ScriptaV2/Language.elm src/Render/Theme.elm src/ScriptaV2/Editor.elm src/ScriptaV2/Sync.elm --output=/dev/null
npx elm-test
```
Expected: `Success!` and all tests pass (the 9 existing + 5 new = 14).

- [ ] **Step 7: Commit**

```bash
git add src/ScriptaV2/Sync.elm tests/SyncTest.elm elm.json
git commit -m "feat(compiler): add ScriptaV2.Sync — map rendered clicks to source-span highlights"
```

---

### Task 2: `Render/Expression.elm` — stopPropagation on inline clicks

**Files:**
- Modify: `src/Render/Expression.elm` (imports; add `onClickStop`; replace 4 `Events.onClick (SendMeta meta)` sites)

**Interfaces:**
- Consumes: `ScriptaV2.Msg.MarkupMsg(..)` (already imported), `Element.htmlAttribute`.
- Produces: no new public API. Behavior change: inline expression clicks no longer bubble to the enclosing block's `SendLineNumber` handler.

This task is behavior-only and not unit-testable in elm-test (it concerns DOM event propagation); its gate is a clean compile + green regression net + green demo build, and it is validated in Task 4's manual browser check. There is no failing-test step.

- [ ] **Step 1: Add the imports**

In `src/Render/Expression.elm`, the import block currently has `import Html` and `import Html.Attributes` but not `Html.Events` or `Json.Decode`. Add both. After line `import Html.Attributes` insert:

```elm
import Html.Events
import Json.Decode
```

- [ ] **Step 2: Add the `onClickStop` helper**

Add this helper near the other top-level helpers (e.g. just above `htmlId` at the bottom of the file):

```elm
{-| A click handler that does NOT bubble, so an inline expression click reports
only itself and not the enclosing block's right-to-left line sync.
-}
onClickStop : MarkupMsg -> Element.Attribute MarkupMsg
onClickStop msg =
    Element.htmlAttribute
        (Html.Events.stopPropagationOn "click" (Json.Decode.succeed ( msg, True )))
```

- [ ] **Step 3: Replace the four inline click sites**

Replace every occurrence of `Events.onClick (SendMeta meta)` with `onClickStop (SendMeta meta)` (4 occurrences — lines ≈ 41, 76, 96, 100). For example line 41 becomes:

```elm
        Text string meta ->
            Element.el (background :: [ onClickStop (SendMeta meta), htmlId meta.id ] ++ attrs) (Element.text (string ++ " "))
```

Leave the commented `-- TODO: Events.onClick (SendMeta meta)?` at ~line 104 untouched. Do not change block-level `SendLineNumber` handling.

- [ ] **Step 4: Verify compile + regression net + demo build**

Run:
```bash
elm make src/ScriptaV2/APISimple.elm src/ScriptaV2/API.elm src/ScriptaV2/Types.elm src/ScriptaV2/Msg.elm src/ScriptaV2/Language.elm src/Render/Theme.elm src/ScriptaV2/Editor.elm src/ScriptaV2/Sync.elm --output=/dev/null
npx elm-test
(cd DemoTOC+Sync && elm make src/Main.elm --output=assets/main.js)
```
Expected: `Success!`, all tests pass, and the demo build prints `Success!`.

- [ ] **Step 5: Commit**

```bash
git add src/Render/Expression.elm
git commit -m "feat(compiler): stop inline click propagation so phrase clicks beat the block"
```

---

### Task 3: `editor.js` — sync-highlight decoration + scroll

**Files:**
- Modify: `DemoTOC+Sync/assets/editor.js`

**Interfaces:**
- Consumes: a `highlight` attribute carrying JSON `{ line, colBegin, colEnd, lineCount, tick }` (1-indexed `line`; `colEnd` inclusive; `lineCount > 0` ⇒ block range). Set by `ScriptaV2.Sync` via `ScriptaV2.Editor` in Task 4.
- Produces: the `codemirror-editor` element now observes `highlight` and paints/scrolls.

- [ ] **Step 1: Add the imports for StateField/StateEffect/Decoration/keymap**

In `DemoTOC+Sync/assets/editor.js`, replace the two import lines:

```js
import { basicSetup, EditorView } from "https://esm.sh/codemirror@6.0.1";
import { EditorState } from "https://esm.sh/@codemirror/state@6";
```

with:

```js
import { basicSetup, EditorView } from "https://esm.sh/codemirror@6.0.1";
import { EditorState, StateField, StateEffect } from "https://esm.sh/@codemirror/state@6";
import { Decoration, keymap } from "https://esm.sh/@codemirror/view@6";
```

(`@codemirror/view@6` resolves to the same instance `codemirror@6.0.1` uses internally — esm.sh dedups by version, same as `@codemirror/state`.)

- [ ] **Step 2: Define the sync-highlight effects + StateField**

Add near the top of the module, after the imports:

```js
// RL sync: a background decoration over the source span the user clicked.
const setSyncHighlight = StateEffect.define();
const clearSyncHighlight = StateEffect.define();
const syncMark = Decoration.mark({ class: "cm-sync-highlight" });

const syncHighlightField = StateField.define({
    create() {
        return Decoration.none;
    },
    update(deco, tr) {
        for (const e of tr.effects) {
            if (e.is(setSyncHighlight)) {
                return Decoration.set([syncMark.range(e.value.from, e.value.to)]);
            }
            if (e.is(clearSyncHighlight)) {
                return Decoration.none;
            }
        }
        // Clear the highlight on any document edit (user typing or programmatic).
        if (tr.docChanged) {
            return Decoration.none;
        }
        return deco.map(tr.changes);
    },
    provide: (f) => EditorView.decorations.from(f),
});
```

- [ ] **Step 3: Register the field, the highlight CSS, and the Escape key**

In `connectedCallback`, the `EditorState.create({ extensions: [...] })` array currently is `[ basicSetup, lightTheme, EditorView.lineWrapping, EditorView.updateListener.of(...) ]`. Add `syncHighlightField` and an Escape keymap so the list reads:

```js
                    extensions: [
                        basicSetup,
                        lightTheme,
                        EditorView.lineWrapping,
                        syncHighlightField,
                        keymap.of([
                            {
                                key: "Escape",
                                run: (view) => {
                                    view.dispatch({ effects: clearSyncHighlight.of(null) });
                                    return true;
                                },
                            },
                        ]),
                        EditorView.updateListener.of((v) => {
                            if (!v.docChanged) return;
                            if (editor.isProgrammaticUpdate) {
                                editor.isProgrammaticUpdate = false; // suppress echo
                            } else {
                                sendText(editor);
                            }
                        }),
                    ],
```

In the `lightTheme` `EditorView.theme({ ... })` object, add a `.cm-sync-highlight` rule (e.g. after the `.cm-gutters` entry):

```js
        ".cm-sync-highlight": {
            backgroundColor: "var(--cm-sync-highlight-bg, #fff3b0)",
        },
```

- [ ] **Step 4: Observe and apply the `highlight` attribute**

Change `observedAttributes` from `return ["load"];` to:

```js
    static get observedAttributes() {
        return ["load", "highlight"];
    }
```

In `handleAttributeChange(attr, value)`, add a `highlight` branch after the existing `load` branch:

```js
        if (attr === "highlight" && typeof value === "string") {
            const editor = this.editor;
            let h;
            try {
                h = JSON.parse(value);
            } catch (e) {
                return; // malformed payload: ignore
            }
            const doc = editor.state.doc;
            if (!h || h.line < 1 || h.line > doc.lines) return; // out of range: ignore

            const lineStart = doc.line(h.line).from;
            let from;
            let to;
            if (h.lineCount > 0) {
                from = lineStart;
                const lastLine = Math.min(h.line + h.lineCount, doc.lines);
                to = doc.line(lastLine).to;
            } else {
                from = lineStart + h.colBegin;
                to = lineStart + h.colEnd + 1; // colEnd is inclusive
            }
            editor.dispatch({
                effects: [
                    setSyncHighlight.of({ from, to }),
                    EditorView.scrollIntoView(from, { y: "center" }),
                ],
            });
        }
```

- [ ] **Step 5: Syntax-check editor.js**

Run: `node --check DemoTOC+Sync/assets/editor.js`
Expected: no output, exit 0.

- [ ] **Step 6: Commit**

```bash
git add DemoTOC+Sync/assets/editor.js
git commit -m "feat(DemoTOC+Sync): editor.js sync-highlight decoration + scroll (RL sync)"
```

---

### Task 4: Wire the highlight through Elm + manual acceptance

**Files:**
- Modify: `src/ScriptaV2/Editor.elm` (Config gains `highlight`; view splats the attribute)
- Modify: `DemoTOC+Sync/src/Main.elm` (model `syncHighlight` + `tick`; update; editorView)

**Interfaces:**
- Consumes: `ScriptaV2.Sync.SyncHighlight`, `ScriptaV2.Sync.fromMsg`, `ScriptaV2.Sync.highlightAttribute` (Task 1); the `highlight` attribute contract (Task 3).
- Produces: the end-to-end RL-sync behavior.

- [ ] **Step 1: Extend `ScriptaV2.Editor` Config + view**

In `src/ScriptaV2/Editor.elm`:

Add the import (after `import Json.Decode as D`):

```elm
import ScriptaV2.Sync
```

Add the field to `Config` (it now reads):

```elm
type alias Config msg =
    { source : String
    , onInput : String -> msg
    , highlight : Maybe ScriptaV2.Sync.SyncHighlight
    , attrs : List (Html.Attribute msg)
    }
```

Change `view` to splat the highlight attribute:

```elm
view : Config msg -> Html msg
view config =
    Html.node "codemirror-editor"
        (Html.Attributes.attribute "load" config.source
            :: Html.Events.on "text-change" (D.map config.onInput textChangeDecoder)
            :: (ScriptaV2.Sync.highlightAttribute config.highlight ++ config.attrs)
        )
        []
```

Update the module's doc comment list/exposing is unchanged (Config/view names are the same).

- [ ] **Step 2: Extend the DemoTOC+Sync model + init**

In `DemoTOC+Sync/src/Main.elm`:

Add the import (with the other `ScriptaV2.*` imports):

```elm
import ScriptaV2.Sync
```

Add two fields to `Model` (after `idsOfOpenNodes`):

```elm
    , syncHighlight : Maybe ScriptaV2.Sync.SyncHighlight
    , tick : Int
```

Seed them in `init` (after `idsOfOpenNodes = []`):

```elm
      , syncHighlight = Nothing
      , tick = 0
```

- [ ] **Step 3: Handle RL clicks in `update`**

Replace the whole `Render msg_ ->` branch with one that first tries `ScriptaV2.Sync.fromMsg`, then falls back to the existing TOC/SelectId handling:

```elm
        Render msg_ ->
            case ScriptaV2.Sync.fromMsg (model.tick + 1) msg_ of
                Just h ->
                    ( { model | syncHighlight = Just h, tick = model.tick + 1 }, Cmd.none )

                Nothing ->
                    case msg_ of
                        ScriptaV2.Msg.ToggleTOCNodeID nodeId ->
                            let
                                idsOfOpenNodes =
                                    if String.left 2 nodeId == "@-" then
                                        if List.member nodeId model.idsOfOpenNodes then
                                            List.Extra.remove nodeId model.idsOfOpenNodes

                                        else
                                            nodeId :: model.idsOfOpenNodes

                                    else
                                        model.idsOfOpenNodes
                            in
                            ( { model | idsOfOpenNodes = idsOfOpenNodes }, Cmd.none )

                        ScriptaV2.Msg.SelectId selId ->
                            if selId == "title" then
                                ( { model | selectId = selId }, jumpToTopOf ScriptaV2.Editor.renderedTextId )

                            else
                                ( { model | selectId = selId }, Cmd.none )

                        _ ->
                            ( model, Cmd.none )
```

(The old explicit `ScriptaV2.Msg.SendLineNumber _ -> ( model, Cmd.none )` branch is gone — `fromMsg` now handles `SendLineNumber` and `SendMeta`; everything else falls through to the `_` no-op.)

- [ ] **Step 4: Pass the highlight to the editor**

Change `editorView` to include the new field:

```elm
editorView : Model -> Html Msg
editorView model =
    ScriptaV2.Editor.view
        { source = model.initialText
        , onInput = InputText
        , highlight = model.syncHighlight
        , attrs = []
        }
```

- [ ] **Step 5: Build + regression net + demo build**

Run:
```bash
elm make src/ScriptaV2/APISimple.elm src/ScriptaV2/API.elm src/ScriptaV2/Types.elm src/ScriptaV2/Msg.elm src/ScriptaV2/Language.elm src/Render/Theme.elm src/ScriptaV2/Editor.elm src/ScriptaV2/Sync.elm --output=/dev/null
npx elm-test
(cd DemoTOC+Sync && elm make src/Main.elm --output=assets/main.js)
```
Expected: `Success!`, all tests pass, demo build `Success!`.

- [ ] **Step 6: Manual browser acceptance (human-run; the implementer reports build/test results and defers this)**

Run `cd DemoTOC+Sync && ./run.sh` (serves over HTTP, opens `http://localhost:8200/index.html`). Confirm:
- Click an inline **phrase** (e.g. a bold or linked word) → exactly that phrase's source span highlights in the editor and scrolls into view; the cursor is not moved.
- Click a **block / image / math** → its source line(s) highlight.
- Start **typing** → the highlight clears.
- Press **Escape** → the highlight clears.
- Clicking the **same** phrase again still re-scrolls (the `tick` changes).

A subagent cannot run a browser; it completes Steps 1–5, commits, and lists Step 6 as "deferred to human."

- [ ] **Step 7: Commit**

```bash
git add src/ScriptaV2/Editor.elm DemoTOC+Sync/src/Main.elm
git commit -m "feat(DemoTOC+Sync): wire RL sync — clicks drive the editor highlight"
```

---

## Self-Review

**Spec coverage:**
- Decision 1 (granularity: phrase inline / line-range block) → `fromMsg` (`SendMeta` → phrase, `SendLineNumber` → range), Task 1; editor.js `lineCount` branch, Task 3. ✓
- Decision 2 (decoration via `--cm-sync-highlight-bg`, clear on edit/Escape) → Task 3 Steps 2–3. ✓
- Decision 3 (Elm-driven) → only `editor.js` is JS; mapping is Elm. ✓
- Decision 4 (new `ScriptaV2.Sync`) → Task 1. ✓
- Decision 5 (stopPropagation on inline) → Task 2. ✓
- Decision 6 (editor-only, no rendered-side highlight) → no `selectedId` wiring added. ✓
- Component 1 (Render/Expression.elm) → Task 2. Component 2 (ScriptaV2.Sync) → Task 1. Component 3 (Editor extend) → Task 4 Step 1. Component 4 (editor.js) → Task 3. Component 5 (Main) → Task 4 Steps 2–4. ✓
- Data flow (click → fromMsg → model+tick → attribute → editor decorates+scrolls) → Task 4 + Task 3. ✓
- Indexing (inline line0+1, colEnd+1, block begin 0-indexed) → `fromMsg` tests (Task 1) + editor.js `to = from + colEnd + 1` (Task 3). ✓
- Error handling (unparseable id → Nothing; malformed/out-of-range JSON → ignore) → Task 1 `lineFromId`/tests; Task 3 try/catch + bounds check. ✓
- Testing (Sync unit tests; node --check; manual acceptance) → Tasks 1, 3, 4. ✓

**Build-green-per-task:** Task 1 (Sync added, unused) — regression net + demo build green. Task 2 (behavior-only) — green. Task 3 (editor.js only) — Elm builds unaffected. Task 4 (Config field + Main together) — the record-shape change and its consumer change land in one task, so the demo build is green at task end. ✓

**Placeholder scan:** none — all code blocks complete; the one non-unit-testable task (2) is explicitly justified and gated by compile + manual.

**Type consistency:** `SyncHighlight` fields (`line, colBegin, colEnd, lineCount, tick`) are identical across `fromMsg`, `encode`, the tests, `editor.js` JSON keys, `Editor.Config`, and `Main`. `fromMsg : Int -> MarkupMsg -> Maybe SyncHighlight` and `highlightAttribute : Maybe SyncHighlight -> List (Html.Attribute msg)` match their call sites in Task 4. `jumpToTopOf ScriptaV2.Editor.renderedTextId` matches the Phase-1 reconciliation already in `Main.elm`.
```

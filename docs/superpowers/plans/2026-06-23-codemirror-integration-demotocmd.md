# CodeMirror Integration for DemoTOCMd Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace DemoTOCMd's elm-ui `Input.multiline` source editor with a real CodeMirror 6 editor (a custom element), and rebuild the demo's app shell in plain `elm/html` + CSS.

**Architecture:** A new `ScriptaV2.Editor` compiler module renders a `<codemirror-editor>` custom element and decodes its `text-change` events. A small hand-written `editor.js` ES module defines that element against CodeMirror 6 loaded from a CDN. DemoTOCMd's `Main.elm` is rewritten to `elm/html` + CSS; the compiler's still-elm-ui rendered `body`/`toc` are bridged into the html app via `Element.layout`.

**Tech Stack:** Elm 0.19.1, `elm/html`, `elm/json`, `mdgriffith/elm-ui` (bridge only), CodeMirror 6 (esm.sh CDN), plain CSS.

## Global Constraints

- XMarkdown is the only language: `ScriptaV2.Language.SMarkdownLang`.
- Compiler regression net must pass after every change (from CLAUDE.md):
  `elm make src/ScriptaV2/APISimple.elm src/ScriptaV2/API.elm src/ScriptaV2/Types.elm src/ScriptaV2/Msg.elm src/ScriptaV2/Language.elm src/Render/Theme.elm --output=/dev/null` then `npx elm-test`.
- Modify `elm.json` dependencies only via `elm-json` (not needed here — no new Elm deps).
- Public entry points are exposed modules; `ScriptaV2.Editor` is added to `exposed-modules`.
- The editor's `load` attribute is bound to an **uncontrolled, constant** initial-text value, never to the live-edited text — re-binding `load` per keystroke causes cursor jumps.
- `editor.js` imports each CodeMirror package from esm.sh **without** `?bundle`, pinned to `@6`, so esm.sh serves a single shared `@codemirror/state` (avoids "unrecognized extension" from duplicate state instances).
- DemoTOCMd build check: `cd DemoTOCMd && elm make src/Main.elm --output=assets/main.js` → `Success!`.

---

### Task 1: `ScriptaV2.Editor` compiler module

**Files:**
- Create: `src/ScriptaV2/Editor.elm`
- Modify: `elm.json` (add `"ScriptaV2.Editor"` to `exposed-modules`)
- Test: `tests/EditorTest.elm`

**Interfaces:**
- Consumes: nothing (leaf module). Deps `elm/html`, `elm/json` (already package dependencies).
- Produces:
  - `type alias Config msg = { source : String, onInput : String -> msg, attrs : List (Html.Attribute msg) }`
  - `view : Config msg -> Html msg` — renders `Html.node "codemirror-editor"` with `load` attribute = `config.source` and an `on "text-change"` handler mapping to `config.onInput`.
  - `textChangeDecoder : D.Decoder String` — `D.at ["detail","source"] D.string`.
  - `renderedTextId : String` — `"__RENDERED_TEXT__"` (stable contract for Phase 2 RL sync).

- [ ] **Step 1: Write the failing test**

Create `tests/EditorTest.elm`:

```elm
module EditorTest exposing (suite)

import Expect
import Json.Decode as D
import ScriptaV2.Editor
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "ScriptaV2.Editor"
        [ test "textChangeDecoder extracts detail.source" <|
            \_ ->
                """{"detail":{"source":"hello","position":3}}"""
                    |> D.decodeString ScriptaV2.Editor.textChangeDecoder
                    |> Expect.equal (Ok "hello")
        , test "renderedTextId is the agreed container id" <|
            \_ ->
                ScriptaV2.Editor.renderedTextId
                    |> Expect.equal "__RENDERED_TEXT__"
        ]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx elm-test tests/EditorTest.elm`
Expected: FAIL — compile error, `ScriptaV2.Editor` module does not exist / `I cannot find module ScriptaV2.Editor`.

- [ ] **Step 3: Write the module**

Create `src/ScriptaV2/Editor.elm`:

```elm
module ScriptaV2.Editor exposing (Config, view, textChangeDecoder, renderedTextId)

{-| Reusable wiring for the `<codemirror-editor>` custom element (defined in JS,
e.g. DemoTOCMd/assets/editor.js).

@docs Config, view, textChangeDecoder, renderedTextId

-}

import Html exposing (Html)
import Html.Attributes
import Html.Events
import Json.Decode as D


{-| Configuration for [`view`](#view).

  - `source` is applied to the `load` attribute. Pass a value that changes
    ONLY on intentional external resets (e.g. an initial document). Binding it
    to live-edited text re-pushes the attribute on every keystroke and jumps
    the cursor.
  - `onInput` is fired for each user edit, carrying the full document text.
  - `attrs` are extra attributes the caller adds (e.g. a sizing class).

-}
type alias Config msg =
    { source : String
    , onInput : String -> msg
    , attrs : List (Html.Attribute msg)
    }


{-| Render the editor custom element. -}
view : Config msg -> Html msg
view config =
    Html.node "codemirror-editor"
        (Html.Attributes.attribute "load" config.source
            :: Html.Events.on "text-change" (D.map config.onInput textChangeDecoder)
            :: config.attrs
        )
        []


{-| Decode the `text-change` CustomEvent, extracting the full source text from
`event.detail.source`.
-}
textChangeDecoder : D.Decoder String
textChangeDecoder =
    D.at [ "detail", "source" ] D.string


{-| The DOM id agreed for the rendered-text container. Phase 2 RL-sync JS binds
its click/selection handlers to this id.
-}
renderedTextId : String
renderedTextId =
    "__RENDERED_TEXT__"
```

- [ ] **Step 4: Expose the module**

In `elm.json`, add `"ScriptaV2.Editor"` to `exposed-modules` (after `"Render.Theme"`):

```json
    "exposed-modules": [
        "ScriptaV2.APISimple",
        "ScriptaV2.API",
        "ScriptaV2.Types",
        "ScriptaV2.Msg",
        "ScriptaV2.Language",
        "Render.Theme",
        "ScriptaV2.Editor"
    ],
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `npx elm-test tests/EditorTest.elm`
Expected: PASS — 2 tests pass.

- [ ] **Step 6: Run the compiler regression net**

Run:
```bash
elm make src/ScriptaV2/APISimple.elm src/ScriptaV2/API.elm src/ScriptaV2/Types.elm src/ScriptaV2/Msg.elm src/ScriptaV2/Language.elm src/Render/Theme.elm src/ScriptaV2/Editor.elm --output=/dev/null
npx elm-test
```
Expected: `Success!` and all tests pass.

- [ ] **Step 7: Commit**

```bash
git add src/ScriptaV2/Editor.elm tests/EditorTest.elm elm.json
git commit -m "feat: add ScriptaV2.Editor — codemirror-editor custom-element wiring"
```

---

### Task 2: `editor.js` custom element + index.html/style.css host

**Files:**
- Create: `DemoTOCMd/assets/editor.js`
- Create: `DemoTOCMd/assets/style.css`
- Modify: `DemoTOCMd/assets/index.html`

**Interfaces:**
- Consumes: `ScriptaV2.Editor.view` renders `<codemirror-editor load="…">` and listens for `text-change`. This task defines that element and emits `text-change` with `{ detail: { source, position } }`.
- Produces: a registered `codemirror-editor` custom element; CSS classes `app`, `app-header`, `panels`, `panel`, `editor-panel`, `rendered-panel`, `toc-panel` and `:root` `--cm-*` variables consumed by Task 3.

- [ ] **Step 1: Write `editor.js`**

Create `DemoTOCMd/assets/editor.js`:

```js
// Minimal CodeMirror 6 custom element for DemoTOCMd.
// Imports without ?bundle so esm.sh shares one @codemirror/state instance
// (duplicate state instances cause "unrecognized extension" errors).
import { basicSetup, EditorView } from "https://esm.sh/codemirror@6.0.1";
import { EditorState } from "https://esm.sh/@codemirror/state@6";

const lightTheme = EditorView.theme(
    {
        "&": {
            color: "var(--cm-fg, #1a1a1a)",
            backgroundColor: "var(--cm-bg, #ffffff)",
            height: "100%",
        },
        ".cm-content": {
            caretColor: "var(--cm-caret, rgba(255,80,0,0.7))",
            fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace",
            fontSize: "14px",
        },
        ".cm-cursor, .cm-dropCursor": {
            borderLeftColor: "var(--cm-caret, rgba(255,80,0,0.7))",
            borderLeftWidth: "2px",
        },
        ".cm-scroller": { overflow: "auto" },
        "&.cm-focused > .cm-scroller > .cm-selectionLayer .cm-selectionBackground, .cm-selectionBackground, .cm-content ::selection":
            { backgroundColor: "var(--cm-selection-bg, #d7e6ff)" },
        ".cm-gutters": {
            backgroundColor: "var(--cm-gutter-bg, #f4f4f4)",
            color: "var(--cm-gutter-fg, #999)",
            border: "none",
        },
    },
    { dark: false }
);

function sendText(editor) {
    const event = new CustomEvent("text-change", {
        detail: {
            source: editor.state.doc.toString(),
            position: editor.state.selection.main.head,
        },
        bubbles: true,
        composed: true,
    });
    editor.dom.dispatchEvent(event);
}

class CodemirrorEditor extends HTMLElement {
    static get observedAttributes() {
        return ["load"];
    }

    constructor() {
        super();
        // Attribute changes can arrive before the EditorView exists (it is
        // created in a deferred setTimeout). Buffer them here.
        this.pendingAttributes = {};
    }

    connectedCallback() {
        this.style.display = "block";
        this.style.height = "100%";

        // Defer creation one tick so layout/dimensions settle first.
        setTimeout(() => {
            const editor = new EditorView({
                state: EditorState.create({
                    doc: "",
                    extensions: [
                        basicSetup,
                        lightTheme,
                        EditorView.lineWrapping,
                        EditorView.updateListener.of((v) => {
                            if (!v.docChanged) return;
                            if (editor.isProgrammaticUpdate) {
                                editor.isProgrammaticUpdate = false; // suppress echo
                            } else {
                                sendText(editor);
                            }
                        }),
                    ],
                }),
                parent: this,
            });
            this.editor = editor;

            for (const attr in this.pendingAttributes) {
                this.handleAttributeChange(attr, this.pendingAttributes[attr]);
            }
            this.pendingAttributes = {};
        }, 0);
    }

    handleAttributeChange(attr, value) {
        if (attr === "load" && typeof value === "string") {
            const editor = this.editor;
            // Replace the whole document without echoing a text-change back to Elm.
            editor.isProgrammaticUpdate = true;
            editor.dispatch({
                changes: { from: 0, to: editor.state.doc.length, insert: value },
            });
        }
    }

    attributeChangedCallback(attr, oldVal, newVal) {
        if (this.editor) {
            this.handleAttributeChange(attr, newVal);
        } else {
            this.pendingAttributes[attr] = newVal;
        }
    }
}

customElements.define("codemirror-editor", CodemirrorEditor);
```

- [ ] **Step 2: Syntax-check `editor.js`**

Run: `node --check DemoTOCMd/assets/editor.js`
Expected: no output, exit 0 (valid ES-module syntax; `node --check` does not resolve imports).

- [ ] **Step 3: Write `style.css`**

Create `DemoTOCMd/assets/style.css`:

```css
:root {
    --cm-fg: #1a1a1a;
    --cm-bg: #ffffff;
    --cm-caret: rgba(255, 80, 0, 0.7);
    --cm-selection-bg: #d7e6ff;
    --cm-gutter-bg: #f4f4f4;
    --cm-gutter-fg: #999999;
    /* Reserved for Phase 2 RL sync */
    --cm-sync-highlight-bg: #fff3b0;
}

html, body {
    margin: 0;
    height: 100%;
}

.app {
    display: flex;
    flex-direction: column;
    height: 100vh;
    background: #666666;
    font-family: ui-sans-serif, system-ui, sans-serif;
}

.app-header {
    color: #e6e6e6;
    font-weight: 700;
    text-align: center;
    padding: 10px 0;
}

.panels {
    display: flex;
    gap: 16px;
    padding: 0 16px 16px;
    flex: 1;
    min-height: 0;
}

.panel {
    background: #ffffff;
    border-radius: 4px;
    overflow: auto;
    min-height: 0;
}

.editor-panel {
    padding: 0;
    overflow: hidden; /* CodeMirror manages its own scrolling */
}

.editor-panel codemirror-editor {
    display: block;
    height: 100%;
}

.rendered-panel,
.toc-panel {
    padding: 16px 24px;
    font-size: 14px;
}
```

- [ ] **Step 4: Wire `index.html`**

In `DemoTOCMd/assets/index.html`, add inside `<head>` (after the existing `<script src="katex.js"></script>` line) these two lines:

```html
    <link rel="stylesheet" href="style.css">
    <script type="module" src="editor.js"></script>
```

The final `<head>` of `DemoTOCMd/assets/index.html` should read:

```html
<head>
    <meta charset="UTF-8">
    <title>XMarkdown TOC Demo</title>

    <script src="katex.js"></script>

    <link rel="stylesheet" href="style.css">
    <script type="module" src="editor.js"></script>

    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.12.0/dist/katex.min.css" integrity="sha384-AfEj0r4/OFrOo5t7NnNe46zW/tFgW6x/bCJG8FqQCEo3+Aro6EYUG4+cU+KJWu/X" crossorigin="anonymous">

    <script defer src="https://cdn.jsdelivr.net/npm/webfontloader@1.6.28/webfontloader.js" integrity="sha256-4O4pS1SH31ZqrSO2A/2QJTVjTPqVe+jnYgOWUVr7EEc=" crossorigin="anonymous"></script>

    <script src="main.js"></script>

</head>
```

- [ ] **Step 5: Commit**

```bash
git add DemoTOCMd/assets/editor.js DemoTOCMd/assets/style.css DemoTOCMd/assets/index.html
git commit -m "feat(DemoTOCMd): add codemirror-editor custom element + CSS app shell"
```

---

### Task 3: Rewrite `DemoTOCMd/src/Main.elm` to elm/html

**Files:**
- Modify: `DemoTOCMd/src/Main.elm` (full rewrite)

**Interfaces:**
- Consumes: `ScriptaV2.Editor.view` (Task 1); CSS classes + `--cm-*` vars (Task 2); `ScriptaV2.Compiler.compile : CompilerParameters -> List String -> CompilerOutput` where `CompilerOutput.body : List (Element MarkupMsg)` and `CompilerOutput.toc : List (Element MarkupMsg)`.
- Produces: the runnable DemoTOCMd app (no authored elm-ui except the `Element.layout` bridge).

- [ ] **Step 1: Replace `Main.elm` with the elm/html version**

Replace the entire contents of `DemoTOCMd/src/Main.elm` with:

```elm
module Main exposing (main)

import Browser
import Browser.Dom
import Browser.Events
import Data.XMarkdown
import Element
import Html exposing (Html, div, text)
import Html.Attributes exposing (class, id, style)
import List.Extra
import ScriptaV2.Compiler
import ScriptaV2.Editor
import ScriptaV2.Language
import ScriptaV2.Msg exposing (MarkupMsg)
import ScriptaV2.Types exposing (Filter(..), defaultCompilerParameters)
import Task


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


subscriptions : Model -> Sub Msg
subscriptions _ =
    Browser.Events.onResize GotNewWindowDimensions


type alias Model =
    { initialText : String
    , sourceText : String
    , count : Int
    , windowWidth : Int
    , windowHeight : Int
    , selectId : String
    , idsOfOpenNodes : List String
    }


type Msg
    = NoOp
    | InputText String
    | Render MarkupMsg
    | GotNewWindowDimensions Int Int


type alias Flags =
    { window : { windowWidth : Int, windowHeight : Int } }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { initialText = Data.XMarkdown.text
      , sourceText = Data.XMarkdown.text
      , count = 0
      , windowWidth = flags.window.windowWidth
      , windowHeight = flags.window.windowHeight
      , selectId = "@InitID"
      , idsOfOpenNodes = []
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        GotNewWindowDimensions width height ->
            ( { model | windowWidth = width, windowHeight = height }, Cmd.none )

        InputText str ->
            ( { model | sourceText = str, count = model.count + 1 }, Cmd.none )

        Render msg_ ->
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
                        ( { model | selectId = selId }, jumpToTopOf "rendered-text" )

                    else
                        ( { model | selectId = selId }, Cmd.none )

                ScriptaV2.Msg.SendLineNumber _ ->
                    ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )



-- GEOMETRY


type alias Geometry =
    { editorW : Int, renderedW : Int, tocW : Int, docWidth : Int }


geometry : Model -> Geometry
geometry model =
    let
        tocW =
            200

        gap =
            16

        pad =
            24

        avail =
            model.windowWidth - tocW - 4 * gap

        half =
            max 240 (avail // 2)
    in
    { editorW = half, renderedW = half, tocW = tocW, docWidth = half - 2 * pad }



-- VIEW


view : Model -> Html Msg
view model =
    let
        g =
            geometry model

        params =
            { defaultCompilerParameters
                | lang = ScriptaV2.Language.SMarkdownLang
                , docWidth = g.docWidth
                , editCount = model.count
                , selectedId = "selectedId"
                , idsOfOpenNodes = model.idsOfOpenNodes
                , filter = NoFilter
            }

        compilerOutput =
            ScriptaV2.Compiler.compile params (String.lines model.sourceText)
    in
    div [ class "app" ]
        [ div [ class "app-header" ] [ text "XMarkdown TOC Demo" ]
        , div [ class "panels" ]
            [ div [ class "panel editor-panel", style "width" (px g.editorW) ]
                [ editorView model ]
            , div
                [ class "panel rendered-panel"
                , id "rendered-text"
                , style "width" (px g.renderedW)
                ]
                [ Html.map Render (renderPanel compilerOutput.body) ]
            , div [ class "panel toc-panel", style "width" (px g.tocW) ]
                [ Html.map Render (renderPanel compilerOutput.toc) ]
            ]
        ]


editorView : Model -> Html Msg
editorView model =
    ScriptaV2.Editor.view
        { source = model.initialText
        , onInput = InputText
        , attrs = []
        }


{-| Bridge the compiler's still-elm-ui output into the html app. -}
renderPanel : List (Element.Element MarkupMsg) -> Html MarkupMsg
renderPanel elements =
    Element.layout [ Element.width Element.fill ]
        (Element.column
            [ Element.spacing 12, Element.width Element.fill ]
            elements
        )


px : Int -> String
px n =
    String.fromInt n ++ "px"


jumpToTopOf : String -> Cmd Msg
jumpToTopOf elementId =
    Browser.Dom.getViewportOf elementId
        |> Task.andThen (\_ -> Browser.Dom.setViewportOf elementId 0 0)
        |> Task.attempt (\_ -> NoOp)
```

- [ ] **Step 2: Build the demo**

Run: `cd DemoTOCMd && elm make src/Main.elm --output=assets/main.js`
Expected: `Success!`

If it fails on a `CompilerParameters` field name (e.g. `docWidth`, `editCount`, `selectedId`, `lang`, `idsOfOpenNodes`, `filter`), open `src/ScriptaV2/Types.elm`, find the `CompilerParameters`/`defaultCompilerParameters` record, and correct the field name to match — do not invent fields. These names are copied from the pre-rewrite `Main.elm`, so they should already match.

- [ ] **Step 3: Run the compiler regression net (unchanged compiler must still pass)**

Run (from repo root):
```bash
elm make src/ScriptaV2/APISimple.elm src/ScriptaV2/API.elm src/ScriptaV2/Types.elm src/ScriptaV2/Msg.elm src/ScriptaV2/Language.elm src/Render/Theme.elm src/ScriptaV2/Editor.elm --output=/dev/null
npx elm-test
```
Expected: `Success!` and all tests pass.

- [ ] **Step 4: Manual browser verification (acceptance)**

Run: `cd DemoTOCMd && ./run.sh` (starts elm-watch, opens `assets/index.html`).
Confirm in the browser:
- (a) The left panel shows a CodeMirror editor pre-filled with the sample document, with line numbers and line wrapping.
- (b) Typing in the editor live-updates the middle (Rendered Text) panel and the right (Table of Contents) panel.
- (c) No cursor jump or focus loss while typing continuously.
- (d) Clicking a TOC section toggles its open/closed nodes.
- (e) Inline/display math still renders (KaTeX unaffected).

If (c) fails (cursor jumps to end each keystroke), confirm `editorView` passes `model.initialText` (NOT `model.sourceText`) to `ScriptaV2.Editor.view`.

- [ ] **Step 5: Commit**

```bash
git add DemoTOCMd/src/Main.elm DemoTOCMd/assets/main.js
git commit -m "feat(DemoTOCMd): rewrite app shell to elm/html + CodeMirror editor"
```

Note: `DemoTOCMd/assets/main.js` is git-ignored (`DemoTOCMd/.gitignore`), so the `git add` of it is a no-op — that is expected; only `Main.elm` is committed.

---

## Self-Review

**Spec coverage:**
- Component 1 (minimal `editor.js` custom element, `load` in / `text-change` out, echo-safe, pendingAttributes) → Task 2, Step 1. ✓
- Component 2 (`ScriptaV2.Editor` module: `Config`, `view`, `textChangeDecoder`, `renderedTextId`; exposed) → Task 1. ✓
- Component 3 (`Main.elm` rewrite to elm/html; editor panel; `Element.layout` bridge for body/toc; geometry → `docWidth`; `Render`/`SendLineNumber` no-op preserved; `id "rendered-text"` for `jumpToTopOf`) → Task 3. ✓
- Component 4 (`style.css` with `--cm-*` vars; `index.html` `<link>` + `<script type=module>`) → Task 2, Steps 3–4. ✓
- Data flow (init seeds `load` once; typing → `text-change` → `InputText`; TOC toggle; `SendLineNumber` no-op) → Tasks 2–3. ✓
- Testing (regression net; demo build; manual acceptance) → Tasks 1 Step 6, 3 Steps 2–4. ✓
- Out of scope (RL sync) → not implemented; `renderedTextId` + `--cm-sync-highlight-bg` left as seams. ✓

**Deviations from spec (intentional, noted):**
- Spec said `load` bound to `model.sourceText`; corrected to a constant `model.initialText` (uncontrolled editor) to prevent per-keystroke cursor jumps. The compiler still reads live text from `model.sourceText`.
- Spec's "CDN `?bundle`" corrected to esm.sh imports without `?bundle` so a single `@codemirror/state` is shared (the actual mechanism that achieves the spec's "single instance" intent).

**Placeholder scan:** none — all code blocks are complete; manual-verification steps enumerate concrete checks.

**Type consistency:** `Config`, `view`, `textChangeDecoder`, `renderedTextId` names match between Task 1 (definition), the test, and Task 3 (use). `renderPanel : List (Element.Element MarkupMsg) -> Html MarkupMsg` consumes `compilerOutput.body`/`.toc` (both `List (Element MarkupMsg)`) and is wrapped by `Html.map Render` in `view`. `geometry`/`Geometry` field names (`editorW`, `renderedW`, `tocW`, `docWidth`) are consistent between definition and use.
```

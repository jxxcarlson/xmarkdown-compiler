# The Editor ↔ Main Interface

*How `Main.elm` talks to the CodeMirror editor, and what each side must
implement. Reference implementation: `DemoTOC+Sync/`.*

This document is an implementation guide. If all you have is the XMarkdown
compiler (`XMarkdown.API`, `XMarkdown.Types`, `Render.Theme`), it tells you
everything you need to build both sides of the editor integration: the Elm
side (`Main.elm` + a small `Ports.elm`) and the JavaScript side (a CodeMirror 6
custom element + a small glue script).

Reference files:

| Role | File |
|---|---|
| Elm host app | `DemoTOC+Sync/src/Main.elm` |
| Elm ports | `DemoTOC+Sync/src/Ports.elm` |
| CodeMirror custom element | `DemoTOC+Sync/assets/editor.js` (bundled to `editor-bundle.js`) |
| JS glue (Elm init + port wiring) | `DemoTOC+Sync/assets/app.js` |
| KaTeX custom element | `DemoTOC+Sync/assets/katex.js` |
| HTML entry point | `DemoTOC+Sync/assets/index.html` |
| Library: editor wiring | `XMarkdown.Editor` (src/XMarkdown/Editor.elm) |
| Library: RL-sync mapping | `XMarkdown.Sync` (src/XMarkdown/Sync.elm) |
| Library: public API | `XMarkdown.API` (src/XMarkdown/API.elm) |

---

## 1. Architecture: how Main communicates with the editor

The editor is **not** an Elm widget. It is a CodeMirror 6 instance wrapped in a
**custom element** `<codemirror-editor>`, defined in JavaScript. Elm renders the
element with `Html.node "codemirror-editor"` and communicates with it through
four channels:

```
            ┌────────────────────────  Elm (Main.elm)  ───────────────────────┐
            │                                                                 │
   (a) attributes            (b) DOM CustomEvents            (c) ports        │
   Elm → editor              editor → Elm                    both directions  │
            │                         │                              │        │
            ▼                         │                              ▼        │
  ┌──────────────────────┐            │                   ┌──────────────────┐
  │ <codemirror-editor   │────────────┘                   │ app.js (glue)    │
  │    load="..."        │  "text-change" event           │ subscribes to    │
  │    highlight="..." > │  "lr-sync" event (via glue)    │ Elm ports, sets  │
  └──────────────────────┘                                │ CSS variables,   │
                                                          │ injects <style>  │
                                                          └──────────────────┘
```

### (a) Elm → editor: attributes on the custom element

Elm's virtual DOM writes two attributes; the custom element observes them
(`observedAttributes`, editor.js:445–447) and reacts:

| Attribute | Payload | Meaning |
|---|---|---|
| `load` | the raw source text | **Replace the whole document.** Pushed only on intentional resets (initial document, Open File, New File) — never on every keystroke. |
| `highlight` | compact JSON, e.g. `{"mode":"lines","start":3,"end":5,"tick":7}` | **RL sync**: paint a highlight over the given source span and scroll it into view. |

The `highlight` JSON is produced by `XMarkdown.Sync.encode`
(src/XMarkdown/Sync.elm:100–109) and has exactly four fields:

```json
{ "mode": "chars" | "lines", "start": Int, "end": Int, "tick": Int }
```

- `mode = "chars"` — `start`/`end` are **absolute document character
  offsets**, `end` **exclusive**. Used for inline (phrase) clicks.
- `mode = "lines"` — `start`/`end` are **1-indexed source line numbers**,
  both **inclusive**. Used for block clicks.
- `tick` — a monotonic counter. Its only job is to make the attribute string
  *different* when the user clicks the same span twice, so Elm's virtual DOM
  actually re-writes the attribute and the editor re-fires.

### (b) Editor → Elm: DOM CustomEvents

The custom element dispatches two `CustomEvent`s with `bubbles: true,
composed: true`:

| Event | `detail` | Fired when | Received by |
|---|---|---|---|
| `text-change` | `{ source : String, position : Int }` | the user edits the document (programmatic `load` updates are suppressed) | Elm directly, via `Html.Events.on "text-change"` on the element |
| `lr-sync` | `{ text : String }` | the user selects text and presses **Ctrl/Cmd-S** | app.js, which forwards `detail.text` into the `lrSyncRequest` port |

`text-change` needs no port: because Elm rendered the element, it can attach a
normal event handler to it. The decoder is
`XMarkdown.Editor.textChangeDecoder` (src/XMarkdown/Editor.elm:50–52):

```elm
textChangeDecoder : D.Decoder String
textChangeDecoder =
    D.at [ "detail", "source" ] D.string
```

`lr-sync` *does* go through a port, because its consumer (Main's LR-sync
search) lives outside the editor element's event path in this design; app.js
listens at the document level (app.js:26–32).

### (c) Ports (four of them, all small)

`DemoTOC+Sync/src/Ports.elm` (13 lines, the entire module):

```elm
port lrSyncRequest : (String -> msg) -> Sub msg            -- JS → Elm
port injectHighlightCSS : String -> Cmd msg                -- Elm → JS
port setEditorHighlightColor : String -> Cmd msg           -- Elm → JS
port setThemeColors : { fg : String, bg : String } -> Cmd msg  -- Elm → JS
```

- `lrSyncRequest` — carries the selected text from the editor's Ctrl-S
  keybinding into Main's `LRSync` message (**LR sync**, editor → rendered
  text).
- `injectHighlightCSS` — Main builds a CSS rule targeting
  `[data-line-number="N"]` and app.js injects it as a `<style>` tag
  (app.js:36–50), highlighting the matched block in the rendered pane.
- `setEditorHighlightColor` — sets the CSS variable
  `--cm-sync-highlight-bg` so the editor's RL-sync highlight color matches the
  compiler's `params.highlightColor` (app.js:53–56).
- `setThemeColors` — sets `--cm-fg` / `--cm-bg` on `:root` when the user
  toggles Light/Dark, so the editor theme follows the app theme (app.js:58–63).

Only `lrSyncRequest` is essential to the sync interface; the other three are
styling conveniences (the CodeMirror theme reads all colors from CSS variables
with fallbacks, editor.js:335–361).

### The two sync directions, end to end

**RL sync (rendered text → editor).** Every rendered block carries an
`onClick` handler emitting `SendLineNumber { begin, end }`
(`Render.Sync.rightToLeftSyncHelper`, src/Render/Sync.elm:57–59). This arrives
in Main as `Render (SendLineNumber ...)`. Main maps it with
`XMarkdown.API.fromMsgToSyncHighlight` to a `SyncHighlight`, stores it
(bumping `tick`), and re-renders — which writes the `highlight` attribute.
The custom element decodes it, computes CodeMirror `from`/`to` offsets, paints
a `.cm-sync-highlight` decoration, and scrolls it into view
(editor.js:531–578).

The `MarkupMsg` variants relevant to sync (`XMarkdown.Types`,
src/XMarkdown/Types.elm:102–108):

```elm
type MarkupMsg
    = SendMeta { begin : Int, end : Int, index : Int, id : String }
    | SendLineNumber { begin : Int, end : Int }
    | SelectId String
    | HighlightId String
    | JumpToTop
    | MMNoOp
```

- `SendLineNumber` — block click. `begin` is the block's first line
  (1-indexed); `end = begin + numberOfLines`, so the last *inclusive* line is
  `end - 1`. → `mode = "lines"`.
- `SendMeta` — inline (phrase) click. `begin`/`end` are absolute document
  character offsets, `end` *inclusive*. → `mode = "chars"`, `to = end + 1`.
  **Note:** as of July 2026 the renderer emits only `SendLineNumber`;
  `SendMeta` is fully supported by the interface (`XMarkdown.Sync.fromMsg`
  handles it, src/XMarkdown/Sync.elm:84–86) but has no emit site in `Render/`.
  Implement the `"chars"` path anyway — it costs three lines of JS.
- `SelectId` — a TOC entry click (`Render.TOCTree`,
  src/Render/TOCTree.elm:98–108). Not editor-related; Main uses it to scroll
  the rendered pane.

The offset mapping lives in `XMarkdown.Sync.fromMsg`
(src/XMarkdown/Sync.elm:81–94) — use it via the re-export
`XMarkdown.API.fromMsgToSyncHighlight` rather than reimplementing it. The
module's header comment (src/XMarkdown/Sync.elm:30–66) explains the
coordinate-systems crux; the classic bug is treating inline `begin`/`end` as
within-line columns.

**LR sync (editor → rendered text).** The user selects text in the editor and
presses Ctrl/Cmd-S. The editor dispatches `lr-sync`; app.js forwards the text
into `lrSyncRequest`; Main's `LRSync` handler
(DemoTOC+Sync/src/Main.elm:184–239):

1. calls `XMarkdown.API.searchBlocksContainingText params (String.lines
   model.sourceText) searchText`, getting a `List BlockMatch` where

   ```elm
   type alias BlockMatch =
       { id : String            -- "e-<lineNumber>.<editCount>"
       , lineNumber : Int
       , numberOfLines : Int
       , sourceText : String
       }
   ```

   (src/XMarkdown/Compiler.elm:111–116; search is case-insensitive substring
   over each block's `sourceText`, src/XMarkdown/Compiler.elm:180–198);
2. cycles through matches on repeated identical searches
   (`modBy (List.length matches)`);
3. scrolls the rendered pane to the match (`Browser.Dom`, falling back from
   the element id to a `[data-line-number="N"]` selector,
   DemoTOC+Sync/src/Main.elm:421–440);
4. highlights it by sending a CSS rule through `injectHighlightCSS`.

---

## 2. What the CodeMirror side must implement

One ES module defining the `codemirror-editor` custom element. The reference
is `DemoTOC+Sync/assets/editor.js` (592 lines, most of it optional syntax
highlighting and theme). The *required* behavior is:

### 2.1 Custom element skeleton

```js
import { basicSetup, EditorView } from "codemirror";
import { EditorState, StateField, StateEffect } from "@codemirror/state";
import { Decoration, keymap } from "@codemirror/view";

class CodemirrorEditor extends HTMLElement {
    static get observedAttributes() { return ["load", "highlight"]; }

    constructor() {
        super();
        this.pendingAttributes = {};   // see 2.5
    }

    connectedCallback() {
        this.style.display = "block";
        this.style.height = "100%";
        setTimeout(() => {             // defer so layout settles (see 2.5)
            this.editor = new EditorView({ state: ..., parent: this });
            for (const attr in this.pendingAttributes)
                this.handleAttributeChange(attr, this.pendingAttributes[attr]);
            this.pendingAttributes = {};
        }, 0);
    }

    attributeChangedCallback(attr, _old, newVal) {
        if (this.editor) this.handleAttributeChange(attr, newVal);
        else this.pendingAttributes[attr] = newVal;
    }
}
customElements.define("codemirror-editor", CodemirrorEditor);
```

No shadow DOM — the EditorView is appended directly to the element
(`parent: this`), so page CSS variables reach it.

### 2.2 `text-change`: report user edits, suppress programmatic echo

Two cooperating pieces (editor.js:432–442, 501–508, 522–529):

```js
function sendText(editor) {
    editor.dom.dispatchEvent(new CustomEvent("text-change", {
        detail: { source: editor.state.doc.toString(),
                  position: editor.state.selection.main.head },
        bubbles: true, composed: true,
    }));
}

// in extensions:
EditorView.updateListener.of((v) => {
    if (!v.docChanged) return;
    if (editor.isProgrammaticUpdate) {
        editor.isProgrammaticUpdate = false;   // a `load` write — swallow it
    } else {
        sendText(editor);
    }
})

// in handleAttributeChange:
if (attr === "load" && typeof value === "string") {
    editor.isProgrammaticUpdate = true;
    editor.dispatch({ changes: { from: 0, to: editor.state.doc.length, insert: value } });
}
```

The echo suppression matters: without it, every `load` (Open File, New File)
would bounce a `text-change` back into Elm, which would bump `editCount` and,
in the worst case, loop. Elm sets the document; Elm already knows its content.

The `detail` **must** contain `source` (the full document text) — that is what
`XMarkdown.Editor.textChangeDecoder` reads. `position` is currently unused by
the Elm side but cheap to include.

### 2.3 `highlight`: decode, decorate, scroll (RL sync)

State plumbing — an effect pair and a `StateField` providing decorations
(editor.js:9–33):

```js
const setSyncHighlight = StateEffect.define();
const clearSyncHighlight = StateEffect.define();
const syncMark = Decoration.mark({ class: "cm-sync-highlight" });

const syncHighlightField = StateField.define({
    create: () => Decoration.none,
    update(deco, tr) {
        for (const e of tr.effects) {
            if (e.is(setSyncHighlight))
                return Decoration.set([syncMark.range(e.value.from, e.value.to)]);
            if (e.is(clearSyncHighlight)) return Decoration.none;
        }
        if (tr.docChanged) return Decoration.none;  // any edit clears it
        return deco.map(tr.changes);
    },
    provide: (f) => EditorView.decorations.from(f),
});
```

Attribute handler (editor.js:531–578). This is where the two coordinate
systems from Section 1 are resolved into CodeMirror offsets — get the clamping
and the inclusive/exclusive conventions exactly right:

```js
if (attr === "highlight" && typeof value === "string") {
    let h;
    try { h = JSON.parse(value); } catch (e) { return; }  // malformed: ignore
    if (!h) return;
    const doc = this.editor.state.doc;
    let from, to;
    if (h.mode === "lines") {
        // start/end are 1-indexed source lines, both inclusive.
        const firstLine = Math.max(1, Math.min(h.start, doc.lines));
        const lastLine  = Math.max(firstLine, Math.min(h.end, doc.lines));
        from = doc.line(firstLine).from;
        to   = doc.line(lastLine).to;
    } else {
        // "chars": absolute document character offsets, end exclusive.
        from = Math.max(0, Math.min(h.start, doc.length));
        to   = Math.max(from, Math.min(h.end, doc.length));
    }
    this.editor.dispatch({ effects: [setSyncHighlight.of({ from, to })] });
    // Center the target line by writing the scroller's scrollTop directly.
    this.editor.requestMeasure({
        read: (view) => {
            const block = view.lineBlockAt(from);
            const scroller = view.scrollDOM;
            return {
                scroller,
                target: block.top - (scroller.clientHeight - block.height) / 2,
            };
        },
        write: ({ scroller, target }) => {
            scroller.scrollTop = target;   // browser clamps to [0, max]
        },
    });
}
```

Note the clamping: the highlight was computed against the text *the compiler
last saw*; if the user has since edited, raw offsets could be out of range and
CodeMirror throws on invalid positions.

**Why not `EditorView.scrollIntoView(from, { y: "center" })`?** That effect
walks the editor's *ancestor* elements too, and `overflow: hidden` boxes are
still programmatically scrollable — so centering a line near the end of the
document maxes out the editor's own scroller and then drags the app shell
itself upward, scrolling the page layout out of view. A direct `scrollTop`
write inside `requestMeasure` (CodeMirror's sanctioned read-then-write cycle)
is clamped by the browser to the scroller's own valid range: true centering
mid-document, a graceful clamp at the ends, and the ancestors never move.

### 2.4 Keybindings: Escape and Mod-S (LR sync)

(editor.js:474–500)

```js
keymap.of([
    { key: "Escape",
      run: (view) => { view.dispatch({ effects: clearSyncHighlight.of(null) }); return true; } },
    { key: "Mod-s",
      run: (view) => {
          const sel = view.state.sliceDoc(view.state.selection.main.from,
                                          view.state.selection.main.to);
          if (sel) {
              view.dom.dispatchEvent(new CustomEvent("lr-sync", {
                  detail: { text: sel }, bubbles: true, composed: true }));
          }
          return true;   // also swallows the browser's Save dialog
      } },
])
```

### 2.5 Two timing details you cannot skip

1. **Defer EditorView creation one tick** (`setTimeout(..., 0)` in
   `connectedCallback`) so the element's layout/dimensions settle before
   CodeMirror measures them.
2. **Buffer early attribute writes.** Elm sets `load` (and possibly
   `highlight`) on the element *before* your deferred EditorView exists.
   `attributeChangedCallback` must stash values in `pendingAttributes` and
   replay them once the editor is up (editor.js:449–454, 514–518, 581–587).
   Without this, the initial document silently fails to load.

### 2.6 Theme via CSS variables

Style the editor with an `EditorView.theme` whose colors are CSS variables
with fallbacks (editor.js:335–361), so the page (via ports) can restyle it
without touching CodeMirror:

```js
"&": { color: "var(--cm-fg, #1a1a1a)", backgroundColor: "var(--cm-bg, #ffffff)", height: "100%" },
".cm-sync-highlight": { backgroundColor: "var(--cm-sync-highlight-bg, #fff3b0)" },
```

Also include `EditorView.lineWrapping` and `basicSetup` in the extensions.

### 2.7 Bundling and serving

Bundle the module with esbuild (`DemoTOC+Sync/build-editor.js`):

```js
esbuild.build({ entryPoints: ['assets/editor.js'], bundle: true,
                outfile: 'assets/editor-bundle.js', format: 'esm', platform: 'browser' })
```

and load it with `<script type="module" src="editor-bundle.js">`. ES modules
do not load over `file://` — the app **must be served over HTTP**
(`DemoTOC+Sync/run.sh` uses elm-watch + a static server; avoid ports
8000–8010).

### 2.8 The glue script (app.js)

Not part of the custom element, but part of the JS side's contract
(`DemoTOC+Sync/assets/app.js`, 64 lines total):

```js
var app = Elm.Main.init({ node: root, flags: { window: { windowWidth: ..., windowHeight: ... } } });
init(app);   // katex.js's loader (KaTeX + mhchem from CDN)

document.addEventListener('lr-sync', (e) => {
    if (e.detail && e.detail.text) app.ports.lrSyncRequest.send(e.detail.text);
}, true);

app.ports.injectHighlightCSS.subscribe((css) => { /* replace #lr-sync-highlight-style <style> tag */ });
app.ports.setEditorHighlightColor.subscribe((c) => document.documentElement.style.setProperty('--cm-sync-highlight-bg', c));
app.ports.setThemeColors.subscribe((c) => { /* set --cm-fg, --cm-bg */ });
```

(If your rendered text includes math, you also need the `math-text` custom
element from `DemoTOC+Sync/assets/katex.js` — the compiler's output emits
`<math-text data-content="..." data-display="...">` nodes. That element must
implement `attributeChangedCallback` re-rendering, or live math edits show
stale KaTeX.)

---

## 3. What Main must implement

`Main.elm` is a plain `Browser.element`. The library does the fiddly parts;
Main's job is state, wiring, and the LR-sync search.

### 3.1 Model — and the crucial `initialText` / `sourceText` split

```elm
type alias Model =
    { initialText : String          -- what the editor was last *loaded* with
    , sourceText : String           -- live text, updated on every keystroke
    , count : Int                   -- edit counter → params.editCount
    , selectId : String             -- id of clicked block → params.selectedId
    , syncHighlight : Maybe SyncHighlight   -- RL-sync span for the editor
    , tick : Int                    -- monotonic counter for syncHighlight
    , theme : Theme
    , windowWidth : Int, windowHeight : Int
    , lrSyncMatches : List XMarkdown.API.BlockMatch   -- LR-sync state
    , lrSyncIndex : Int
    , lrSyncText : String
    , ...
    }
```

**The one rule that keeps the cursor alive:** the editor's `load` attribute is
bound to `initialText`, *never* to `sourceText`. `sourceText` changes on every
keystroke; if `load` were bound to it, every keystroke would re-push the whole
document into CodeMirror and reset the cursor. `initialText` changes only on
intentional resets — init, `FileLoaded`, `NewFileRequested`
(DemoTOC+Sync/src/Main.elm:121–145). This is also documented on
`XMarkdown.Editor.Config` (src/XMarkdown/Editor.elm:18–27).

### 3.2 Rendering the editor

Use the library helper — it assembles the attributes exactly as Section 1
describes (src/XMarkdown/Editor.elm:37–44):

```elm
editorView : Model -> Html Msg
editorView model =
    XMarkdown.API.viewEditor
        { source = model.initialText          -- → the `load` attribute
        , onInput = InputText                 -- ← the `text-change` event
        , highlight = model.syncHighlight     -- → the `highlight` attribute
        , attrs = []                          -- e.g. sizing class
        }
```

Which is nothing more than:

```elm
Html.node "codemirror-editor"
    (Html.Attributes.attribute "load" config.source
        :: Html.Events.on "text-change" (D.map config.onInput textChangeDecoder)
        :: (XMarkdown.Sync.highlightAttribute config.highlight ++ config.attrs)
    )
    []
```

`highlightAttribute` (src/XMarkdown/Sync.elm:115–123) emits
`attribute "highlight" (encode h)` when there is a highlight, and nothing
otherwise.

### 3.3 Compiling and rendering the document

In `view`, compile `sourceText` with parameters that carry the live state
(DemoTOC+Sync/src/Main.elm:292–311):

```elm
params =
    { defaultCompilerParameters
        | docWidth = g.docWidth
        , editCount = model.count        -- rendered text will NOT update without this
        , selectedId = model.selectId
        , theme = model.theme
    }

compilerOutput =
    XMarkdown.API.compileOutput params model.sourceText
```

`compilerOutput.body` and `.toc` are `List (Html MarkupMsg)`; wrap them with
`Html.map Render` to fold the compiler's messages into your `Msg` type. Give
the rendered-pane container `id XMarkdown.API.renderedTextId`
(`"__RENDERED_TEXT__"`, src/XMarkdown/Editor.elm:58–60) — the scrolling code
addresses the pane by that id.

### 3.4 Messages and update

The minimum message set for the interface:

```elm
type Msg
    = InputText String        -- text-change from the editor
    | Render MarkupMsg        -- clicks in the rendered text / TOC
    | LRSync String           -- lrSyncRequest port (Ctrl-S in the editor)
    | ...
```

**`InputText`** (DemoTOC+Sync/src/Main.elm:112–113) — store the text, bump
the counter, *do not touch `initialText`*:

```elm
InputText str ->
    ( { model | sourceText = str, count = model.count + 1 }, Cmd.none )
```

**`Render`** (DemoTOC+Sync/src/Main.elm:241–256) — first try to interpret the
message as an RL-sync click; `fromMsgToSyncHighlight` returns `Just` for
`SendMeta`/`SendLineNumber` and `Nothing` for everything else:

```elm
Render msg_ ->
    case fromMsgToSyncHighlight (model.tick + 1) msg_ of
        Just h ->
            ( { model | syncHighlight = Just h, tick = model.tick + 1 }, Cmd.none )

        Nothing ->
            case msg_ of
                SelectId selId ->
                    -- TOC click: scroll the rendered pane to the block.
                    -- selId has the form "e-<lineNumber>.<editCount>".
                    ( { model | selectId = selId }, jumpToTopOfWithLineNumber selId lineNum )

                _ ->
                    ( model, Cmd.none )
```

Storing the highlight re-renders the view, which re-renders the editor with
the new `highlight` attribute — that *is* the delivery mechanism. The `tick`
bump is what makes clicking the same block twice work.

**`LRSync`** (DemoTOC+Sync/src/Main.elm:184–239) — search, cycle, scroll,
highlight:

```elm
LRSync searchText ->
    let
        matches =
            XMarkdown.API.searchBlocksContainingText params (String.lines model.sourceText) searchText

        newIndex =
            if searchText == model.lrSyncText && not (List.isEmpty matches) then
                (model.lrSyncIndex + 1) |> modBy (List.length matches)   -- repeat search cycles
            else
                0
    in
    case List.drop newIndex matches |> List.head of
        Just match ->
            ( { model | lrSyncMatches = matches, lrSyncIndex = newIndex
                      , lrSyncText = searchText
                      , selectId = String.fromInt match.lineNumber }
            , Cmd.batch
                [ jumpToTopOfWithLineNumber match.id match.lineNumber
                , Ports.injectHighlightCSS css   -- see below
                ] )

        Nothing ->
            ( { model | lrSyncMatches = matches, ... }, Cmd.none )
```

The highlight CSS targets the `data-line-number` attribute the renderer puts
on every block, plus its descendants (DemoTOC+Sync/src/Main.elm:219–229):

```css
[data-line-number="N"]   { background-color: <highlightColor> !important; }
[data-line-number="N"] * { background-color: <highlightColor> !important; }
```

### 3.5 Subscriptions and ports

```elm
port module Ports exposing (lrSyncRequest, injectHighlightCSS, setEditorHighlightColor, setThemeColors)

port lrSyncRequest : (String -> msg) -> Sub msg
port injectHighlightCSS : String -> Cmd msg
port setEditorHighlightColor : String -> Cmd msg
port setThemeColors : { fg : String, bg : String } -> Cmd msg
```

```elm
subscriptions _ =
    Sub.batch
        [ Browser.Events.onResize GotNewWindowDimensions
        , Ports.lrSyncRequest LRSync
        ]
```

On `init`, send the compiler's highlight color to the editor so both panes
highlight in the same color (DemoTOC+Sync/src/Main.elm:99):

```elm
( model, Ports.setEditorHighlightColor params.highlightColor )
```

On theme toggle, push the new fg/bg (DemoTOC+Sync/src/Main.elm:174–182):

```elm
Ports.setThemeColors
    { fg = currentTheme.text |> Color.toCssString
    , bg = currentTheme.background |> Color.toCssString }
```

### 3.6 Scrolling the rendered pane

`jumpToTopOfWithLineNumber` (DemoTOC+Sync/src/Main.elm:421–475) is ordinary
`Browser.Dom` work, but two details are interface-relevant:

- **Two-step element lookup**: try `Browser.Dom.getElement elementId` (the
  `"e-<line>.<count>"` id), and on failure fall back to the selector
  `[data-line-number="N"]`. Ids embed `editCount`, so an id computed before
  an edit may no longer exist; line numbers are stabler.
- **Scroll the container, not the window**: compute the target's position
  relative to the `renderedTextId` container's content and
  `Browser.Dom.setViewportOf XMarkdown.API.renderedTextId 0 targetScroll`.

---

## 4. Interface contract — quick reference

Everything both sides must agree on, in one table:

| Contract item | Value | Producer | Consumer |
|---|---|---|---|
| Custom element tag | `codemirror-editor` | editor.js | `XMarkdown.Editor.view` |
| Document-reset attribute | `load` (raw text) | Elm | editor.js |
| Highlight attribute | `highlight` = `{"mode","start","end","tick"}` JSON | `XMarkdown.Sync.encode` | editor.js |
| `mode:"chars"` semantics | absolute doc char offsets, end **exclusive** | `Sync.fromMsg` (from `SendMeta`, end inclusive → `+1`) | editor.js char path |
| `mode:"lines"` semantics | 1-indexed lines, both **inclusive** | `Sync.fromMsg` (from `SendLineNumber`, `end - 1`) | editor.js line path |
| Edit event | `text-change`, `detail.source : String` | editor.js | `XMarkdown.Editor.textChangeDecoder` |
| LR-sync event | `lr-sync`, `detail.text : String` (Ctrl/Cmd-S on selection) | editor.js | app.js → `lrSyncRequest` port |
| LR-sync port | `lrSyncRequest : (String -> msg) -> Sub msg` | app.js | Main `LRSync` |
| Rendered-pane id | `"__RENDERED_TEXT__"` (`XMarkdown.API.renderedTextId`) | Main's view | Main's scroll code |
| Block line marker | `data-line-number="N"` on rendered blocks | Render pipeline | highlight CSS + scroll fallback |
| Block/TOC element id | `"e-<lineNumber>.<editCount>"` | Render pipeline / `BlockMatch.id` | scroll code |
| Highlight color variable | `--cm-sync-highlight-bg` | app.js (from `setEditorHighlightColor`) | editor theme CSS |
| Theme variables | `--cm-fg`, `--cm-bg` | app.js (from `setThemeColors`) | editor theme CSS |

## 5. Pitfalls checklist

1. **Never bind `load` to the live text.** Bind it to `initialText`; binding
   to `sourceText` resets the cursor on every keystroke.
2. **Suppress the programmatic echo.** A `load` write must not re-emit
   `text-change` (the `isProgrammaticUpdate` flag).
3. **Buffer attributes that arrive before the EditorView exists** and replay
   them; otherwise the initial document is lost.
4. **Respect the coordinate systems.** Inline offsets are *document* offsets,
   not within-line columns; inline `end` is inclusive at the `MarkupMsg` level
   and exclusive in the `highlight` JSON; block lines are 1-indexed inclusive.
   Read the header of `XMarkdown.Sync` (src/XMarkdown/Sync.elm:30–66) before
   touching any of it.
5. **Clamp offsets in editor.js.** The highlight was computed against an
   older document state; unclamped positions can throw.
6. **Bump `tick` on every highlight**, or repeat clicks on the same span do
   nothing (the attribute string wouldn't change, so Elm's VDOM won't rewrite
   it).
7. **Bump `editCount` on every edit**, or the rendered pane won't update
   (block ids are memoized against it).
8. **Serve over HTTP.** The editor bundle is an ES module; `file://` yields a
   white screen. Avoid ports 8000–8010.
9. **`math-text` must observe attribute changes** (katex.js:39–41), or live
   math edits render stale KaTeX.

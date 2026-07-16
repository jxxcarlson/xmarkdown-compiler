# Design: CodeMirror integration for DemoTOC+Sync (Phase 1)

**Date:** 2026-06-23
**Status:** Approved design, pre-implementation
**Scope:** Phase 1 only — replace DemoTOC+Sync's `elm-ui` source input with a real
CodeMirror 6 editor, rebuild the app shell in plain `elm/html` + CSS, test,
commit, push. **RL sync is Phase 2** and is explicitly out of scope here (but
this phase leaves the seams for it).

## Goal

Today `DemoTOC+Sync` edits source text in an `Element.Input.multiline` (a styled
`<textarea>`). RL sync (preview → editor: click rendered text, the editor
selects/scrolls/highlights the matching source) needs a real editor we can drive
programmatically. Phase 1 swaps in CodeMirror 6 via a custom element, following
the proven pattern in `scripta-app-v4` (`editor-prepare/editor.js` +
`Editor.elm`), and rebuilds the demo's UI in plain `elm/html` + CSS instead of
`elm-ui`.

## Decisions (locked during brainstorming)

1. **Minimal `editor.js`** — a small (~80–120 line) CodeMirror 6 custom element
   with a hardcoded light theme, not the full v4 bundle. RL-sync infrastructure
   (sync-highlight decoration field, `scrollToCenter`, Scripta syntax
   highlighting) is deliberately **deferred to Phase 2**.
2. **New compiler module `ScriptaV2.Editor`** — the reusable Elm wiring (custom
   element view + event decoders + the `renderedTextId` constant) lives in the
   compiler package so every consuming app shares it. Added to `elm.json`
   `exposed-modules`.
3. **Plain CSS** — one external stylesheet (`assets/style.css`) owns both the app
   chrome and the `--cm-*` theme tokens the editor reads. No `elm-css`.
4. **App shell only (no `elm-ui` authored in the app)** — the 3-panel layout,
   headers, and editor are `elm/html` + CSS. The compiler's rendered output is
   still `Element MarkupMsg`; we bridge it into the html app with a single
   `Element.layout` call per rendered panel. The app keeps a transitive `elm-ui`
   dependency but never *writes* `elm-ui`. Migrating `Render/*` off `elm-ui` is a
   separate, much larger project, not part of this work.

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│ DemoTOC+Sync/assets/index.html                                     │
│   <link rel="stylesheet" href="style.css">   (app + --cm-* vars)│
│   <script src="editor.js">     defines <codemirror-editor>      │
│   <script src="katex.js">      (existing)                       │
│   <script src="main.js">       Elm app, mounts to #main         │
└────────────────────────────────────────────────────────────────┘
        │ Elm renders Html (plain elm/html + CSS classes)
        ▼
┌───────────────┬──────────────────────────┬─────────────────────┐
│ <codemirror-  │ rendered body             │ TOC                 │
│  editor        │  (compiler Element →      │  (compiler Element  │
│  load="src">   │   Element.layout → Html)  │   → Element.layout) │
└───────────────┴──────────────────────────┴─────────────────────┘
   load attr in          ▲ compile(params, lines)
   text-change out ──────┘ ScriptaV2.Compiler.compile
```

### Component 1 — `assets/editor.js` (new, minimal custom element)

Defines `customElements.define("codemirror-editor", …)`. Authored by hand as a
small, readable **ES module** committed as `assets/editor.js` and loaded with
`<script type="module" src="editor.js">`. To avoid a node/bundler step entirely,
it imports CodeMirror 6 from a CDN **bundle** (e.g. `https://esm.sh/codemirror@6?bundle`
plus `@codemirror/state`/`@codemirror/view`/`@codemirror/commands`/
`@codemirror/autocomplete` from the same `?bundle` origin). The `?bundle` form
inlines shared deps so there is a single `@codemirror/state` instance —
duplicate-instance is the classic cause of CodeMirror "unrecognized extension"
errors. This is consistent with how the demo already pulls KaTeX and webfonts
from CDNs. The module runs immediately on load and registers the element; the
demo's `run.sh`/`elm-watch` flow is unchanged. (If offline/repro builds later
matter, swapping the CDN imports for a committed rollup bundle is a drop-in
change — same module source.)

Contract:

- **Observed attribute `load`** (String): the source text. On change, replace the
  whole document. Guard with an `isProgrammaticUpdate` flag so this replacement
  does **not** echo a `text-change` event. Uses the `pendingAttributes` pattern
  from v4 because the `EditorView` is created in a deferred `setTimeout` and the
  attribute may arrive first.
- **Emits `text-change`** CustomEvent `{ detail: { source: String, position: Int } }`
  on every user edit (via `EditorView.updateListener`, skipped when
  `isProgrammaticUpdate`). `bubbles: true, composed: true`.
- Extensions: `basicSetup`, `EditorView.lineWrapping`, `closeBrackets()`, a
  hardcoded light `EditorView.theme`. (No Scripta syntax highlighting, no search
  panel theming, no `wrapWithMark`/`indentBlockOptTab` — Phase 2+ if wanted.)

**Echo safety:** Elm binds `load = model.sourceText`. After a keystroke,
`text-change` → `InputText` sets `sourceText` to the value CM already holds, so
Elm's vdom diff sees `load` unchanged and never re-touches the attribute — no
cursor reset, no loop. The only `load` change that fires is a genuine external
one (initial mount).

### Component 2 — `src/ScriptaV2/Editor.elm` (new compiler module)

Reusable, `elm/html`-based, no `elm-ui`. Public API (Phase 1):

```elm
module ScriptaV2.Editor exposing (Config, view, textChangeDecoder, renderedTextId)

type alias Config msg =
    { source : String          -- bound to the `load` attribute
    , onInput : String -> msg  -- fired from the text-change event
    , attrs : List (Html.Attribute msg)  -- caller-supplied (e.g. class for sizing)
    }

view : Config msg -> Html msg
-- Html.node "codemirror-editor"
--   ( Html.Attributes.attribute "load" config.source
--     :: Html.Events.on "text-change" (D.map config.onInput textChangeDecoder)
--     :: config.attrs ) []

textChangeDecoder : Decoder String   -- D.at ["detail","source"] D.string

renderedTextId : String              -- "__RENDERED_TEXT__" — stable contract for Phase 2 RL sync
```

`renderedTextId` is included now (cheap, stable) so the Phase 2 RL-sync JS has a
fixed container id to bind to. Deps used: `elm/html`, `elm/json` (both already
package dependencies). Added to `elm.json` `exposed-modules`.

### Component 3 — `src/Main.elm` (rewrite to elm/html)

- **Remove** all `Element.*` imports except the bridge (`Element.layout`,
  `Element.column`, and minimal layout attrs used only to wrap compiler output).
- `Browser.element` with `view : Model -> Html Msg`.
- Model is unchanged (`sourceText`, `count`, window dims, `selectId`,
  `idsOfOpenNodes`).
- **Editor panel:** `ScriptaV2.Editor.view { source = model.sourceText, onInput = InputText, attrs = [ class "editor-panel" ] }`.
- **Rendered + TOC panels:** bridge each via
  `Element.layout [] (Element.column [...] compilerOutput.body)` (and `.toc`),
  then `Html.map Render`. Wrapped in `div [ class "rendered-panel" ] [ … ]`.
- **Layout:** a `div [ class "app" ]` containing a header and a
  `div [ class "panels" ]` (CSS flex row) with three panel `div`s. Widths/heights
  via CSS; the rendered panel's pixel width is still computed in Elm and passed as
  `params.docWidth` (the compiler needs it for line wrapping) and mirrored onto
  the panel via inline `style "width"`.
- `update` is unchanged except `InputText` (now fed by the editor event instead
  of `Input.multiline`) and the existing `Render`/`SendLineNumber` no-op stays.

### Component 4 — `assets/style.css` (new) + `assets/index.html` (edit)

- `style.css`: `.app`, `.panels` (flex), `.editor-panel`/`.rendered-panel`/`.toc-panel`
  (widths, heights, white bg, borders, fonts), and a `:root { --cm-fg; --cm-bg;
  --cm-selection-bg; … }` block. Even with a hardcoded JS theme we keep a small
  `:root` block so Phase 2's sync-highlight color has a home.
- `index.html`: add `<link rel="stylesheet" href="style.css">` and
  `<script type="module" src="editor.js">` in `<head>`. Elm still mounts to `#main`
  with the same flags (`window` dims). `katex.js` unchanged. (A custom element
  defined after Elm inserts the node still upgrades automatically, so module load
  order vs. `main.js` is not critical.)

## Data flow

1. **Init:** `model.sourceText = Data.XMarkdown.text`. First render emits
   `<codemirror-editor load="…">`. Element upgrades, `load` applied once → CM doc
   seeded (no echo).
2. **Typing:** CM fires `text-change` → decoded → `InputText newSource` →
   `model.sourceText = newSource`, `count += 1`. `compile` re-runs → new `body`
   + `toc`. `load` re-render is a no-op (value unchanged).
3. **TOC toggle / select:** unchanged — `Render (ToggleTOCNodeID …)` etc. through
   the existing update branches.
4. **`SendLineNumber`** (block click) still no-ops — RL sync is Phase 2.

## Testing

- **Compiler regression net** (from CLAUDE.md), must pass:
  ```
  elm make src/ScriptaV2/APISimple.elm src/ScriptaV2/API.elm src/ScriptaV2/Types.elm \
           src/ScriptaV2/Msg.elm src/ScriptaV2/Language.elm src/Render/Theme.elm --output=/dev/null
  npx elm-test
  ```
- **Demo build:** `cd DemoTOC+Sync && elm make src/Main.elm --output=assets/main.js` → `Success!`
  (this is what actually type-checks `ScriptaV2.Editor`, since Main imports it).
- **Manual (the real acceptance):** `./run.sh`, then in the browser confirm:
  (a) the editor renders with the sample doc and CodeMirror chrome (line wrap,
  bracket closing); (b) typing in the editor live-updates the rendered panel and
  TOC; (c) no cursor jump / focus loss while typing; (d) clicking a TOC node still
  toggles open/closed; (e) math still renders (katex unaffected).

## Out of scope (Phase 2 — RL sync)

- Sync-highlight `StateField`/effect, `scrollToCenter`, capture-phase click/
  selection handlers in the bundle.
- RL markers (`data-begin`/`data-end`/`id`) on rendered elements — note the
  compiler already emits `onClick (SendLineNumber …)` per block
  (`Render/Sync.elm:74`) and `onClick (SendMeta …)` per inline expr
  (`Render/Expression.elm`); Phase 2 decides whether RL sync rides the Elm update
  loop (using those) or the JS/DOM-attribute path (like v4).
- Wiring `renderedTextId` onto the rendered container and driving the editor from
  clicks.

## Risks / notes

- **`Element.layout` bridge:** elm-ui's `layout` injects a scoped reset
  stylesheet and establishes a stacking context. Acceptable inside a panel; if it
  visually fights the CSS, fall back to `Element.layoutWith { options = [...] }`.
- **No bundler in the demo:** `editor.js` is a hand-written ES module importing
  CodeMirror from a CDN `?bundle` URL — no node toolchain, no committed blob.
  Trade-off: needs network at runtime (same as KaTeX today). A pinned version in
  the URL keeps it deterministic; a committed rollup bundle is the offline
  fallback if ever needed.
- **Geometry:** keeping Elm-computed `docWidth` avoids a measurement round-trip;
  good enough for a demo. A later cleanup could move to pure CSS + ResizeObserver.
```

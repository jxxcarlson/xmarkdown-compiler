# Design: RL Sync (rendered → editor) for DemoTOCMd

**Date:** 2026-06-24
**Status:** Approved design, pre-implementation
**Branch:** `feat/rl-sync` (foundation commit `c242211` already landed — see below)

## Goal

RL sync is the **preview → editor** direction: click rendered text and the
CodeMirror source editor paints a background highlight over the corresponding
source span and scrolls it into view. v1 supports:

- **Phrase-level** precision for inline clicks (using the within-line column
  spans the compiler now emits).
- **Line-range** highlight for block clicks (images, math blocks, list items,
  block padding / non-text regions).

Highlight is a non-intrusive **background decoration** (does not move the cursor
or selection); it clears on edit and on Escape.

## Foundation already in place (commit `c242211`)

The XMarkdown inline parser previously discarded source columns
(`begin = 0, end = 0`) for every styled/structured expression. Commit `c242211`
added `stackSpan` in `XMarkdown/Expression.elm` so every inline expression now
carries accurate `(line via id, begin, end)` within-line columns. Verified by
`tests/XMarkdownSpanTest.elm`. This is the data RL sync consumes.

## Decisions (locked during brainstorming)

1. **Granularity:** phrase-level for inline, line-range for blocks.
2. **Highlight style:** CodeMirror background decoration via a `StateField`,
   colored with the reserved `--cm-sync-highlight-bg` CSS var. Not selection.
3. **Architecture:** Elm-driven. The compiler already emits `onClick` per
   element; clicks route through the Elm update loop as `MarkupMsg`. Only the
   decoration/scroll application is JS.
4. **Mapping module:** a **new `ScriptaV2.Sync`** module owns the
   `MarkupMsg → SyncHighlight` mapping and its JSON encoding. `ScriptaV2.Editor`
   only renders the resulting attribute.
5. **Inline-click collision:** inline `onClick` uses **`stopPropagation`** so a
   phrase click reports only the phrase, not the enclosing block. (Behavior-only
   change in `Render/Expression.elm`; rendered output is unchanged.)
6. **Editor-only for v1:** no rendered-side highlight of the clicked element
   (the compiler's `selectedId` rendered-highlight is a separate concern, out of
   scope here).

## The collision being fixed (why decision 5 matters)

In `Render/Block.elm`, the paragraph container carries the block-level
`Render.Sync.rightToLeftSyncHelper … → onClick (SendLineNumber …)` and is an
**ancestor** of the inline expression els, which each carry
`onClick (SendMeta …)`. A DOM click on a phrase bubbles to both, firing
`SendMeta` (precise) **and** `SendLineNumber` (whole block). Without
intervention the block message arrives last and clobbers the phrase target.
`stopPropagation` on the inline handler makes phrase clicks report only the
phrase; clicks that land on block padding / non-text still reach the block
handler and produce a line-range highlight.

## Architecture

```
 Rendered panel (elm-ui, bridged)         CodeMirror editor (<codemirror-editor>)
 ┌───────────────────────────┐            ┌──────────────────────────────┐
 │ inline el  onClick SendMeta│  click     │  .cm-sync-highlight band over │
 │ block el   onClick SendLine│ ───────┐   │  the mapped range + scroll    │
 └───────────────────────────┘        │   └──────────────────────────────┘
        │ Element.layout + Html.map Render   ▲
        ▼                                    │ highlight="{json}" attribute
   DemoTOCMd update (Render msg_)            │
        │  ScriptaV2.Sync.fromMsg tick msg_  │
        ▼                                    │
   model.syncHighlight : Maybe SyncHighlight │
        └── ScriptaV2.Editor.view {highlight}┘
```

### Component 1 — `src/Render/Expression.elm` (compiler, behavior-only)

Replace the inline `Events.onClick (SendMeta meta)` on the `Text` and `Fun`
cases with a stop-propagation click handler, so the event does not bubble to the
enclosing block's `SendLineNumber` handler:

```elm
Element.htmlAttribute
    (Html.Events.stopPropagationOn "click"
        (Json.Decode.succeed ( SendMeta meta, True )))
```

Applied at the `Text`, marked/`Fun`, `anchor`, `mark`, and default `Fun` sites
that currently use `Events.onClick (SendMeta meta)` (≈ lines 41, 76, 96, 100).
`htmlId meta.id` stays. No change to rendered output, only event propagation.

### Component 2 — `src/ScriptaV2/Sync.elm` (new compiler module)

Owns the mapping and encoding. Pure, fully unit-testable.

```elm
module ScriptaV2.Sync exposing (SyncHighlight, fromMsg, encode, highlightAttribute)

type alias SyncHighlight =
    { line : Int        -- 1-indexed CodeMirror line of the span start
    , colBegin : Int    -- within-line start column (0 for whole-line/block)
    , colEnd : Int      -- within-line end column, inclusive (0 for whole-line/block)
    , lineCount : Int   -- 0 for a single-line phrase; > 0 for a block line range
    , tick : Int        -- monotonic; makes repeat clicks re-trigger scroll
    }

-- Maps the two RL-relevant MarkupMsgs to a highlight; Nothing for others.
--  SendMeta {begin,end,index,id}: line parsed from id ("e-<line0>.<tok>") then
--      line = line0 + 1, colBegin = begin, colEnd = end, lineCount = 0.
--  SendLineNumber {begin,end}: line = begin + 1, lineCount = end - begin,
--      colBegin = colEnd = 0.   (begin is 0-indexed; see Indexing.)
fromMsg : Int -> MarkupMsg -> Maybe SyncHighlight

-- JSON for the custom-element attribute: {"line":..,"colBegin":..,"colEnd":..,"lineCount":..,"tick":..}
encode : SyncHighlight -> String

-- Convenience: the Html attribute to splat onto the editor node, or [] if Nothing.
highlightAttribute : Maybe SyncHighlight -> List (Html.Attribute msg)
```

`fromMsg` parses the line from `meta.id` using `ScriptaV2.Config.expressionIdPrefix`
(`"e-"`) — strip prefix, take the part before `"."`, `String.toInt`. On any parse
failure → `Nothing` (no highlight rather than a wrong one).

### Component 3 — `src/ScriptaV2/Editor.elm` (extend)

`Config` gains `highlight : Maybe ScriptaV2.Sync.SyncHighlight`. `view` splats
`ScriptaV2.Sync.highlightAttribute config.highlight` onto the
`codemirror-editor` node alongside the existing `load` attribute and
`text-change` handler.

### Component 4 — `DemoTOCMd/assets/editor.js` (extend)

- Add `"highlight"` to `observedAttributes`.
- Add a sync-highlight `StateField` + `setSyncHighlight`/`clearSyncHighlight`
  `StateEffect`s and a `Decoration.mark({ class: "cm-sync-highlight" })`
  (mirrors the scripta-app-v4 pattern). `.cm-sync-highlight` background =
  `var(--cm-sync-highlight-bg)` (already in `style.css`; add the `.cm-sync-highlight`
  rule to the editor theme).
- On `highlight` attribute change: parse JSON (guarded). Compute `from`/`to`:
  - **block** (`lineCount > 0`): `from = doc.line(line).from`,
    `to = doc.line(min(line + lineCount, doc.lines)).to`.
  - **phrase** (`lineCount === 0`): `from = doc.line(line).from + colBegin`,
    `to = doc.line(line).from + colEnd + 1`.
  - Bounds-check `line` against `doc.lines`; out of range → no-op.
  - dispatch `setSyncHighlight({from,to})` + `EditorView.scrollIntoView(from, {y:"center"})`.
  The `tick` field changing guarantees the attribute value differs on each click,
  so Elm re-pushes it and the editor re-applies/re-scrolls.
- Clear the decoration on user edit (in the existing `updateListener` `docChanged`
  branch, when not a programmatic update) and on `Escape` (a keymap entry).

### Component 5 — `DemoTOCMd/src/Main.elm` (extend)

- `Model` gains `syncHighlight : Maybe ScriptaV2.Sync.SyncHighlight` and
  `tick : Int` (seed `Nothing` / `0`).
- `update`'s `Render msg_` branch: alongside the existing `ToggleTOCNodeID` /
  `SelectId` handling, compute `ScriptaV2.Sync.fromMsg (model.tick + 1) msg_`;
  if `Just h`, set `syncHighlight = Just h`, `tick = model.tick + 1`. The
  existing `SendLineNumber _ -> no-op` branch is replaced by this handling.
- `editorView` passes `highlight = model.syncHighlight` to `ScriptaV2.Editor.view`.

## Data flow

1. Click rendered text → `Element.Events`/stopPropagation handler →
   `SendMeta` (inline, precise) or `SendLineNumber` (block) → `Html.map Render`
   → `update (Render msg_)`.
2. `ScriptaV2.Sync.fromMsg (tick+1) msg_` → `Just SyncHighlight` → stored,
   `tick` bumped.
3. `editorView` renders `highlight="{json}"`; the value differs each click (tick).
4. `editor.js` parses, maps line+cols → absolute `from`/`to`, dispatches the
   decoration effect + scroll.
5. User types → `docChanged` → decoration cleared. Escape → cleared.

## Indexing (pinned by unit tests)

- Inline `id` line is **0-indexed** (verified: first line → `e-0.x`) → CM `line = line0 + 1`.
- Inline `begin/end` are **inclusive** within-line columns (verified:
  `**world**` → 6..14) → editor uses `to = from + colEnd + 1`.
- Block `SendLineNumber.begin` = `block.meta.lineNumber`, treated as
  **0-indexed** → CM `line = begin + 1`; `lineCount = end - begin`. The exact
  block line-range arithmetic is **verified empirically** in the implementation
  (a `fromMsg` unit test with known inputs, plus the manual browser check) —
  if blocks turn out to be 1-indexed, the `+1` is dropped; the test is the
  source of truth.

## Error handling

- `fromMsg` returns `Nothing` on unparseable `id` → no highlight (never a wrong one).
- `editor.js` guards `JSON.parse` and bounds-checks the line; malformed/empty/
  out-of-range → clear or no-op, never throw.
- A `MarkupMsg` that is neither `SendMeta` nor `SendLineNumber` → `fromMsg`
  returns `Nothing`; the other `Render` branches (TOC toggle, SelectId) are
  unaffected.

## Testing

- **`ScriptaV2.Sync` (the meat):** elm-test unit tests for `fromMsg` —
  `SendMeta {begin=6,end=14,id="e-12.4"}` → `{line=13,colBegin=6,colEnd=14,lineCount=0,tick=t}`;
  `SendLineNumber {begin=4,end=6}` → `{line=5,…,lineCount=2}`; an unparseable id → `Nothing`;
  a non-RL `MarkupMsg` → `Nothing`. Plus an `encode` round-trip / shape test.
- **Compiler regression net** (CLAUDE.md) + the existing span tests stay green.
- **`editor.js`:** `node --check` syntax gate.
- **Manual browser acceptance (real gate):** served over HTTP (`./run.sh`),
  click an inline phrase → exactly that phrase highlights in the source and
  scrolls into view; click a block/image → its source line(s) highlight; typing
  clears the highlight; Escape clears it; cursor is not moved by a sync.

## Out of scope / future

- **Word-level** precision (sub-phrase): would need pixel→character mapping
  (`caretRangeFromPoint`) — deferred; phrase-level is the v1 target.
- **Rendered-side highlight** of the clicked element (needs the `selectedId`
  wiring the Phase-1 final review flagged).
- **Prose id uniqueness:** prose runs share `id = "e-<line>.0"` (see the
  `prose-run-id-collision` memory). RL sync keys off `line + begin/end`, so this
  doesn't block v1; clean up `Expression.elm:189` if unique ids are ever needed.
- **LR sync** (editor → preview) and drag-select range sync.
```

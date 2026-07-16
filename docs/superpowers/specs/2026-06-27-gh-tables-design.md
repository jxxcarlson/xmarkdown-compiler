# Design: GitHub-flavored Markdown (GFM) tables

**Date:** 2026-06-27
**Branch:** `gh-table`
**Status:** Approved design, pre-implementation

## Goal

Render GitHub-flavored markdown tables in XMarkdown:

```
| Name  | Age | Occupation    |
|-------|----:|---------------|
| Alice |  29 | Engineer      |
| Bob   |  34 | Musician      |
```

- The **separator row** (line 2, e.g. `|---|---:|---|`) is required; it both marks
  the block as a table and gives per-column alignment.
- Alignment tokens: `---` left (default), `:---` left, `:---:` center, `---:` right.
- The row **above** the separator is the header (standard GFM — always present when
  it is a table).
- Cells hold **inline markdown/math**, e.g. `[m G]`, `$…$`, `[6, 10, 11]`.

New rendering code lives in a new module `Render.GHTable`. The dead old table code
(`Render.Table`, its registration, leftover `tabular` bits) is removed.

## Key fact (decided the architecture)

A GFM table source **already parses to a single primitive block**: the XMarkdown
block parser groups the contiguous `|`-lines into one block (first line → heading,
remaining lines → body), splitting only on blank lines. `block.meta.sourceText`
holds the full, in-order source. **No change to the core primitive-block parser is
needed** — we detect the table by shape and re-interpret that one block.

(Verified empirically: parsing the 4-line example yields one `Ordinary "Name"`
block whose `sourceText` is all four lines.)

## Decisions (locked in brainstorming)

1. **Standard GFM** header rule: separator required; header is the row above it. No
   separator ⇒ not a table.
2. **Detection by shape**, not a `| table` keyword: first source line is a pipe-row
   AND the second line matches the separator pattern.
3. **Parse-time** (not render-time): `Generic.Pipeline.toExpressionBlock` builds the
   table AST (cells inline-parsed via the `exprParser` it already holds);
   `Render.GHTable` only renders. Keeps layering clean (Render → parse, not the
   reverse) and parses once.
4. **Rendering** via elm-ui `Element.table` (column-indexed) for auto-sized columns
   and native per-column alignment.
5. **Reuse the existing AST shape** `Right [ Fun "table" [ Fun "row" [ Fun "cell" exprs ] ] ]`.

## Architecture

```
source lines ──(primitive block parser, unchanged)──▶ one Ordinary block
                                                       (firstLine=header,
                                                        sourceText=all rows)
        │
        ▼  Generic.Pipeline.toExpressionBlock
  isGFMTable block ?  ──no──▶ existing handling (block unchanged)
        │ yes
        ▼
  gfmTableToExpressionBlock exprParser block
   - split sourceText into lines: header=0, separator=1, data=2..
   - parse separator → List Alignment, store in properties "alignments"="l,r,c,…"
   - for each row (header + data): split on "|", drop empty outer cells,
     pad/truncate to header column count, inline-parse each cell text → exprs
   - body := Right [ Fun "table" (List (Fun "row" (List (Fun "cell" exprs)))) ]
   - heading := Ordinary "table"   (routes to Render.GHTable.render)
        │
        ▼  Render.GHTable.render
   read "alignments" from properties; Element.table with one column per index,
   header row (bold + bottom rule) then data rows; each cell rendered via
   Render.Expression.render wrapped in the column's alignment.
```

## Components

### `Generic/Pipeline.elm` (modify) — detection + AST build

Pure helpers (exposed for unit testing):

```elm
type Alignment = AlignLeft | AlignCenter | AlignRight

isGFMTable : PrimitiveBlock -> Bool
-- firstLine is a pipe-row AND the 2nd source line matches the separator regex
--   separator cell ≈ "^ *:?-+:? *$"; row ≈ "|" separated such cells

parseAlignments : String -> List Alignment   -- the separator line → per-column alignment

splitRow : String -> List String             -- split a "| a | b |" line into trimmed cell texts
                                              -- (drop the empty leading/trailing cell from outer pipes)
```

In `toExpressionBlock` (before the heading-based dispatch), add:

```elm
if isGFMTable primitiveBlock then
    gfmTableToExpressionBlock parse primitiveBlock
else
    ... existing dispatch ...
```

`gfmTableToExpressionBlock (parse : String -> List Expression) block` builds the
`Right [ Fun "table" rows ]` AST (header row + data rows; each cell =
`Fun "cell" (parse cellText)`), pads/truncates rows to the header width, stores
`alignments` in `properties`, and sets `heading = Ordinary "table"`. `emptyExprMeta`
is acceptable for the synthetic table/row/cell wrappers (cells' own exprs carry the
inline parser's metas).

### `Render/GHTable.elm` (new) — rendering only

```elm
module Render.GHTable exposing (render)

render : Int -> Accumulator -> RenderSettings
      -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
```

- Read `alignments` from `block.properties` (default left for missing columns).
- `case block.body of Right [ Fun "table" rows ] ->` extract rows (each
  `Fun "row" cells`, each cell `Fun "cell" exprs`).
- Render with `Element.table` (or `indexedTable`): one column per index; header row
  bold with a bottom border; each cell = `Element.paragraph [alignmentAttr] (List.map (Render.Expression.render count acc settings []) exprs)`.
- Fallback to `Element.none` for a malformed body.

### `Render/OrdinaryBlock.elm` (modify)

Replace the dead `( "table", Render.Table.render )` registration with
`( "table", Render.GHTable.render )`; drop the `import Render.Table`.

### Deletions (dead code)

- `src/Render/Table.elm` (never received a real table; replaced by GHTable).
- The leftover commented `tabular` reference in `Render/VerbatimBlock.elm`, and the
  `( "table", Render.Math.textarray )` verbatim entry if it is now unused. (Verify
  with the compiler / elm-review; remove only what is genuinely unused.)

## Data flow / edge cases

- **Non-table `|`-block** (no separator on line 2): `isGFMTable` is false → block is
  untouched; existing behavior preserved.
- **Outer pipes:** supported (`| a | b |`). The no-outer-pipe form (`a | b`) is out
  of scope for v1.
- **Ragged rows:** each row padded with empty cells / truncated to the header column
  count.
- **Escaped pipes (`\|`):** out of scope for v1 (a `\|` will split the cell). Known
  limitation.
- **Empty table body (header + separator only):** renders just the header row.

## Error handling

- `parseAlignments` defaults any unrecognized/short column to `AlignLeft`.
- Render fallback is `Element.none` if the body is not the expected `Fun "table"`
  shape.
- A `|`-block that *looks* close to a table but whose line 2 is not a valid
  separator is simply not a table (falls through) — no crash.

## Testing

Pure unit tests (`tests/GHTableTest.elm`, elm-test):

- `parseAlignments "|:---|---:|:---:|---|"` → `[AlignLeft, AlignRight, AlignCenter, AlignLeft]`.
- `isGFMTable` true for a real table block; false for a `|`-block whose 2nd line is
  not a separator.
- `splitRow "| Alice | 29 | Engineer |"` → `["Alice", "29", "Engineer"]`.
- `gfmTableToExpressionBlock` on the 4-line example → a block whose body is
  `Right [ Fun "table" rows ]` with the right number of rows/cells, header cell texts
  present, and `properties.alignments` set. (Assert via a flattened summary.)
- A ragged row is padded/truncated to header width.

Regression net (CLAUDE.md) + both demo builds stay green.

Manual browser acceptance (the real render gate): put a table in the DemoTOC+Sync
sample (or load one), confirm: columns align per the separator; header is
distinguished; `$math$` and `[m …]` render inside cells; the music-theory example
renders; ragged/headerless-data tables don't crash.

## Out of scope (v1)

- No-outer-pipe rows; escaped pipes; per-cell RL-sync precision (cells inherit the
  block, like list items); column width controls; cell-spanning.

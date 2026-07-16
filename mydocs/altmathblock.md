# Block-level `\[ ... \]` Display Math

*July 2026*

This note records how LaTeX-style display-math blocks

```
\[
x^2 + y^2 = z^2
\]
```

were made to parse to **exactly the same thing** as

```
$$
x^2 + y^2 = z^2
$$
```

and how the feature exposed (and fixed) a long-standing end-of-input bug in
the block parser.

## 1. Where the work lives: the block layer, not the inline layer

The earlier `\(...\)` inline-math feature (see `mydocs/extend-parser.md`)
required coordinated changes across four modules of the inline engine —
token pair, tokenizer mode, symbols, reducibility rule, reduce handler,
recovery case. `extend-parser.md` originally predicted that `\[...\]` would
follow the same recipe. That prediction was wrong, in a pleasant way.

Display math is a *block* construct: a group of lines with a blank line above
and below. Blocks are classified by `Parser.Block.PrimitiveBlock` long before
the inline parser sees anything, and `$$` blocks are simply the case where a
block's first line starts with `$$` — the block becomes `Verbatim "math"`,
its body stays a raw string forever (`Either.Left`), and the renderer
(`Render.Math.displayedMath` → KaTeX) receives that raw content after
stripping the delimiters. The inline tokenizer is never involved.

So the entire feature is three small changes to one module, plus one
bug fix and tests.

## 2. How `$$` blocks work (the machinery being mirrored)

In `Parser.Block.PrimitiveBlock`:

- `getHeadingData` classifies a block by its first line. A first word of
  `$$` yields `Verbatim "math"`.
- The state machine accumulates body lines (in reverse order) until a blank
  line triggers `commitBlock`. For verbatim blocks, `commitBlock` drops the
  opening line (it lives in `firstLine`) but **keeps the closing `$$` in the
  body**; the renderer's `stripMathDelimiters` (Render/Math.elm) removes it
  at render time.
- `finalize` reverses the body into source order and reconstructs
  `meta.sourceText` from `firstLine :: body` — the string that
  editor↔rendered-text sync searches against.

## 3. The changes

All in `Parser.Block.PrimitiveBlock`:

**(a) Classification.** `getHeadingData` gained one case: a first word of
`\[` is classified `Verbatim "math"`, identically to `$$`. (`isVerbatimLine`
was also taught the `\[` prefix, for symmetry with `$$` and code fences.)

**(b) Delimiter normalization.** A new function applied as the last step of
`finalize`:

```elm
normalizeMathDelimiters : PrimitiveBlock -> PrimitiveBlock
```

For a `Verbatim "math"` block it rewrites `firstLine` (`\[…` → `$$…`) and a
final body line of `\]` → `$$`. After this, a `\[...\]` block is
*indistinguishable* from a `$$...$$` block in every parsed field: `heading`,
`firstLine`, `args`, `properties`, `body`. Downstream code — the pipeline,
the accumulator, `stripMathDelimiters`, KaTeX — needs no changes and cannot
even tell which delimiters were used.

Two deliberate design points:

- **`meta.sourceText` stays faithful.** Normalization runs *after* `finalize`
  computes sourceText, so sourceText still contains the `\[...\]` the author
  typed. Rewriting it would break click-to-source sync, since the editor
  buffer contains `\[`, not `$$`.
- **Each delimiter is normalized independently**, so mixed forms
  (`\[`…`$$` or `$$`…`\]`) are tolerated silently. Blocks are really
  terminated by the blank line; strictness about the decorative closer would
  buy nothing.

**(c) Test suite.** `tests/BlockMathBracketTest.elm` (9 tests) asserts
parse-equality of the two snippets on all non-meta fields, sourceText
faithfulness, mixed delimiters, missing closer, `\[` inside a code fence
staying literal, unaffected neighboring paragraphs, and the EOF case below.

## 4. The bug the feature flushed out: blocks ending at EOF

First real-world test: a document whose *last* line was `\]`, with no
trailing blank line. Result: **no rendered math at all.**

The block state machine (`nextStep`) has two ways to close a block:

- **Blank line** → `commitBlock` → heading-specific handling → `finalize`
  (body to source order, sourceText computed, and now delimiter
  normalization).
- **End of input** → a degenerate branch that did a bare `dropLast` on the
  body and **skipped `finalize` entirely** — a known wart; the module even
  carried the comment *"NOTE (TODO) for the moment we assume that the input
  ends with a blank line."*

So for a file ending at `\]`: body left in reverse order, never normalized.
KaTeX received `\]\n x^2+y^2=z^2` and produced nothing.

The revealing part: **`$$` blocks at EOF were broken in exactly the same
way** — reversed body, no sourceText — but *appeared* to work by accident:
`stripMathDelimiters` trims a `$$` from either end of the (trimmed) content,
so it didn't matter that the delimiter was at the wrong end. The new
delimiter had no such luck, which is what surfaced a years-old latent bug.

**The fix** is one line at the root rather than patches in the EOF branch:

```elm
parse initialId outerCount lines =
    loop (init initialId outerCount (lines ++ [ "" ])) nextStep
```

`PrimitiveBlock.parse` appends a virtual blank line to its input,
discharging the old TODO's assumption for every caller. Every block —
math, code, paragraph — now closes through the well-tested
`commitBlock`/`finalize` path no matter how the file ends. This also quietly
fixes other EOF-path defects: paragraphs at EOF losing a line to the bare
`dropLast`, code blocks at EOF keeping their closing fence, and every
EOF-committed block lacking `sourceText` (hence broken sync on the last
block of a file not ending in a newline).

## 5. Verification

```
$ elm repl
> import XMarkdown.Compiler as C
> import RoseTree.Tree as T
> C.parseFromString "\\[\nx^2 + y^2 = z^2\n\\]"      -- note: no trailing \n
      |> List.map T.value |> List.map (\b -> (b.heading, b.firstLine, b.body))
[(Verbatim "math", "$$", Left "x^2 + y^2 = z^2\n$$")]   -- identical to the $$ form
```

Full suite: 47 tests pass (`npx elm-test`), including the EOF regression
test. The DemoTOC example document shows both display-math flavors back to
back, rendering identically.

## 6. Takeaways

- **Know which layer owns the syntax.** A "new math delimiter" sounds like a
  parser-engine change, but block-level constructs are classified from a
  block's first line in one function. Checking where `$$` was handled before
  planning saved four modules of work.
- **Normalize early, at the parse boundary.** Because `\[` blocks become
  literally identical to `$$` blocks at parse time, zero downstream code
  needed changes — and the equality is testable with `Expect.equal` on
  parsed blocks.
- **Faithful `sourceText` is a hard constraint** in this codebase; any
  normalization must happen after it is computed.
- **"Works" can mean "fails invisibly."** The `$$` EOF path was broken all
  along; a renderer-side leniency masked it. New features that mirror old
  ones are a cheap way to flush out such latent bugs — when the mirror
  breaks, look for what luck was protecting the original.

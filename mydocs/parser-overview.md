# The XMarkdown Parser: An Overview

*July 2026*

## What kind of parser is this?

Not one thing — like most Markdown processors, XMarkdown is parsed in **two
layers of different character**, and neither layer is a classical
grammar-driven recursive-descent parser:

- The **block layer** is a *line-oriented, indentation-sensitive block
  scanner*: a hand-written state machine that consumes the source one line at
  a time, groups lines into "primitive blocks" separated by blank lines, and
  then builds a forest of blocks from their indentation. There is no grammar
  and no backtracking; each line is classified once and the machine
  transitions on (in-block?, line-empty?, line-blank?).

- The **inline layer** (the contents of a paragraph, list item, heading, …)
  is a *shift-reduce parser*: tokens are pushed onto an explicit stack, and
  after every push the parser asks whether the stack's shape matches a
  completed construct; if so it reduces the stack to an AST node. Reducibility
  is decided by pattern rules over a symbol abstraction of the stack, not by a
  generated LR table — so it is best described as an *ad-hoc shift-reduce
  parser with hand-written reduction rules and error recovery*.

Recursive descent (via the `elm/parser` combinator library) appears only at
the *lowest* level, inside single tokens: classifying one line's prefix, or
recognizing one token such as `**`, `\(`, or a run of text. Everything above
that is state machines and a stack.

A consequence worth internalizing: **failure at the inline level is never a
parse error.** The input is user prose; the parser must always produce
*something*. Unreducible stacks flow into a recovery routine that emits a
visible error expression (e.g. a red `$` marker for unclosed math) and
resumes, so a typo degrades one construct instead of the document.

## The pipeline at a glance

The driver is `XMarkdown.Compiler.parse` (Compiler.elm:97):

```elm
parse idPrefix outerCount lines =
    lines
        |> Parser.Block.PrimitiveBlock.parse idPrefix outerCount   -- lines → List PrimitiveBlock
        |> Parser.Block.ForestTransform.forestFromBlocks .indent   -- indentation → Forest PrimitiveBlock
        |> AST.Forest.map
            (Parser.Block.Pipeline.toExpressionBlock               -- per block: inline parsing
                Parser.Inline.Expression.parse)                    --   → Forest ExpressionBlock
```

followed (in `parseToForestWithAccumulator`, Compiler.elm:119) by a
post-parse fold, `AST.Acc.transformAccumulate`, which walks the finished
forest threading an `Accumulator` through it — section numbering, labels,
and similar cross-block bookkeeping.

So the full journey is:

```
String
  → List String                 (String.lines)
  → List PrimitiveBlock         (blank-line-separated groups, classified)
  → Forest PrimitiveBlock       (nesting recovered from indentation)
  → Forest ExpressionBlock      (each block's text parsed into Expressions)
  → (Accumulator, Forest ExpressionBlock)
```

Rendering (`Render/`) consumes the final forest; it is not part of parsing.

## Layer 1: lines → primitive blocks

**Module:** `Parser.Block.PrimitiveBlock` (with `Parser.Block.Line`).

A *primitive block* is a maximal run of non-empty lines: at least one blank
line above and below. Its `body` is kept as raw strings — no inline parsing
happens here.

Each raw line is first classified by `Line.classify` (Line.elm:47) into
`{ indent, prefix, content, lineNumber, position }` using a tiny `elm/parser`
parser that measures leading spaces. `position` is the absolute character
offset of the line in the source — this is what later makes
editor↔rendered-text synchronization possible.

The heart of the module is a state machine driven by `Tools.Loop.loop`
(`nextStep`, PrimitiveBlock.elm:219). Its state carries the lines not yet
consumed, the block under construction, and position/line counters. Each step
dispatches on the triple *(am I inside a block?, is this line empty?, is it
blank-but-indented?)*:

| in block | line              | action                          |
|----------|-------------------|---------------------------------|
| no       | empty             | skip                            |
| no       | blank, non-empty  | skip                            |
| no       | has content       | **create** a new current block  |
| yes      | has content       | **add** line to current block   |
| yes      | empty             | **commit** the current block    |

(A line of only spaces is "blank but non-empty" — that's the documented trick
that lets a multi-paragraph code block survive: its internal "blank" lines are
two spaces wide, so they don't terminate the block.)

When a block is created, its first line determines its `Heading`
(`getHeadingData`, PrimitiveBlock.elm:608):

- `#`, `##`, … → `Ordinary "section"` (level in `args`)
- `- ` → `Ordinary "item"`, `. ` → `Ordinary "numbered"` — and if subsequent
  lines of the same block are also items, the block is promoted to
  `Ordinary "itemList"` / `"numberedList"` (nextStep, the "ADD" case)
- `> ` → `Ordinary "quotation"`
- `| name args` → `Ordinary name` (the generic named-block escape hatch)
- `$$` → `Verbatim "math"`, triple backtick → `Verbatim "code"`
- anything else → `Paragraph`

`Verbatim` blocks matter downstream: their bodies stay raw strings forever
(the `Either` in the block type: `Left String` vs `Right (List Expression)`),
so nothing inside `$$ ... $$` or a code fence is ever inline-parsed.

`finalize` (PrimitiveBlock.elm:60) reverses the accumulated body (it was
built head-first), reconstructs `meta.sourceText`, and extracts properties
(e.g. key:value pairs from a `settings` block).

## Layer 2: indentation → forest

**Module:** `Parser.Block.ForestTransform` → `Library.Forest.makeForest`.

The flat block list becomes a forest of rose trees
(`RoseTree.Tree`) using each block's `indent` as its outline level, exactly
like reading a bulleted outline: deeper-indented blocks become children of
the nearest shallower predecessor. This is where nested lists, quotations
containing paragraphs, and box-like containers get their structure.

## Layer 3: block contents → expressions

**Module:** `Parser.Block.Pipeline` (`toExpressionBlock`, Pipeline.elm:9).

Each `PrimitiveBlock` is mapped to an `ExpressionBlock`, whose body is
`Either String (List Expression)`:

- `Verbatim _` → `Left rawText` (untouched)
- `Paragraph` / `Ordinary _` → `Right (inline-parse (body))`
- list blocks get special treatment: each item is inline-parsed separately
  from its marker-stripped substring, wrapped in `ExprList indent …`, and its
  expression source-offsets are shifted so they remain absolute (again for
  editor sync)
- GitHub-flavored tables are detected here (`Parser.Block.GFMTable`) and get
  their own cell-by-cell parse

The target AST (`AST.Language`, Language.elm:31) is deliberately tiny:

```elm
type Expr metaData
    = Text String metaData                       -- plain text
    | Fun String (List (Expr meta)) metaData     -- "bold", "italic", "link", ...
    | VFun String String metaData                -- verbatim-content: "math", "code"
    | ExprList Int (List (Expr meta)) metaData   -- list item (Int = indent)
```

Everything the renderer knows — bold, links, images, inline math — is a
`Fun`/`VFun` name, not a constructor. Extending the language rarely means
touching the AST.

## The inline parser in detail

This is the most intricate machinery, all under `src/Parser/Inline/`.

### Stage A: tokenizing (`Parser.Inline.Token`)

`Token.run` is another `Tools.Loop` state machine that walks one line with a
`scanpointer`. At each position it runs a **mode-dependent** `Parser.oneOf`
against the rest of the string and gets back exactly one token:

```elm
type Token
    = LB | RB              -- [ ]        (link/image brackets)
    | LP | RP              -- ( )
    | Image                -- ![
    | AT                   -- @[
    | Bold | Italic        -- ** and *
    | S String | W String  -- text and whitespace runs
    | MathToken            -- $
    | MathTokenLeft        -- \(
    | MathTokenRight       -- \)
    | CodeToken            -- `
    | TokenError ...
```

(each carrying a `Meta` with begin/end column offsets, token index, and id.)

Three things make this scanner more than a lexer:

1. **Modes.** A small state machine (`newMode`, Token.elm:544) switches the
   active parser set: `Normal`, `InMath` (inside `$…$`), `InMathParen`
   (inside `\(...\)`), `InCode` (inside backticks). Inside `InMath`, almost
   everything is plain text — only `$` terminates — which is how `*` or `\(`
   inside a formula stay literal. Each delimiter pair "owns" a mode.

2. **Merging.** Consecutive `S`/`W` tokens are folded into a single `S` as
   they are produced (`handleMerge` / `updateCurrentToken`), so the parser
   above sees `S "a + b"` rather than five tokens.

3. **Span-driven advance.** The loop moves forward by
   `length token + 1` where `length = meta.end - meta.begin`
   (Token.elm:475). The advance is governed by the *token's recorded span*,
   not by what the combinator consumed. Two-character tokens must set
   `end = start + 1` (`\(`, `\)`); by contrast `![` and `**` deliberately
   record a zero-width span so their second character is *re-scanned* (`[`
   becomes an ordinary LB; the second `*` becomes an Italic token) — the
   grammar upstairs exploits those re-reads. This asymmetry is the number-one
   trap when adding tokens; see `mydocs/extend-parser.md`.

### Stage B: symbols (`Parser.Inline.Symbol`)

For reduction decisions, the token stack is projected onto a coarse symbol
alphabet — `LBracket, RBracket, LParen, RParen, SBold, SItalic, SImage, SAT,
M, ML, MR, C` — and text/whitespace tokens vanish (`toSymbol` returns
`Nothing`). So a stack holding `` [MathToken, S "x^2", MathToken] `` is seen
as just `[M, M]`. `Symbol.value` assigns +1/−1 to opening/closing brackets
for balance counting and 0 to self-delimiting marks (`$`, backtick, `\(`).

### Stage C: shift-reduce (`Parser.Inline.Expression` + `Parser.Inline.Match`)

`Expression.parse` tokenizes, then loops over the token list
(`nextStep`, Expression.elm:83):

```
take next token
  → push it            (pushToken: text may commit directly if the stack
                        is empty; everything else goes on the stack)
  → try to reduce      (reduceState)
```

**Shift.** `pushToken` (Expression.elm:112) contains one lookahead hack:
a text token immediately followed by `*`/`**` is pushed together with that
delimiter, which disambiguates closing-vs-opening emphasis.

**Reduce.** `reduceState` (Expression.elm:204) asks
`isReducible` → `Match.reducible` (Match.elm:8) whether the stack's symbols —
reversed into source order — form a complete construct. The rules are
pattern cases, e.g.:

| head symbol | reducible when                       | reduction              |
|-------------|--------------------------------------|------------------------|
| `M`         | last symbol is `M`                   | `VFun "math" content`  |
| `ML`        | last symbol is `MR`                  | `VFun "math" content`  |
| `C`         | last symbol is `C`                   | `VFun "code" content`  |
| `SBold`     | last symbol is `SBold`               | `Fun "bold" [...]`     |
| `SImage`    | `[SImage, LBracket, RBracket, LParen, RParen]` | image        |
| `LBracket`  | `[LBracket, RBracket, LParen, RParen]`         | link         |
| `SAT`       | balanced brackets after the `@`      | `@[...]` construct     |

When a rule fires, the matching handler in Expression.elm
(`handleMathSymbol`, `handleBoldSymbol`, `handleAt`, …) takes the middle of
the stack, builds the AST node — with a source span recovered from the
stacked tokens' metas (`stackSpan`) — commits it, and clears the stack.
Handlers for bracketed constructs recursively invoke expression parsing on
the inner token ranges; math/code handlers just take the middle verbatim.

**Recover.** If the line ends and the stack is non-empty, the parse *has
failed locally* — and this is where the design shows its purpose.
`recoverFromError` (Expression.elm:571) pattern-matches the reversed stack
against known failure shapes: unclosed `$`, unclosed `\(`, unclosed backtick,
dangling `*` or `**`, `[text]` with no `(url)`, and so on. Each case commits
a small, visible error expression (typically `Fun "red" [...]` or
`Fun "pink" [...]` — rendered as colored text), possibly repairs the token
stream (some cases *insert* a synthetic closing token and re-loop), resets
the stack, and continues. The catch-all paints the leftover stack red. The
parser therefore **totals**: every input produces a renderable expression
list plus diagnostic messages.

### `Parser.Inline.Core.*` — a note

`Parser.Inline.Core.{Tokenizer, Symbol, Match, Expression}` is a second,
parallel copy of this engine, derived from the L0 language. It is *shared
infrastructure*: `Macro.TextMacro` and the `@[...]` syntax (via
`Parser.Inline.Expression`) use it. The XMarkdown-specific engine described
above (`Parser.Inline.{Token, Symbol, Match, Expression}`) evolved from it
but has diverged (different token set, modes, recovery cases). When changing
inline syntax, the XMarkdown modules are the ones on the hot path — but
grep both before assuming.

## Post-parse: the accumulator

`AST.Acc.transformAccumulate` folds over the finished forest in reading
order, threading an `Accumulator` that assigns section numbers, gathers
labels/cross-references, and stamps each block with what it needs for
rendering (e.g. the `"label"` property used in headings and the TOC). It is
a pure fold — parsing proper is already done.

## Design themes worth knowing

- **Never fail.** Both layers are total functions from text to structure;
  errors become visible artifacts in the output, not exceptions. This is the
  right contract for a live editor, where the document is *usually* in an
  incomplete state mid-keystroke.
- **Positions are sacred.** Line numbers and character offsets are threaded
  from `Line.classify` through token `Meta`s into expression metadata, and
  list-item parsing carefully *shifts* offsets back to absolute positions.
  All of the editor↔preview sync features sit on this data.
- **Flat AST, named constructs.** `Fun "bold"`/`VFun "math"` instead of
  dedicated constructors keeps the AST stable while the language grows;
  the renderer dispatches on names via a registry.
- **State machines over grammars.** Blank lines, indentation, and modes do
  the work a grammar would, which matches Markdown's line-oriented nature
  and keeps every step debuggable in the repl (`Token.run`,
  `Expression.parse`, `PrimitiveBlock.parse` can each be inspected
  independently — see §5 of `mydocs/extend-parser.md` for the technique).

## Worked example

For the line `He said $x^2$ **loudly**.`:

1. Block layer: one `Paragraph` primitive block (assuming blank lines
   around it); no structure to recover.
2. Tokenizer: `S "He said "`, `MathToken`, (mode→InMath) `S "x^2"`,
   `MathToken` (mode→Normal), `W " "`, `Bold`, `S "loudly"`, `Bold`,
   `S "."` — with the leading text runs merged.
3. Shift-reduce: `S "He said "` commits directly (empty stack).
   `[M]` … push `S` … `[M, S, M]` → symbols `[M, M]` → reducible →
   `VFun "math" "x^2"`. Likewise `[SBold, SBold]` → `Fun "bold" [Text "loudly"]`.
   Final `S "."` commits directly.
4. Result:
   `[ Text "He said ", VFun "math" "x^2", Text " ", Fun "bold" [Text "loudly"], Text "." ]`
   — each node carrying its source span for sync.

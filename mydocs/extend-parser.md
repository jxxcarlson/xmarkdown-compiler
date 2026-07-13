# Extending the Inline Parser: LaTeX-style `\(...\)` Math Delimiters

*July 2026 — commits `75967e4` and `d66bf61`*

This report describes the changes made so that the XMarkdown inline parser
accepts LaTeX-style `\(...\)` delimiters for inline mathematics. It also
records the bugs encountered along the way, since they illuminate how the
tokenizer's scan loop actually works — useful the next time a multi-character
token is added.

## 1. Specification

- `\(x^2\)` must parse to **exactly** the same AST element as `$x^2$`,
  namely `VFun "math" "x^2" <meta>`.
- Inside `$...$`, the sequences `\(` and `\)` are **literal text**.
  So `$x \(y\) z$` is a single math expression whose content is the
  string `x \(y\) z`.
- An unclosed `\(` recovers gracefully, in the same style as an
  unclosed `$`: a small red marker is emitted and the rest of the line
  is parsed normally.
- Escaping (`\\(` producing the literal characters `\(` in prose) is
  **deferred** — see §7, Future work.

## 2. How the inline pipeline works (refresher)

The inline language is processed in three stages, all under `src/Parser/Inline/`:

1. **Tokenizer** (`Parser.Inline.Token`). A loop (`run`/`nextStep`) scans the
   line left to right. At each position it runs a mode-dependent
   `Parser.oneOf` over the remaining input and produces one `Token`
   (`LB`, `RB`, `Bold`, `S "text"`, `MathToken`, …). A small `Mode` state
   machine (`newMode`, Token.elm:544) switches the active parser set:
   `Normal`, `InMath` (inside `$...$`), `InCode` (inside backticks).
   Consecutive text/whitespace tokens (`S`/`W`) are merged into a single
   `S` token as they are produced.

2. **Symbols** (`Parser.Inline.Symbol`). For reduction decisions, the token
   stack is abstracted to a list of `Symbol`s (`LBracket`, `M`, `C`, …).
   Text tokens map to `Nothing` and vanish, so `[MathToken, S, MathToken]`
   becomes just `[M, M]`.

3. **Shift/reduce expression parser** (`Parser.Inline.Expression`, with
   `Parser.Inline.Match` deciding reducibility). Tokens are pushed onto a
   stack; after each push, `reduceState` (Expression.elm:204) asks
   `Match.reducible` whether the stack's symbol pattern is complete. If so,
   a handler collapses the stack into an AST `Expression`. If the line ends
   with a non-empty stack, `recoverFromError` pattern-matches the stack and
   emits a friendly error expression.

A new delimiter pair therefore needs coordinated support at **all three**
stages, plus error recovery. Missing any one of them fails silently — the
tokens just fall through to a fallback path (see §5).

## 3. Changes, module by module

### 3.1 `Parser.Inline.Token`

**New token variants** (Token.elm:40–41):

```elm
| MathTokenLeft Meta  -- for "\("
| MathTokenRight Meta -- for "\)"
```

with corresponding `TMathLeft` / `TMathRight` in `TokenType` and new cases in
the bookkeeping functions `setIndex`, `type_`, `getMeta`, `stringValue`
(`"\\("` / `"\\)"`), `stringValue2` (`"ML"` / `"MR"`), `length`, and `indexOf`.

**New token parsers** (Token.elm:749, 755):

```elm
mathTokenLeftParser start index =
    Parser.symbol (Parser.Token "\\(" (PT.ExpectingSymbol "\\("))
        |> Parser.map (\_ -> MathTokenLeft { begin = start, end = start + 1, ... })
```

Two points matter here:

- **`Parser.symbol` is atomic** in `elm/parser`: it either consumes the whole
  string or fails consuming nothing. This makes it safe inside `Parser.oneOf` —
  input like `\x` falls through cleanly to the remaining alternatives. (A
  hand-rolled `chompIf '\\' |> andThen (chompIf '(')` is *not* safe: after the
  first `chompIf` consumes, a failure aborts the entire `oneOf`.)

- **`end = start + 1`, not `end = start`.** The scan loop advances by
  `length token + 1` where `length = meta.end - meta.begin`
  (Token.elm:475). A two-character token must therefore span
  `[start, start + 1]`; with `end = start` the scanpointer advances only one
  character and the `(` is tokenized a second time. (Single-character tokens
  like `$` use `end = start`; two-character tokens like `![` and `**`
  intentionally advance by 1 so their second character is re-read — a design
  quirk this feature must *not* imitate.)

Both parsers are registered near the front of the `Normal`-mode `oneOf`
(`tokenParser_`), ahead of `textParser`.

**New tokenizer mode `InMathParen`** (Token.elm:109). The mode transitions are:

| Current mode  | Token            | New mode      |
|---------------|------------------|---------------|
| `Normal`      | `MathTokenLeft`  | `InMathParen` |
| `InMathParen` | `MathTokenRight` | `Normal`      |
| `Normal`      | `MathToken` (`$`)| `InMath`      |
| `InMath`      | `MathToken` (`$`)| `Normal`      |

A separate mode — rather than reusing `InMath` — is what implements the
"literal inside `$...$`" rule: `InMath`'s parser set is untouched and still
terminates only on `$`, so `\(` and `\)` occurring inside dollar-math are
chomped as ordinary math text.

`InMathParen` uses its own parser set (`mathParenParser_`, Token.elm:647):

```elm
Parser.oneOf
    [ mathTokenRightParser start index
    , mathParenTextParser start index
    , whiteSpaceParser start index
    ]
```

`mathParenTextParser` (Token.elm:732) chomps any non-space text but **stops at
every backslash**, so a closing `\)` is always seen by `mathTokenRightParser`
rather than being swallowed into a text token. Content like
`\sum_{i=0}^n x_i` is split at backslashes/spaces into several `S`/`W`
tokens, which the scan loop's merging machinery reassembles into a single
`S` token, backslashes intact.

### 3.2 `Parser.Inline.Symbol`

Two new symbols, `ML` and `MR` (Symbol.elm:17–18), mapped from
`MathTokenLeft` / `MathTokenRight` in `toSymbol` (Symbol.elm:98, 101). Both
have `value 0`: the `value` function's ±1 accounting is for bracket-balance
counting, and like `$` (`M`) and backtick (`C`) these delimiters are
self-delimiting, not nesting.

### 3.3 `Parser.Inline.Match`

One new case in `reducible` (Match.elm:14):

```elm
Just ML ->
    List.head (List.reverse (List.drop 1 symbols)) == Just MR
```

i.e. a stack whose symbols start with `ML` is reducible exactly when the last
symbol is `MR` — the direct analogue of the `M ... M` rule for dollar math.
This was the last missing piece during development: without it the stack
`[MathTokenLeft, S "x^2", MathTokenRight]` was never deemed reducible, the
reduce handler never ran, and the tokens eventually fell out through the
generic error path as literal red text.

### 3.4 `Parser.Inline.Expression`

**Reduce dispatch and handler.** `reduceState` converts the stack to symbols
(*reversed, i.e. in source order*) and dispatches on the head. A new branch
(Expression.elm:224) sends `Just ML` to `handleMathTokenLeftSymbol`
(Expression.elm:457):

```elm
handleMathTokenLeftSymbol symbols state =
    if symbols == [ ML, MR ] then
        let
            content = takeMiddleReversed state.stack |> Token.toString2
            expr = VFun "math" content (stackSpan state)
        in
        { state | stack = [], committed = expr :: state.committed }
    else
        state
```

This is the same construction `handleMathSymbol` uses for `[ M, M ]` — which
is precisely why the two syntaxes yield identical AST nodes. (Development
note: the pattern is `[ ML, MR ]`, not `[ MR, ML ]`; the symbol list has
already been reversed into source order by the time it reaches the handler.)

**Error recovery.** A new `recoverFromError` case (Expression.elm:778)
handles an opening `\(` that never found its `\)`, mirroring the unclosed-`$`
case above it: commit a red `"\( "` marker (or `"\(?\)"` when nothing
followed), clear the stack, resume after the opening delimiter, and record
the message *"opening \\( needs to be matched with a closing \\)"*. The rest
of the line is preserved as normal text instead of being painted red by the
catch-all.

## 4. What did **not** change

- `ETeX.Transform` and everything in `Render/` — by the time rendering
  happens there is only `VFun "math" content`, with the delimiters already
  stripped. KaTeX rendering, theming, sync, etc. are all downstream of the
  AST and required no changes.
- `Parser.Inline.Core.*` — the L0-derived engine shared with
  `Macro.TextMacro` and the `@[...]` syntax has its own Symbol/Match modules
  and is not on the `$`-math code path; it was left untouched.
- `InMath` and `InCode` tokenizer modes.

## 5. Bugs encountered (a case study in silent fallbacks)

The first working-looking implementation rendered `\(x^2\)` as `\((x^2\)`.
Three independent defects were stacked on top of each other, and each one
failed *silently* into a fallback behavior:

1. **Wrong token span → doubled `(`.** With `end = start`, the scan loop
   advanced 1 character past `\(` instead of 2, re-tokenizing `(` as `LP`.
   *Lesson: the scanpointer advance is driven by the token's `Meta` span,
   not by how much the `elm/parser` parser consumed.*

2. **No way to close.** After `\(`, the tokenizer entered `InMath`, whose
   parser set only looks for `$`; the entire remainder including `\)` merged
   into one text token. *Lesson: every mode has its own closed set of
   recognizable tokens — a new delimiter must be added to the set of every
   mode in which it is significant.*

3. **Reduce never fired.** With tokens finally correct, `Match.reducible`
   had no `ML` rule, so the completed stack was never collapsed and the
   catch-all committed it as red literal text. *Lesson: reducibility is a
   separate, easy-to-forget registration step.*

Diagnosis was fastest in the repl, inspecting each stage separately:

```
$ elm repl
> import Parser.Inline.Token as T
> import Parser.Inline.Expression as E
> T.run "\\(x^2\\)"      -- inspect tokens + spans
> E.parse 0 "\\(x^2\\)"  -- inspect resulting AST
```

## 6. Verification

Repl checks:

```
E.parse 0 "\\(x^2\\)"   --> [ VFun "math" "x^2" { begin = 0, end = 6, ... } ]
E.parse 0 "$x^2$"       --> [ VFun "math" "x^2" { begin = 0, end = 4, ... } ]
E.parse 0 "$x \\(y\\) z$" --> one math expression, content "x \(y\) z"
E.parse 0 "start \\(x^2 end"
  --> [ Text "start ", Fun "red" [ Text "\( " ], Text "x^2 end" ]
```

Unit tests in `tests/MathLatexSyntaxTest.elm` (8 cases): AST equivalence with
`$...$`, LaTeX commands with backslashes inside `\(...\)`, mixed delimiters on
one line, empty `\(\)`, multiple occurrences per line, and literal `\( \)`
inside `$...$`. All 38 tests in the suite pass.

*Tooling note:* `npx elm-test` had been failing with an Elm version mismatch —
the homebrew-installed elm-test (0.19.1-revision10) generates a runner
`elm.json` pinned to Elm 0.19.1, which the installed Elm 0.19.2 rejects. Fixed
by adding a repo-local `package.json` with `elm-test@0.19.2-0`, which `npx`
resolves ahead of the global binary.

The demo document in `DemoMd/src/Data/Example.elm` gained a "LaTeX Math
Syntax" section exercising the new delimiters, viewable via
`npx elm-watch hot` (port 9000).

## 7. Future work

- **Escaping**: support `\\(` in prose to produce the literal characters
  `\(` (agreed in principle, not yet implemented).
- **Stray `\)`** with no opener still falls through to the generic
  catch-all (red literal text); a dedicated recovery case could match the
  friendlier unclosed-`\(` treatment.
- **`\[...\]` display math** would follow the same recipe if ever wanted:
  token pair → mode → symbols → reducibility rule → reduce handler →
  recovery case.

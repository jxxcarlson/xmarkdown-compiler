# CLAUDE.md — XMarkdown Compiler

## What this repo is

This is a **standalone XMarkdown (Scientific Markdown / SMarkdown) compiler**.
It compiles XMarkdown source text into elm-ui HTML. XMarkdown is the only supported
language.

## Module layout (organized by pipeline stage)

- `Parser/` — the XMarkdown parser (source → AST). `Parser.Block.*` (block
  structure: PrimitiveBlock, Pipeline, ForestTransform, GFMTable, Line),
  `Parser.Inline.*` (inline parser: Expression, Token, Symbol, Match, …), and
  `Parser.Inline.Core.*` (the L0-derived engine the inline layer is built on).
- `AST/` — the data model + post-parse passes (Language, ASTTools, Acc, Forest,
  Vector, BlockUtilities).
- `Macro/`, `ETeX/` — macro expansion and math rendering.
- `Render/` — AST → elm-ui.
- `Scripta/` — the public API + driver (API, APISimple, Compiler, Types, Msg,
  Editor, Sync, Config). The driver is `Scripta.Compiler`.

## Key architectural fact (do not get this wrong)

`Parser.Inline.Core.*` (Expression/Match/Symbol/Tokenizer) is the L0-derived
*inline* engine, **shared infrastructure** reused by `Macro.TextMacro` and (via
`Parser.Inline.Expression`) by XMarkdown's `@[...]` syntax. **Keep it.** `ETeX/`
is the math renderer, not a language — keep it.

## Verification

The Elm compiler is the regression net. After every change:

```bash
elm make src/Scripta/APISimple.elm src/Scripta/API.elm src/Scripta/Types.elm src/Scripta/Msg.elm src/Render/Theme.elm --output=/dev/null
npx elm-test
```

Both must pass before committing.

## Conventions

- Modify `elm.json` **dependencies** via `elm-json`, not by hand.
  (`npx elm-json install <author/package>`, `npx elm-json uninstall --yes <author/package>`)
- `npx elm-review --ignore-dirs src/Evergreen/` for code review.
- Generated `main.js` files are git-ignored.
- Public entry points: `Scripta.APISimple`, `Scripta.API`, `Scripta.Types`,
  `Scripta.Msg`, `Render.Theme`, `Scripta.Editor`, `Scripta.Sync`.
- When asked to "show me the code", give module name + line numbers.

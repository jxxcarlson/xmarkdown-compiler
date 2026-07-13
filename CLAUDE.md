# CLAUDE.md — XMarkdown Compiler

## What this repo is

This is a **standalone XMarkdown (Scientific Markdown / SMarkdown) compiler**.
It compiles XMarkdown source text into elm-ui HTML. XMarkdown is the only supported
language.

## Module layout (organized by pipeline stage)

- `Parser/` — the XMarkdown parser (source → AST). `Parser.Block.*` (block
  structure: PrimitiveBlock, Pipeline, ForestTransform, GFMTable, Line) and
  `Parser.Inline.*` (inline parser: Expression, Token, Symbol, Match, …).
- `AST/` — the data model + post-parse passes (Language, ASTTools, Acc, Forest,
  Vector, BlockUtilities).
- `Render/` — AST → HTML.
- `XMarkdown/` — the public API + driver (API, Compiler, Types,
  Editor, Sync, Config). The driver is `XMarkdown.Compiler`.

Math rendering uses the external `jxxcarlson/etex` package (`ETeX.*`).

Historical note: the L0-derived inline engine (`Parser.Inline.Core.*`) and the
text-macro system (`Macro/*`), which supported the `@[...]` syntax and
`textmacros` blocks, were removed in July 2026 along with those two features.

## Verification

The Elm compiler is the regression net. After every change:

```bash
elm make src/XMarkdown/API.elm src/XMarkdown/Types.elm src/Render/Theme.elm --output=/dev/null
npx elm-test
```

Both must pass before committing.

## Conventions

- Modify `elm.json` **dependencies** via `elm-json`, not by hand.
  (`npx elm-json install <author/package>`, `npx elm-json uninstall --yes <author/package>`)
- `npx elm-review --ignore-dirs src/Evergreen/` for code review.
- Generated `main.js` files are git-ignored.
- Public entry points: `XMarkdown.API`, `XMarkdown.Types`, `Render.Theme`,
  `XMarkdown.Editor`, `XMarkdown.Sync` (package `exposed-modules`:
  `XMarkdown.API`, `XMarkdown.Types`).
- When asked to "show me the code", give module name + line numbers.

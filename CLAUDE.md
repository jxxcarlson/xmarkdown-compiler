# CLAUDE.md — XMarkdown Compiler

## What this repo is

This is a **standalone XMarkdown (Scientific Markdown / SMarkdown) compiler**.
It compiles XMarkdown source text into elm-ui HTML. XMarkdown is the only supported
language.

## Key architectural fact (do not get this wrong)

`Scripta.Expression` (+ `Scripta.Match`, `Scripta.Symbol`, `Scripta.Tokenizer`) is
the L0-derived *inline* parser, but it is **shared infrastructure** — it parses table
cells (`Generic.Pipeline`), text macros (`Generic.TextMacro`), and XMarkdown's
`@[...]` syntax. **Keep it.** `ETeX/` is the math renderer, not a language — keep it.

## Verification

The Elm compiler is the regression net. After every change:

```bash
elm make src/ScriptaV2/APISimple.elm src/ScriptaV2/API.elm src/ScriptaV2/Types.elm src/ScriptaV2/Msg.elm src/Render/Theme.elm --output=/dev/null
npx elm-test
```

Both must pass before committing.

## Conventions

- Modify `elm.json` **dependencies** via `elm-json`, not by hand.
  (`npx elm-json install <author/package>`, `npx elm-json uninstall --yes <author/package>`)
- `npx elm-review --ignore-dirs src/Evergreen/` for code review.
- Generated `main.js` files are git-ignored.
- Public entry points: `ScriptaV2.APISimple`, `ScriptaV2.API`, `ScriptaV2.Types`,
  `ScriptaV2.Msg`, `Render.Theme`, `ScriptaV2.Editor`, `ScriptaV2.Sync`.
- When asked to "show me the code", give module name + line numbers.

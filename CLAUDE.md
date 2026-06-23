# CLAUDE.md — XMarkdown Standalone Compiler (extraction in progress)

## What this repo is

This is a **standalone XMarkdown (Scientific Markdown / SMarkdown) compiler**, being
extracted from the three-language `scripta-compiler-v2`. It compiles XMarkdown source
into elm-ui HTML. MiniLaTeX and L0 are being removed as selectable languages.

## The plan

Follow **`EXTRACTION_PLAN.md`** in this directory, task by task. It is a
superpowers-style plan: use the `superpowers:executing-plans` or
`superpowers:subagent-driven-development` skill to work through it, checking off
steps as you go.

## Reference repo (read-only)

The original lives at **`../scripta-compiler-v2`**
(`/Users/carlson/dev/elm-work/scripta/scripta-compiler-v2`).

- **Never modify it.** It is the source of truth for comparison.
- Use it to: pull test cases, diff a module against the original when a change
  breaks something, or confirm original behavior.

## Key architectural fact (do not get this wrong)

`Scripta.Expression` (+ `Scripta.Match`, `Scripta.Symbol`, `Scripta.Tokenizer`) is
the L0 *inline* parser, but it is **shared infrastructure** — it parses table cells
(`Generic.Pipeline`), text macros (`Generic.TextMacro`), and XMarkdown's `@[...]`
syntax. **Keep it.** Only `Scripta.PrimitiveBlock` (the L0 *block* parser) is
L0-specific and removable. `ETeX/` is the math renderer, not a language — keep it.

## Verification (the test loop for this refactor)

The Elm compiler is the regression net. After every deletion:

```bash
elm make src/ScriptaV2/APISimple.elm --output=/dev/null   # must say Success!
elm-test                                                   # must pass
```

## Conventions inherited from the source repo

- Modify `elm.json` dependencies via `elm-json`, not by hand.
- `npx elm-review --ignore-dirs src/Evergreen/` for code review.
- Generated `main.js` files are git-ignored.
- Public entry points: `ScriptaV2.APISimple`, `ScriptaV2.API`, `ScriptaV2.Types`,
  `ScriptaV2.Msg`, `ScriptaV2.Language`, `Render.Theme`.
- When asked to "show me the code", give module name + line numbers.

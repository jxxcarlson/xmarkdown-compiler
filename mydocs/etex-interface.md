# ETeX Interface

External API surface of the `src/ETeX/` directory: which modules and which
of their functions/types are used from outside `ETeX/*`.

## Modules used outside ETeX/

Of the five ETeX modules, only **two** are referenced from outside `ETeX/`:

| ETeX module | Used outside ETeX/? | External users |
|---|---|---|
| `ETeX.MathMacros` | ✅ yes | `src/Render/Expression.elm`, `src/Generic/Acc.elm` |
| `ETeX.Transform` | ✅ yes | `src/Render/Expression.elm`, `src/Render/Math.elm`, `src/Render/Html/Math.elm`, `src/Generic/Acc.elm` |
| `ETeX.Dictionary` | ❌ no | — (internal to ETeX/) |
| `ETeX.KaTeX` | ❌ no | — (internal to ETeX/) |
| `ETeX.Test` | ❌ no | — (test/dev module) |

`ETeX.MathMacros` and `ETeX.Transform` are the public surface of the directory;
`Dictionary`, `KaTeX`, and `Test` are used only internally within `ETeX/*` (or
are standalone test code).

## Functions/types used externally

### `ETeX.MathMacros` — only **1** symbol used externally

| Symbol | Kind | Used in |
|---|---|---|
| `MathMacroDict` | type | `Render/Expression.elm:113,581,588`, `Generic/Acc.elm:88` |

Only the **type** `MathMacroDict` is referenced — no functions from
`MathMacros` are called externally.

### `ETeX.Transform` — **2** functions used externally

| Symbol | Kind | Used in |
|---|---|---|
| `evalStr` | function | `Render/Expression.elm:1176`, `Render/Math.elm` (×7: 70,117,121,128,218,286,369), `Render/Html/Math.elm` (×7: 52,112,116,123,208,272,344) |
| `makeMacroDict` | function | `Generic/Acc.elm:921` |

## Summary

The entire external API of `ETeX/` consists of just three things:

- **`ETeX.MathMacros.MathMacroDict`** (type) — passed around as the macro-dictionary type
- **`ETeX.Transform.makeMacroDict`** (function) — builds the dict (called once, in `Generic/Acc.elm`)
- **`ETeX.Transform.evalStr`** (function) — the workhorse; expands ETeX→KaTeX strings at every math render site

Notably, `evalStr` and `makeMacroDict` are the only *functions* anyone outside
`ETeX/` calls. Everything else (`Dictionary`, `KaTeX`, and the rest of
`MathMacros`/`Transform`) is internal implementation.

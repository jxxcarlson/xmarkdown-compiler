# Simplify branch — dead-code cleanup

Branch: `simplify` (off `main`). Goal: remove unused modules, dependencies, and
(pending) unused exports/imports. Everything below is verified green after each
step: compiler regression net (8 entry points), `npx elm-test` (18/18), and both
`DemoTOCMd` and `DemoMd` build.

## Already removed (committed on `simplify`)

### 28 modules — commit `c30b623`
Removed iteratively (a module's removal orphans its now-unused deps; repeated
until convergence — 4 rounds). `src/` went 124 → 96 modules, ~3.5k lines.

- **Differential subsystem (dead):** `Differential.AbstractDifferentialCompiler`,
  `Differential.AbstractDifferentialParser`, `Differential.Differ`,
  `Differential.DifferForest`, `Differential.Differential`,
  `Differential.Utility`, `ScriptaV2.DifferentialCompiler`
- **Render dead/superseded:** `Render.Chart` (→ `ChartV2`), `Render.Tabular`,
  `Render.TOC`, `Render.Data`, `Render.Types`, `Render.AttributesExtended`,
  `Render.Compatibility.OrdinaryBlock`, `Render.Compatibility.Tree`
- **Test/scaffolding:** `Render.SimpleTest`, `Render.TestCompile`,
  `Render.TestMigration`, `Render.TestRender`, `ETeX.Test`,
  `Library.TestForest1`, `Library.TestForest2`, `Library.TestTree`
- **Other orphans:** `ScriptaV2.Helper`, `ScriptaV2.Settings`,
  `XMarkdown.Classify`, `XMarkdown.Transform`, `XMarkdown.Line`

### 2 dependencies — commit `9faee04`
- `elm/time`
- `jinjor/elm-diff` (was the Differential subsystem's diff lib)

## Would be removed (#2 — investigated, NOT applied yet)

Found via `elm-review` with the `NoUnused.*` rules (config added under `review/`).

| Category | Count | Notes |
|---|---|---|
| Unused imports | 100 (41 files) | safe, mechanical |
| Unused local values (let/top-level) | 89 | safe, mechanical |
| Unused exports (internal API) | 315 (57 files) | safe but **cascades** |
| *(not requested)* unused params / patterns / constructors | 137 / 42 / 17 | noisier; may include intentional cases |

Public API is preserved: the 8 exposed modules (`ScriptaV2.APISimple`,
`ScriptaV2.API`, `ScriptaV2.Types`, `ScriptaV2.Msg`, `ScriptaV2.Language`,
`Render.Theme`, `ScriptaV2.Editor`, `ScriptaV2.Sync`) are not touched by
`NoUnused.Exports` — only internal-module exports nothing imports.

### Dead-code hotspots
- **`src/Render/NewColor.elm` — 90 unused exports + 11 unused imports.** Likely
  almost entirely dead; worth inspecting for wholesale deletion vs. trimming.
- `src/Generic/ASTTools.elm` — 22 unused exports
- `src/Generic/Language.elm` — 15
- `src/Generic/TextMacro.elm` — 12
- `src/Render/MathMacro.elm` — 11

Full itemized lists (every export/import with its file) were generated to the
session scratchpad: `unused-exports.txt`, `unused-imports.txt`. Re-generate any
time with:

```
npx elm-review --ignore-dirs src/Evergreen/ --report=json
```

## Tooling added
- `review/` — an `elm-review` config (`review/src/ReviewConfig.elm`) enabling the
  `NoUnused.*` rule set (`Dependencies`, `Exports`, `Modules`, `Variables`,
  `CustomTypeConstructors`, `Parameters`, `Patterns`). The repo previously had no
  elm-review config. Run with `npx elm-review --ignore-dirs src/Evergreen/`.

## Pending decision (before proceeding)
How aggressive to be on #2:
1. **Imports + local values only (189)** — safe, no cascade.
2. **+ Unused exports (315)** — full #2; `--fix-all` iterates to a fixed point,
   likely deleting many internal functions (cascade). Public API untouched.
3. **Everything (700)** — also params/patterns/constructors; touches signatures,
   needs closer review.

User is investigating before deciding. Likely first look: `Render/NewColor.elm`.

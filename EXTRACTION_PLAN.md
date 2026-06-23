# XMarkdown Standalone Compiler — Extraction Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a standalone Elm package that compiles only XMarkdown (Scientific Markdown / SMarkdown) source into elm-ui HTML, by copying the existing three-language `scripta-compiler-v2` and subtracting the other two front-ends.

**Architecture:** The source compiler has three layers: language front-ends (`XMarkdown/`, `MiniLaTeX/`, `Scripta/`=L0), a language-agnostic core (`Generic/`, `Render/`, `ETeX/` math, `ScriptaV2/` API), and shared utilities. Only **MiniLaTeX** is cleanly severable. The L0 inline parser (`Scripta.Expression`) is **shared infrastructure** (tables, macros, and XMarkdown's `@[...]` all use it), so it is kept; only L0's *block* parser and its status as a *selectable language* are removed. Extraction = copy whole repo, then delete the severable parts and let `elm make` drive residual cleanup.

**Tech Stack:** Elm 0.19, elm-ui (`mdgriffith/elm-ui`), elm-test, KaTeX (runtime, via host HTML), elm-watch (dev).

---

## CRITICAL FINDING — read before starting

The reference repo presents L0/Scripta as one of three "languages," but its **inline expression parser is core shared infrastructure**, not L0-specific:

| Module | Role | Action |
|---|---|---|
| `Scripta.Expression` | inline parser used by `Generic.Pipeline` (table cells), `Generic.TextMacro` (macros), `Render.Tabular`, and `XMarkdown.Expression` (`@[...]`) | **KEEP** |
| `Scripta.Match`, `Scripta.Symbol`, `Scripta.Tokenizer` | closure of `Scripta.Expression` | **KEEP** |
| `Scripta.PrimitiveBlock` | L0 *block* parser, only used by the dispatchers | **DELETE** |
| `Scripta.Regex` | verify usage; delete only if orphaned after `PrimitiveBlock` removal | **VERIFY → DELETE if orphaned** |

Therefore "fully delete L0" is **not** done by erasing `Scripta/`. It is done by removing L0 as a *selectable language* (enum constructor, dispatcher branch, block parser) while keeping the shared inline parser. Renaming the kept `Scripta.*` modules out of the `Scripta.*` namespace (so the package no longer advertises L0) is **optional polish in Task 8**, not required for a working compiler.

## Global Constraints

- **Reference repo (read-only):** `/Users/carlson/dev/elm-work/scripta/scripta-compiler-v2`. Never modify it. Use it to pull test cases and to diff/compare behavior.
- **Working repo:** `/Users/carlson/dev/elm-work/scripta/xmarkdown` (this directory).
- **Definition of "test passes" for each task:** `elm make src/ScriptaV2/APISimple.elm --output=/dev/null` compiles clean AND `elm-test` passes (after the test suite is trimmed in the task that trims it). The Elm compiler is the primary regression net for a deletion refactor.
- **Edit `elm.json` only via `elm-json`** (per the reference repo's CLAUDE.md), never by hand.
- **Keep `ETeX/`** — it is the math-macro renderer, used by `Render/` and `Generic/Acc`, not a language.
- **Commit after every task** with a descriptive message. Frequent commits.
- The package's public entry points are `ScriptaV2.APISimple`, `ScriptaV2.API`, `ScriptaV2.Types`, `ScriptaV2.Msg`, `ScriptaV2.Language`, `Render.Theme` (see `exposed-modules` in `elm.json`).

## Languages / features being removed

- **MiniLaTeX** (`src/MiniLaTeX/`, 15 files) — selectable language, fully removed.
- **L0 / Scripta** as a selectable language — `ScriptaLang`, `parseScripta`, `Scripta.PrimitiveBlock` removed; `Scripta.Expression` kept as shared infra.
- **Plain Markdown** (`src/Markdown/`, `MarkdownLang`) — the dillonkearns-based standalone compiler, removed.
- **LaTeX / Scripta export** (`Render/Export/LaTeX.elm`, `LaTeXToScripta.elm`, `Scripta.elm`, `Render/Html/Export.elm`) — per scope decision "render only".

## File Structure (target end state)

Kept: `src/XMarkdown/`, `src/Generic/`, `src/Render/` (minus export modules), `src/ETeX/`, `src/ScriptaV2/`, `src/Scripta/` (minus `PrimitiveBlock`/`Regex`), `src/Tools/`, `src/Library/`, `src/MicroScheme/`, `src/Differential/`.
Deleted: `src/MiniLaTeX/`, `src/Markdown/`, L0 block parser, LaTeX/Scripta export modules.

---

### Task 1: Set up the working repo with a green baseline

**Files:**
- Create: everything (clone of reference repo)

- [ ] **Step 1: Clone the reference repo into this directory**

The plan files (`EXTRACTION_PLAN.md`, `CLAUDE.md`) already live in `/Users/carlson/dev/elm-work/scripta/xmarkdown`. Clone into a temp dir and move the contents in so the plan files are preserved.

```bash
cd /Users/carlson/dev/elm-work/scripta
git clone scripta-compiler-v2 xmarkdown-src
# move repo contents (including .git) into the plan dir without clobbering the plan files
rsync -a xmarkdown-src/ xmarkdown/
rm -rf xmarkdown-src
cd xmarkdown
git add EXTRACTION_PLAN.md CLAUDE.md && git commit -m "chore: add extraction plan and orientation"
```

- [ ] **Step 2: Verify the baseline builds**

Run: `cd /Users/carlson/dev/elm-work/scripta/xmarkdown && elm make src/ScriptaV2/APISimple.elm --output=/dev/null`
Expected: `Success!` (downloads deps on first run).

- [ ] **Step 3: Verify the baseline tests pass**

Run: `elm-test`
Expected: all suites pass. Record the pass count — this is the baseline.

- [ ] **Step 4: Commit the baseline marker**

```bash
git commit --allow-empty -m "chore: green baseline before extraction"
```

---

### Task 2: Remove the standalone plain-Markdown language

Smallest, most isolated cut. `src/Markdown/Markdown/Compiler.elm` is a separate dillonkearns-based compiler; `MarkdownLang` is its enum constructor.

**Files:**
- Delete: `src/Markdown/` (whole dir)
- Modify: `src/ScriptaV2/Language.elm`, `src/ScriptaV2/Compiler.elm:191-192`, `src/ScriptaV2/DifferentialCompiler.elm:340,357`

- [ ] **Step 1: Confirm nothing else imports it**

Run: `grep -rln "import Markdown" src/ --include='*.elm' | grep -v Evergreen | grep -v "src/Markdown/"`
Expected: empty (only the dispatcher references `MarkdownLang`, not the module).

- [ ] **Step 2: Delete the directory**

```bash
git rm -r src/Markdown
```

- [ ] **Step 3: Remove the `MarkdownLang` constructor** in `src/ScriptaV2/Language.elm`

Delete `| MarkdownLang` from the `type Language` declaration and delete its `MarkdownLang -> "Markdown"` arm in `toString`.

- [ ] **Step 4: Build and follow the compiler to every `MarkdownLang` reference**

Run: `elm make src/ScriptaV2/APISimple.elm --output=/dev/null`
The compiler reports each missing-pattern / dangling reference (expected: `Compiler.elm` ~line 191, `DifferentialCompiler.elm` ~lines 340 and 357). Delete each `MarkdownLang ->` case arm. Repeat build-fix until `Success!`.

- [ ] **Step 5: Run tests**

Run: `elm-test`
Expected: same pass count as baseline (no test targeted plain Markdown).

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "refactor: remove standalone plain-Markdown language"
```

---

### Task 3: Remove LaTeX / Scripta export (render-only scope)

These are the export modules; the only in-tree consumer is `src/ScriptaV2/Helper.elm`.

**Files:**
- Delete: `src/Render/Export/LaTeX.elm`, `src/Render/Export/LaTeXToScripta.elm`, `src/Render/Export/LaTeXToScriptaTest.elm`, `src/Render/Export/Scripta.elm`, `src/Render/Export/Preamble.elm`, `src/Render/Html/Export.elm`
- Modify: `src/ScriptaV2/Helper.elm` (remove export-related functions/imports)
- Verify-keep: `src/Render/Export/Check.elm`, `Image.elm`, `Util.elm` (delete only if orphaned after the above)

- [ ] **Step 1: See exactly what Helper imports from export**

Run: `grep -n "import Render.Export\|import Render.Html.Export\|Export\." src/ScriptaV2/Helper.elm`
Note each exported-from-Helper function that depends on these (e.g. an `exportToLaTeX`-style helper).

- [ ] **Step 2: Delete the LaTeX/Scripta export modules**

```bash
git rm src/Render/Export/LaTeX.elm src/Render/Export/LaTeXToScripta.elm \
       src/Render/Export/LaTeXToScriptaTest.elm src/Render/Export/Scripta.elm \
       src/Render/Export/Preamble.elm src/Render/Html/Export.elm
```

- [ ] **Step 3: Remove export wiring from Helper**

In `src/ScriptaV2/Helper.elm`, delete the imports of the removed modules and any function whose body calls them. If a deleted Helper function is re-exported by `ScriptaV2.API`, remove it from `API.elm` too (the compiler will point you there).

- [ ] **Step 4: Build and follow errors for orphaned support modules**

Run: `elm make src/ScriptaV2/APISimple.elm --output=/dev/null`
For each remaining `src/Render/Export/*.elm` (`Check`, `Image`, `Util`), check whether anything still imports it:
`grep -rln "import Render.Export.Check\|import Render.Export.Util\|import Render.Export.Image" src/ --include='*.elm' | grep -v Evergreen`
`git rm` any that are now orphaned. Repeat build-fix until `Success!`.

- [ ] **Step 5: Run tests**

Run: `elm-test`
Expected: baseline pass count minus any export-specific test (the `LaTeXToScriptaTest` was a module-level test, already deleted; if `elm-test` referenced it, it is gone now).

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "refactor: remove LaTeX/Scripta export (render-only scope)"
```

---

### Task 4: Remove the MiniLaTeX language

**Files:**
- Delete: `src/MiniLaTeX/` (whole dir, 15 files), `tests/PrettyPrintTest.elm` (exercises `MiniLaTeX.Pretty`)
- Modify: `src/ScriptaV2/Language.elm`, `src/ScriptaV2/Compiler.elm` (`parseMiniLaTeX` def + dispatcher arms + the `exposing` list at line 3 + `compileML`-style helpers around lines 244-245), `src/ScriptaV2/DifferentialCompiler.elm` (imports lines 34-35, branches 331/348), `src/Generic/Acc.elm` (verify: it imports ETeX, not MiniLaTeX — should need no change)

- [ ] **Step 1: Confirm the MiniLaTeX consumer set**

Run: `grep -rln "import MiniLaTeX" src/ --include='*.elm' | grep -v Evergreen | grep -v "src/MiniLaTeX/"`
Expected consumers: `ScriptaV2/Compiler.elm`, `ScriptaV2/DifferentialCompiler.elm`, and possibly `ReplTest.elm`. (Export consumers were already removed in Task 3.)

- [ ] **Step 2: Delete the directory and its test**

```bash
git rm -r src/MiniLaTeX
git rm tests/PrettyPrintTest.elm
```

- [ ] **Step 3: Remove `MiniLaTeXLang` from the enum**

In `src/ScriptaV2/Language.elm`, delete `| MiniLaTeXLang` and its `toString` arm.

- [ ] **Step 4: Remove the MiniLaTeX dispatch in `Compiler.elm`**

In `src/ScriptaV2/Compiler.elm`: delete the `parseMiniLaTeX` function (~lines 219-221), its `MiniLaTeXLang ->` arms (~lines 185-186 and ~276-277), the `MiniLaTeX.*` imports (lines 21-22), `parseMiniLaTeX` from the `exposing` list (line 3), and any `compile`-by-MiniLaTeX convenience wrapper (~line 245).

- [ ] **Step 5: Remove the MiniLaTeX dispatch in `DifferentialCompiler.elm`**

Delete imports (lines 34-35) and the `MiniLaTeXLang ->` arms (~lines 331 and 348).

- [ ] **Step 6: Build and fix residuals (e.g. `src/ReplTest.elm`)**

Run: `elm make src/ScriptaV2/APISimple.elm --output=/dev/null`
`ReplTest.elm` is a dev scratch module that imports MiniLaTeX; if it errors, either trim its MiniLaTeX use or `git rm src/ReplTest.elm` (it is not part of the public API). Repeat build-fix until `Success!`.

- [ ] **Step 7: Run tests**

Run: `elm-test`
Expected: baseline minus PrettyPrint suite. `ToForestAndAccumulatorTest` may contain MiniLaTeX cases — if it fails to compile, comment/remove the MiniLaTeX test groups (full trim happens in Task 7).

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "refactor: remove MiniLaTeX language"
```

---

### Task 5: Remove L0 as a selectable language (keep shared inline parser)

Remove `ScriptaLang`, `parseScripta`, and the L0 **block** parser. **Keep** `Scripta.Expression`, `Scripta.Match`, `Scripta.Symbol`, `Scripta.Tokenizer` — they are the shared table/macro/`@` inline parser (see CRITICAL FINDING).

**Files:**
- Delete: `src/Scripta/PrimitiveBlock.elm`, `tests/ScriptaPrimitiveBlockTest.elm`; `src/Scripta/Regex.elm` only if orphaned
- Modify: `src/ScriptaV2/Language.elm`, `src/ScriptaV2/Compiler.elm` (`parseScripta` def ~lines 197-199 + dispatcher arms ~182-183, ~273-274 + `exposing` list + L0 convenience wrappers ~lines 164, 240), `src/ScriptaV2/DifferentialCompiler.elm` (`Scripta.PrimitiveBlock` import line 42 + `ScriptaLang ->` arms 334/351)
- Keep (do not touch): `src/Scripta/Expression.elm`, `Match.elm`, `Symbol.elm`, `Tokenizer.elm`

- [ ] **Step 1: Re-confirm what is shared vs L0-only**

Run: `grep -rln "import Scripta.Expression" src/ --include='*.elm' | grep -v Evergreen`
Expected (these prove `Scripta.Expression` must stay): `Generic/Pipeline.elm`, `Generic/TextMacro.elm`, `Render/Tabular.elm`, `XMarkdown/Expression.elm`, plus the dispatchers.
Run: `grep -rln "import Scripta.PrimitiveBlock" src/ --include='*.elm' | grep -v Evergreen`
Expected (these are the only consumers, all being edited/removed): `ScriptaV2/Compiler.elm`, `ScriptaV2/DifferentialCompiler.elm`, `ScriptaV2/Test.elm`, `ReplTest.elm`.

- [ ] **Step 2: Delete the L0 block parser and its test**

```bash
git rm src/Scripta/PrimitiveBlock.elm tests/ScriptaPrimitiveBlockTest.elm
```

- [ ] **Step 3: Remove `ScriptaLang` from the enum**

In `src/ScriptaV2/Language.elm`, delete `| ScriptaLang` and its `toString` arm. (After this and Task 4, only `SMarkdownLang` remains — see Task 6.)

- [ ] **Step 4: Remove L0 dispatch in `Compiler.elm`**

Delete the `parseScripta` function (~197-199), its dispatcher arms (~182-183, ~273-274), the `Scripta.PrimitiveBlock` import (line 29), `parseScripta` from `exposing` (line 3), and the L0 convenience wrappers at ~line 164 (`compileScripta`-style) and ~line 240. **Leave `import Scripta.Expression`** if Compiler uses it; remove only if the compiler flags it as unused.

- [ ] **Step 5: Remove L0 dispatch in `DifferentialCompiler.elm`**

Delete the `Scripta.PrimitiveBlock` import (line 42) and the `ScriptaLang ->` arms (~334, ~351). Keep `import Scripta.Expression` if still used.

- [ ] **Step 6: Handle `ScriptaV2/Test.elm` and `ReplTest.elm`**

These dev modules import `Scripta.PrimitiveBlock`. Trim those references or `git rm` the modules (neither is in `exposed-modules`).

- [ ] **Step 7: Build; check whether `Scripta.Regex` is now orphaned**

Run: `elm make src/ScriptaV2/APISimple.elm --output=/dev/null` then
`grep -rln "import Scripta.Regex" src/ --include='*.elm' | grep -v Evergreen | grep -v "src/Scripta/"`
If empty, `git rm src/Scripta/Regex.elm` and rebuild. Repeat build-fix until `Success!`.

- [ ] **Step 8: Run tests**

Run: `elm-test`
Expected: passes (ScriptaPrimitiveBlock suite removed). If `ToForestAndAccumulatorTest` has L0 groups that no longer compile, trim them (full trim in Task 7).

- [ ] **Step 9: Commit**

```bash
git add -A && git commit -m "refactor: drop L0 as selectable language; keep Scripta.Expression as shared inline parser"
```

---

### Task 6: Collapse the Language type and default the API to XMarkdown

After Tasks 2/4/5 the only constructor left is `SMarkdownLang`. Make the public API default to it.

**Files:**
- Modify: `src/ScriptaV2/Language.elm`, `src/ScriptaV2/API.elm:161` (default `lang`), `src/ScriptaV2/APISimple.elm` (doc comment ~lines 19-24), `src/ScriptaV2/Compiler.elm` (the `case lang of` in `parse`/`compile` now has one arm)

- [ ] **Step 1: Confirm only `SMarkdownLang` remains**

Run: `grep -n "Lang" src/ScriptaV2/Language.elm`
Expected: only `SMarkdownLang`.

- [ ] **Step 2: Simplify single-arm `case lang of` expressions**

In `Compiler.elm` and `DifferentialCompiler.elm`, any `case lang of` now has exactly one arm. Leave them as single-arm cases (valid Elm) OR replace the dispatch body with a direct call to `parseSMarkdown ...` ignoring `lang`. Prefer the direct call for clarity:

```elm
parse _ idPrefix outerCount lines =
    parseSMarkdown idPrefix outerCount lines
```

Run: `elm make src/ScriptaV2/APISimple.elm --output=/dev/null` → `Success!`

- [ ] **Step 3: Default `API.settings.lang` to `SMarkdownLang`**

In `src/ScriptaV2/API.elm`, change line ~161 from `lang = ScriptaV2.Language.MiniLaTeXLang` to `lang = ScriptaV2.Language.SMarkdownLang`. Update the "Supported Languages" doc block (~lines 69-115) to describe XMarkdown only.

- [ ] **Step 4: Update the `APISimple` doc comment**

In `src/ScriptaV2/APISimple.elm`, edit the example doc (~lines 19-24) so the `Language` type shown lists only `SMarkdownLang`.

- [ ] **Step 5: Build and test**

Run: `elm make src/ScriptaV2/APISimple.elm --output=/dev/null && elm-test`
Expected: `Success!` and tests pass.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "refactor: collapse Language to SMarkdown and default API to it"
```

---

### Task 7: Prune dependencies, finalize tests, rename package

**Files:**
- Modify: `elm.json` (via `elm-json`), `tests/ToForestAndAccumulatorTest.elm`, `tests/ToExpressionBlockTest.elm`, `README.md`, `CLAUDE.md`

- [ ] **Step 1: Trim tests to XMarkdown-only**

Open `tests/ToForestAndAccumulatorTest.elm` and `tests/ToExpressionBlockTest.elm`; remove `describe`/test groups that target MiniLaTeX or L0 input. Keep XMarkdown cases. Add at least one XMarkdown round-trip test if coverage looks thin (source string → `ScriptaV2.APISimple.compile` produces non-empty elm-ui).

Run: `elm-test`
Expected: green, XMarkdown-only.

- [ ] **Step 2: Find candidate unused dependencies**

For each dependency that plausibly served a removed feature, check for remaining imports. Likely candidates after removing LaTeX export and L0/MiniLaTeX:
```bash
# example checks — run per suspect package's modules
grep -rln "import SyntaxHighlight" src/ --include='*.elm' | grep -v Evergreen   # pablohirafuji/elm-syntax-highlight (code blocks — likely still needed)
grep -rln "import Diff" src/ --include='*.elm' | grep -v Evergreen              # jinjor/elm-diff (Differential — likely needed)
```
Only remove a dependency if **zero** non-Evergreen modules import it. Most deps support rendering features shared by XMarkdown and will stay.

- [ ] **Step 3: Remove confirmed-unused deps via elm-json**

```bash
# only for packages proven unused in Step 2:
npx elm-json uninstall <author/package> -- elm.json
```
Run: `elm make src/ScriptaV2/APISimple.elm --output=/dev/null` after each removal to confirm still green.

- [ ] **Step 4: Rename the package**

```bash
npx elm-json --help  # confirm available ops; name/summary may need a manual edit
```
Edit `elm.json` `name` to e.g. `jxxcarlson/xmarkdown-compiler`, `version` to `1.0.0`, and `summary` to "A compiler for XMarkdown (Scientific Markdown)". (Name/summary/version are metadata; editing these specific fields by hand is acceptable — the elm-json restriction matters for the `dependencies` block.)

- [ ] **Step 5: Update README and CLAUDE.md**

Rewrite `README.md` and `CLAUDE.md` to describe a single-language XMarkdown compiler (drop MiniLaTeX/L0 sections).

- [ ] **Step 6: Final full verification**

Run: `elm make src/ScriptaV2/APISimple.elm --output=/dev/null && elm-test && npx elm-review --ignore-dirs src/Evergreen/`
Expected: clean build, green tests, no review errors.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "chore: prune deps, finalize XMarkdown-only tests, rename package"
```

---

### Task 8 (OPTIONAL): Rename shared `Scripta.*` modules out of the L0 namespace

Cosmetic: the kept inline parser still lives under `Scripta.*`. Rename to a neutral namespace (e.g. `Internal.Inline.*`) so the standalone package no longer advertises L0. Skip if not worth the churn.

**Files:**
- Rename: `src/Scripta/Expression.elm` → `src/Internal/Inline/Expression.elm` (and `Match`, `Symbol`, `Tokenizer` similarly)
- Modify: every importer found by grep

- [ ] **Step 1: List importers**

Run: `grep -rln "import Scripta\." src/ --include='*.elm' | grep -v Evergreen`

- [ ] **Step 2: Move files and update module declarations**

```bash
mkdir -p src/Internal/Inline
git mv src/Scripta/Expression.elm src/Internal/Inline/Expression.elm
git mv src/Scripta/Match.elm src/Internal/Inline/Match.elm
git mv src/Scripta/Symbol.elm src/Internal/Inline/Symbol.elm
git mv src/Scripta/Tokenizer.elm src/Internal/Inline/Tokenizer.elm
```
Update each file's `module Scripta.X exposing` → `module Internal.Inline.X exposing`.

- [ ] **Step 3: Update all importers**

Replace `import Scripta.Expression` → `import Internal.Inline.Expression` (and the others) across the files from Step 1, including qualified usages.

- [ ] **Step 4: Build, test, commit**

```bash
elm make src/ScriptaV2/APISimple.elm --output=/dev/null && elm-test
git add -A && git commit -m "refactor: move shared inline parser out of Scripta namespace"
```

---

## Self-Review Notes

- **Spec coverage:** L0 disentangle (Tasks 5, 8) · MiniLaTeX removal (Task 4) · render-only/no-export (Task 3) · plan written to chosen location (this file). ✓
- **Risk hot-spots:** the dispatchers (`Compiler.elm`, `DifferentialCompiler.elm`) and `Generic/Acc.elm` — these are where shared and language-specific code meet. The build-fix loop in each task is the safety mechanism.
- **Line numbers** are from the reference repo at planning time and will drift as edits land; treat them as starting points and let `elm make` confirm the real location.
- **The Elm compiler is the test harness** for this refactor: a clean `elm make` of the public entry point proves no dangling references remain.

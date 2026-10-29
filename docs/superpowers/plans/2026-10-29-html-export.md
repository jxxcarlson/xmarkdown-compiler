# XMarkdown → standalone HTML export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `HTML.Export.toTextHtml : TOC -> SectionNumbers -> AST -> String` turns a parsed XMarkdown document into a complete web page that any browser displays, with math typeset by KaTeX from a CDN.

**Architecture:** `XMarkdown.API.parse` wraps the internal parser in an opaque `AST`. `HTML.Export` prepares the forest (section-level fix-ups, `AST.Acc` numbering, unique slugs, numbering on/off), then walks it with new internal modules `HTML.Escape`, `HTML.Inline`, `HTML.Block` and `HTML.Style`, mirroring the `LaTeX.*` exporter. Math is emitted as escaped LaTeX inside `.xm-math` elements that an inline script hands to `katex.render`.

**Tech Stack:** Elm 0.19.x package `jxxcarlson/xmarkdown-compiler`, `jxxcarlson/etex` (`ETeX.Transform.transformETeX`), `RoseTree.Tree`, `elm-explorations/test`, KaTeX 0.16.9 (CDN, in the generated page only).

**Spec:** `docs/superpowers/specs/2026-10-29-html-export-design.md` (summary: `docs/plan-for-textHtml-export.md`)

## Global Constraints

- **Precondition:** `elm.json` line 1 currently reads `pwd{` (an accidental uncommitted edit). Restore it to `{` with the user's OK before Task 1; nothing builds until then.
- Options are custom types, never `Bool`: `type TOC = WithTOC | WithoutTOC`, `type SectionNumbers = WithSectionNumbers | WithoutSectionNumbers`. This applies to internal helpers too.
- Exposed API added: `XMarkdown.API.AST`, `XMarkdown.API.parse`, module `HTML.Export` (`TOC(..)`, `SectionNumbers(..)`, `toTextHtml`). Add `HTML.Export` to `exposed-modules` in `elm.json` by hand. Everything else is internal.
- Do not change the live renderer (`Render.*`), `AST.Acc`, existing `XMarkdown.API` functions, or LaTeX output. Moving a LaTeX helper to a shared module is fine if `LaTeX*Test` still passes unchanged.
- KaTeX 0.16.9 from `https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/`: `katex.min.css`, `katex.min.js`, `contrib/mhchem.min.js`. Render options `{ displayMode, throwOnError: false, trust: true }` (as the apps' `assets/katex.js`).
- Escape `& < > "` (and `'` in attributes) in every piece of user text, URL and attribute.
- Math goes through `ETeX.Transform.transformETeX Dict.empty`. Output starting with `[ETeX error]` means failure: emit the original trimmed source instead (KaTeX then shows it in red).
- No equation, figure or theorem numbers. Section numbers only with `WithSectionNumbers`, at all levels.
- Verification after every task:
  `elm make src/XMarkdown/API.elm src/XMarkdown/Types.elm src/Render/Theme.elm src/LaTeX/Export.elm src/HTML/Export.elm --output=/dev/null && npx elm-test`
  (`src/HTML/Export.elm` joins the command in Task 5.)
- **Do not commit.** The user's standing rule: no commits until they've tested. Each task ends with verification, not a commit.

## Review Focus

1. **Prose that looks like markup** (`if a<b && c>d`, `<script>`, `"quotes"` in a link label or image caption): must be shown as text, never become tags or break an attribute. Test in Tasks 2 and 3.
2. **A formula ETeX rejects** (`a\:b`): the page still loads and the formula is shown, not dropped. Test in Task 3.
3. **Two headings with the same text** (`# Notes` twice): distinct ids, and each TOC link goes to its own heading. Test in Task 5.
4. **A document starting at `##`, or with hand-typed numbers** (`## 2.1 Results`): with `WithSectionNumbers`, labels are `1`, `2`, … with no `0.1` and no `2.1 2.1`. Test in Task 5.
5. **`$` and `\` in prose and code** (`costs $5`, `C:\path`): not treated as math by the page script (the script renders only `.xm-math` elements). Test in Task 5.

---

### Task 1: Opaque `AST` and `XMarkdown.API.parse`

**Files:**
- Create: `src/XMarkdown/AST.elm`
- Modify: `src/XMarkdown/API.elm` (exposing list, docs, new functions)
- Modify: `elm.json` (line 1 fix only; see precondition)
- Test: `tests/HTMLParseTest.elm`

**Interfaces:**
- Produces:
  - `XMarkdown.AST.AST` = `AST (Forest ExpressionBlock)` (constructor exposed; module internal)
  - `XMarkdown.AST.forest : AST -> Forest ExpressionBlock`
  - `XMarkdown.API.AST` (type alias of `XMarkdown.AST.AST`, documented as opaque)
  - `XMarkdown.API.parse : String -> AST` (wraps `XMarkdown.Compiler.parseFromString`)

- [ ] **Step 1: Write the failing test** `tests/HTMLParseTest.elm`:
  - `"parse gives one tree per top-level block"`: `XMarkdown.API.parse "# A\n\nHello." |> XMarkdown.AST.forest |> List.length` equals `2`.
  - `"parse matches parseFromString"`: `XMarkdown.AST.forest (XMarkdown.API.parse s)` equals `XMarkdown.Compiler.parseFromString s` for `s = "- a\n- b\n\n$$\nx^2\n$$"`.
- [ ] **Step 2: Run** `npx elm-test tests/HTMLParseTest.elm`. Expected: FAIL (module `XMarkdown.AST` not found).
- [ ] **Step 3: Implement** both modules. Add `AST, parse` to `XMarkdown.API`'s exposing list and a `@docs` line under a new `# Parsing` heading that explains the button flow (`parse` then `HTML.Export.toTextHtml`).
- [ ] **Step 4: Run the verification command.** Expected: compiles, all tests pass. Also run `elm make --docs=/tmp/docs.json` and check `XMarkdown.API.AST` is listed. If the alias documents badly, switch to defining `type AST` without its constructor in `XMarkdown.API`, with `XMarkdown.AST` holding only an accessor. Record the choice in the module comment.

### Task 2: `HTML.Escape`

**Files:**
- Create: `src/HTML/Escape.elm`
- Test: `tests/HTMLEscapeTest.elm`

**Interfaces:**
- Produces: `HTML.Escape.text : String -> String`, `HTML.Escape.attribute : String -> String`

- [ ] **Step 1: Write the failing tests:**
  - `text "a<b && c>d"` == `"a&lt;b &amp;&amp; c&gt;d"`
  - `text "<script>alert(1)</script>"` == `"&lt;script&gt;alert(1)&lt;/script&gt;"`
  - `attribute "say \"hi\" & 'bye'"` == `"say &quot;hi&quot; &amp; &#39;bye&#39;"`
  - `text "&amp;"` == `"&amp;amp;"` (no double-decoding: `&` always escaped first)
- [ ] **Step 2: Run** `npx elm-test tests/HTMLEscapeTest.elm`. Expected: FAIL.
- [ ] **Step 3: Implement.** `&` is replaced first. `text` escapes `& < > "`, and `attribute` also escapes `'`.
- [ ] **Step 4: Run the verification command.** Expected: PASS.

### Task 3: `HTML.Inline`

**Files:**
- Create: `src/HTML/Inline.elm`
- Test: `tests/HTMLInlineTest.elm`

**Interfaces:**
- Consumes: `HTML.Escape.text`, `HTML.Escape.attribute`; `LaTeX.Image.fromText : String -> { url, caption, width : Maybe Int }`; `LaTeX.Inline.plainText : List Expression -> String`
- Produces:
  - `HTML.Inline.exprs : List Expression -> String`
  - `HTML.Inline.math : MathMode -> String -> String`, where `type MathMode = InlineMath | DisplayMath`. It ETeX-transforms the source and returns the `.xm-math` element. `DisplayMath` gives `<div class="xm-math" data-display="true">…</div>`, and `InlineMath` gives `<span class="xm-math" data-display="false">…</span>`.
  - `HTML.Inline.image : String -> String` (image text → `<img>`)

Tests parse a one-line paragraph with `XMarkdown.Compiler.parseFromString` and pass its `Right` body to `exprs`. Write a helper `inline : String -> String` in the test file.

- [ ] **Step 1: Write the failing tests** (exact output, after `String.trim`):
  - `inline "a < b"` == `"a &lt; b"`
  - `inline "**b** and *i*"` == `"<strong>b</strong> and <em>i</em>"`
  - `inline "[NYT](https://n.com)"` == `"<a href=\"https://n.com\">NYT</a>"`
  - `inline "[say \"hi\"](https://n.com?a=1&b=2)"` contains `href="https://n.com?a=1&amp;b=2"` and `>say &quot;hi&quot;</a>`
  - ``inline "`a<b`"`` == `"<code>a&lt;b</code>"`
  - `inline "$sqrt(2)$"` == `"<span class=\"xm-math\" data-display=\"false\">\\sqrt{2}</span>"`
  - `inline "$a<b$"` contains `>a&lt;b</span>`
  - `inline "$a\\:b$"` (ETeX error) contains `class="xm-math"` and `a\:b`
  - `inline "$$"` (empty inline math) == `""`
  - `inline "![Robin <1> width:400](https://x.com/a.jpg)"` == `"<img class=\"xm-image\" src=\"https://x.com/a.jpg\" alt=\"Robin &lt;1&gt;\" width=\"400\">"`
  - An unknown function (build it directly as `Fun "frobnicate" [Text "x" emptyExprMeta] emptyExprMeta`) gives `"<span class=\"xm-unsupported\" data-name=\"frobnicate\">x</span>"`
- [ ] **Step 2: Run** `npx elm-test tests/HTMLInlineTest.elm`. Expected: FAIL.
- [ ] **Step 3: Implement.** The names are the same as in `LaTeX.Inline.fun` / `vfun`: `bold|b|strong`, `italic|i|em`, `link|a` (the URL is the last word of `plainText args`), `image|img`, and `VFun` `math|m`, `chem` (`\ce{…}` inside inline math), `code`. `ExprList` recurses into its expressions. `img` has no `width` attribute when `width` is `Nothing`.
- [ ] **Step 4: Run the verification command.** Expected: PASS.

### Task 4: `HTML.Block`

**Files:**
- Create: `src/HTML/Block.elm`
- Test: `tests/HTMLBlockTest.elm`

**Interfaces:**
- Consumes: Task 3's `exprs`, `math`, `image`; `HTML.Escape.*`
- Produces: `HTML.Block.forest : Forest ExpressionBlock -> String`. Blocks are joined with `"\n"`. A section shows a number **iff** its `properties` has `"label"`, and its id is `properties["tag"]`. Task 5 controls both, so `HTML.Block` has no options.

Tests run `XMarkdown.Compiler.parseFromString src |> AST.Acc.transformAccumulate |> Tuple.second |> HTML.Block.forest`. Write a helper `block : String -> String` in the test file. Use the AST facts table in `docs/superpowers/plans/2026-10-01-latex-export.md` for which source produces which block.

- [ ] **Step 1: Write the failing tests:**
  - `block "Hello."` == `"<p class=\"xm-paragraph\">Hello.</p>"`
  - `block "## Results"` contains `<h3 class="xm-section" data-level="2" id="results">` and `Results</h3>`, and has no `xm-section-number` unless a label is set. To check the labelled case, build a section whose `properties` has `label = "1.1"` and assert it contains `<span class="xm-section-number">1.1</span> Results`. Heading tag = level + 1, capped at `h6`.
  - `block "- a\n  - b\n- c"` (compact) == `"<ul class=\"xm-list\"><li>a<ul class=\"xm-list\"><li>b</li></ul></li><li>c</li></ul>"`
  - `block ". one\n. two"` starts with `<ol class="xm-list"><li>one</li>`
  - `block "- a\n\n  - nested\n\n- b"` (loose) gives one `<ul class="xm-list">` whose first `<li>` contains `a`, then a nested `<ul>` with `nested`, and whose second `<li>` contains `b`. Assert `String.indexes "<ul class=\"xm-list\">"` has length 2 and the output starts with `<ul`.
  - `block "> a\n>\n> b"` == `"<blockquote class=\"xm-quotation\"><p>a</p><p>b</p></blockquote>"` (`Text ">"` splits paragraphs, as in `LaTeX.Block.quotation`)
  - `block "/begin verse\nRoses *red*,\n    violets\n\nSugar\n/end verse"` contains `<div class="xm-verse">`, `<div class="xm-verse-line">Roses <em>red</em>,</div>`, `<div class="xm-verse-line" style="padding-left:2em">violets</div>` (indent ÷ 2 em) and `<div class="xm-verse-blank"></div>`
  - GFM table `"| A | B |\n|:--|--:|\n| 1 | 2 |"` contains `<table class="xm-table"><thead><tr><th style="text-align:left">A</th><th style="text-align:right">B</th></tr></thead><tbody><tr><td style="text-align:left">1</td>`
  - `block "![Robin](https://x.com/a.jpg)"` (a paragraph whose only content is an image) == `"<figure class=\"xm-figure\"><img class=\"xm-image\" src=\"https://x.com/a.jpg\" alt=\"Robin\"><figcaption>Robin</figcaption></figure>"`. With no caption, there is no `<figcaption>`.
  - `block "---"` == `"<hr class=\"xm-hrule\">"`
  - `block "```elm\nx = a < b\n```"` == `"<pre class=\"xm-code\"><code class=\"language-elm\">x = a &lt; b</code></pre>"`. With no language, there is no `class` on `<code>`.
  - `block "$$\nsqrt(2)\n$$"` == `"<div class=\"xm-math\" data-display=\"true\">\\sqrt{2}</div>"`
  - `block "| equation\nx^2"` == `"<div class=\"xm-equation\"><div class=\"xm-math\" data-display=\"true\">x^2</div></div>"` (no number)
  - `block "| aligned\na &= b \\\\\nc &= d"` contains `\begin{aligned}` and `\end{aligned}`
  - `block "| chem\nH2O"` contains `data-display="true">\ce{H2O}</div>`
  - `block "/begin theorem\nAll *x*.\n/end theorem"` == `"<div class=\"xm-block xm-theorem\">All <em>x</em>.</div>"`
  - The title block (`"%title T\n\nHi."`) produces no output for the `titleBlock` block (Task 5 renders it).
- [ ] **Step 2: Run** `npx elm-test tests/HTMLBlockTest.elm`. Expected: FAIL.
- [ ] **Step 3: Implement.** Follow `LaTeX.Block`'s structure. Reuse its loose-list `group` logic (move `Group`/`group` to a shared internal module such as `AST.ListGroup` if needed), its `mathSource`, and its array column-spec logic. Other rules:
  - A tree's children are rendered after the block.
  - `hrule` with trailing text adds a paragraph.
  - `setcounter`, `shiftandsetcounter`, `Verbatim "settings"` and `titleBlock` give `""`.
  - Any other `Ordinary NAME` gives `<div class="xm-block xm-NAME">` with its inline body.
  - Any other `Verbatim NAME` gives `<pre class="xm-block xm-NAME">` with escaped text.
  - NAME goes through `HTML.Escape.attribute`.
- [ ] **Step 4: Run the verification command.** Expected: PASS, and `LaTeX*Test` still passes if helpers moved.

### Task 5: `HTML.Style` and `HTML.Export` (the page)

**Files:**
- Create: `src/HTML/Style.elm`, `src/HTML/Export.elm`
- Modify: `elm.json` (`exposed-modules` += `"HTML.Export"`), `CLAUDE.md` (verification command, public entry points, module layout line `HTML/`), `docs/changelog.md`
- Test: `tests/HTMLExportTest.elm`

**Interfaces:**
- Consumes: `XMarkdown.AST.forest`, `HTML.Block.forest`, `HTML.Escape.*`, `LaTeX.Block.normalizeSectionLevels`, `LaTeX.Block.stripSectionNumbers`, `AST.Acc.transformAccumulate`, `AST.TitleBlock.fromForest`, `AST.ASTTools.tableOfContents`
- Produces:
  - `HTML.Export.TOC(..)`, `HTML.Export.SectionNumbers(..)`, `HTML.Export.toTextHtml : TOC -> SectionNumbers -> AST -> String`
  - `HTML.Style.defaultCss : String`, `HTML.Style.katexHead : String` (link + 2 deferred scripts + the render script)

The pipeline inside `toTextHtml`:

```
forest
  |> normalizeSectionLevels |> stripSectionNumbers
  |> transformAccumulate |> Tuple.second
  |> uniqueTags           -- 2nd "notes" → "notes-2", 3rd → "notes-3"
  |> (WithoutSectionNumbers → remove "label" from section blocks)
```

The page layout is in the spec, under "Page structure". The `<title>` comes from the title block's title, else the plain text of the first section, else `Untitled`. The header shows only the fields that are present, with authors joined by `", "`. The TOC is a `<nav class="xm-toc"><ul>…</ul></nav>` nested by `level`. Each entry is `<li><a href="#TAG">[<span class="xm-section-number">N</span> ]Text</a>…</li>`.

The render script is an inline `<script>` in `<head>` that registers a `DOMContentLoaded` listener. Deferred scripts run before `DOMContentLoaded` fires, so `katex` and mhchem are defined by then. The listener runs: `document.querySelectorAll(".xm-math").forEach(el => katex.render(el.textContent, el, {displayMode: el.dataset.display === "true", throwOnError: false, trust: true}))`.

`defaultCss` targets only `xm-*` classes and plain elements: a centred column `max-width: 42rem`, a serif body, `figure img { max-width: 100% }`, a bordered `.xm-table`, `.xm-verse-line` with `white-space: pre-wrap`, and a muted `.xm-unsupported`. It sits in `<style id="xm-default-style">`.

- [ ] **Step 1: Write the failing tests** (use `page : TOC -> SectionNumbers -> String -> String = \t n s -> toTextHtml t n (XMarkdown.API.parse s)`):
  - `page WithoutTOC WithoutSectionNumbers "Hi."` starts with `"<!doctype html>\n<html lang=\"en\">"`, contains `<p class="xm-paragraph">Hi.</p>`, `<title>Untitled</title>`, `katex@0.16.9/dist/katex.min.css`, `contrib/mhchem.min.js`, `<style id="xm-default-style">`, and exactly one `<body>` (`String.indexes "<body>"` length 1). It ends with `"</html>\n"`.
  - Title block: `"%title A <B>\n%author X\n%author Y\n%date 2026\n\n# Intro"` gives `<title>A &lt;B&gt;</title>` and `<header class="xm-title-block"><h1 class="xm-title">A &lt;B&gt;</h1><p class="xm-authors">X, Y</p><p class="xm-date">2026</p></header>`.
  - Title fallback: `"# First\n\nx"` gives `<title>First</title>` and no `xm-title-block`.
  - `WithSectionNumbers`, `"# A\n\n## B\n\n# C"`: section numbers `1`, `1.1`, `2` in that order.
  - `WithSectionNumbers`, `"## A\n\n## B"`: numbers `1` and `2` (no `0.1`).
  - `WithSectionNumbers`, `"# 1. Intro"`: contains `<span class="xm-section-number">1</span> Intro` and not `1. Intro`.
  - `WithoutSectionNumbers`, `"# A"`: no `xm-section-number` anywhere (body or TOC).
  - `WithTOC WithSectionNumbers`, `"# A\n\n## B"`: contains `<nav class="xm-toc"><ul><li><a href="#a"><span class="xm-section-number">1</span> A</a><ul><li><a href="#b">`.
  - `WithoutTOC`: no `xm-toc`.
  - Duplicate headings `"# Notes\n\nx\n\n# Notes"`: ids `notes` and `notes-2`; with `WithTOC`, links `#notes` and `#notes-2`.
  - `"costs $5 and C:\\path"` (no closing `$`): does not emit an `xm-math` element. *(Builder: if the parser does treat this as math, assert what it produces and note it; the point is that the page never scans raw text for `$`.)*
  - The render script contains `querySelectorAll(".xm-math")` and `throwOnError: false`.
- [ ] **Step 2: Run** `npx elm-test tests/HTMLExportTest.elm`. Expected: FAIL.
- [ ] **Step 3: Implement** `HTML.Style` and `HTML.Export`. Document `toTextHtml` with the button example from `docs/plan-for-textHtml-export.md`. Update `elm.json`, `CLAUDE.md` and the changelog (an "Unreleased / 2.2.0" entry).
- [ ] **Step 4: Run the verification command** (now including `src/HTML/Export.elm`). Expected: PASS. Then `elm make --docs=/tmp/docs.json`. Expected: succeeds, `HTML.Export` is documented.
- [ ] **Step 5: Manual check.** In `elm repl`, write `toTextHtml WithTOC WithSectionNumbers (XMarkdown.API.parse <DemoTOC+Sync's sample document>)` to a scratch `.html`. Open it in a browser and check math (inline, display, aligned, chem), tables, images, lists, verse, TOC links and the title block. Report what you saw to the user. Don't commit.

## Out of scope (follow-ups)

- The "Export HTML" menu item in the demo apps (separate change, after the user has tested this).
- CSS options, dark theme.
- `elm bump` / publishing 2.2.0 (the user's release step).

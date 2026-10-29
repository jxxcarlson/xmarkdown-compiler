# XMarkdown → standalone HTML export — design

Status: draft for discussion (2026-10-29).

## Goal

An app that embeds the compiler (DemoTOC+Sync, XMarkdownNetlifyDemo, the
desktop app) gets an "Export HTML" button that:

1. parses the current document (String → AST),
2. turns the AST into HTML text (AST → String),
3. saves the string.

The saved file is a **complete web page**: double-click it and any browser
shows the document, with math typeset by KaTeX loaded from a CDN. No Elm app,
no app JavaScript (`math-text` custom element, `katex.js`), no elm-ui.

The compiler's job is step 2 only. Parsing already exists; the button and the
save belong to the app.

## Decisions (from brainstorming)

- **Output is a complete page**, not a fragment: `<!doctype html>`, `<head>`
  with `<meta charset>`, viewport meta, `<title>`, KaTeX CSS + JS from a CDN,
  a default `<style>` block, then `<body>`.
- **Plain, readable styling that is easy to restyle with CSS.** Not a visual
  match with the in-app renderer. Better CSS options are later work.
- **Main function** (the user's signature):

  ```elm
  type TOC
      = WithTOC
      | WithoutTOC

  type SectionNumbers
      = WithSectionNumbers
      | WithoutSectionNumbers

  toTextHtml : TOC -> SectionNumbers -> AST -> String
  ```

  Custom types rather than `Bool`s, because they carry meaning (the user's
  standing preference).
- **The AST is opaque** (user's choice): `XMarkdown.API` exposes
  `type AST` (no constructors) and `parse : String -> AST`. Apps can hold
  and pass an AST but not look inside it, so the internals stay free to
  change.
- Light theme only.
- No click-to-source sync, highlighting, `editCount`, or ids for the editor.

## Goals / non-goals / anti-goals

Goals
- Every block and inline element the live renderer supports produces sensible
  semantic HTML.
- Math renders in the browser exactly as KaTeX renders it in the app (same
  ETeX → LaTeX transformation).
- Every generated element has a stable, predictable class so later CSS can
  target anything without touching the compiler.

Non-goals (this version)
- Matching the app's fonts, colours, spacing.
- Dark theme, theme switching, multiple stylesheets (later work).
- Embedding images (they stay remote URLs), offline KaTeX, server-side KaTeX.
- Changing the live renderer or `XMarkdown.API`'s existing functions
  (adding `AST` and `parse` to it is fine).

Anti-goals (would make it a failure even if it "works")
- Unescaped user text: `<`, `&`, `"` in prose or code breaking the page, or
  injecting markup.
- Silently dropping content. Unknown constructs are shown as escaped text.
- A page that needs the app's JavaScript to display.

## Public API

Additions to `XMarkdown.API`:

```elm
type alias AST = XMarkdown.AST.AST   -- opaque to apps

parse : String -> AST                -- wraps XMarkdown.Compiler.parseFromString
```

New exposed module `HTML.Export` (mirrors `LaTeX.Export`):

```elm
module HTML.Export exposing (TOC(..), SectionNumbers(..), toTextHtml)

toTextHtml : TOC -> SectionNumbers -> AST -> String
```

An app's button does `source |> XMarkdown.API.parse |> HTML.Export.toTextHtml WithTOC WithSectionNumbers`
and saves the result.

How to make it opaque (builder's call, suggested): a new **internal** module
`XMarkdown.AST` defines `type AST = AST (Forest ExpressionBlock)` and exposes
the constructor. `HTML.Export` imports it and unwraps the forest.
`XMarkdown.API` re-exports it as a type alias. Apps can't import the internal
module, so they can't see inside. Elm documents an alias of a type from an
unexposed module poorly, so check `elm make --docs`. If it reads badly,
define `AST` in an exposed module without its constructor plus an internal
accessor.

## Page structure

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>…</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@<pinned>/dist/katex.min.css">
  <script defer src="https://cdn.jsdelivr.net/npm/katex@<pinned>/dist/katex.min.js"></script>
  <script defer src="https://cdn.jsdelivr.net/npm/katex@<pinned>/dist/contrib/mhchem.min.js"></script>
  <style id="xm-default-style">…</style>
  <script>/* render .xm-math elements on DOMContentLoaded */</script>
</head>
<body>
  <article class="xm-document">
    <header class="xm-title-block">…</header>      <!-- if the doc has one -->
    <nav class="xm-toc">…</nav>                     <!-- WithTOC only -->
    …blocks…
  </article>
</body>
</html>
```

- **KaTeX version**: 0.16.9, the version the apps' `katex.js` loads (their
  `index.html` files still mention 0.12.0), plus mhchem for `chem`. *(Claude's
  call.)*
- **Math hand-off**: math is emitted as `<span class="xm-math" data-display="false">LaTeX</span>`
  (or `<div class="xm-math" data-display="true">`), text HTML-escaped. A
  ~10-line inline script calls `katex.render(el.textContent, el, {displayMode, throwOnError:false})`
  for each. No auto-render delimiter scanning, so `$` in prose is never
  misread.
- **Default style** lives in one function / one `<style id="xm-default-style">`
  block, so it can be swapped or dropped later.
- **Title**: from the document's title block (`AST.TitleBlock.fromForest`);
  else the first section heading's plain text; else `Untitled`.

## Mappings

The AST facts table in `docs/superpowers/plans/2026-10-01-latex-export.md`
describes which source produces which block/expression; it applies here too.

Blocks

| AST | HTML |
|---|---|
| title block | `<header class="xm-title-block">` with `<h1 class="xm-title">`, `<p class="xm-authors">`, `<p class="xm-date">` |
| `Ordinary "section"`, level n | `<h(n+1 capped at 6) class="xm-section" data-level="n" id="slug">` with `<span class="xm-section-number">2.1</span>` (number from the accumulator's `label` property). Level offset is the builder's call so the title stays the only `<h1>`. |
| `Paragraph` | `<p class="xm-paragraph">` |
| compact `itemList` / `numberedList` (`ExprList` indents) | nested `<ul class="xm-list">` / `<ol class="xm-list">` with `<li>` |
| loose `item` / `numbered` siblings, children nested | grouped into one `<ul>`/`<ol>`, children as nested lists (same grouping as `LaTeX.Block.group`) |
| `quotation` | `<blockquote class="xm-quotation">` |
| `verse` | `<div class="xm-verse">`, line breaks preserved (`white-space: pre-line` or `<br>`) |
| `/begin NAME … /end NAME` and numbered blocks (`theorem`, `definition`, … in `AST.Settings.numberedBlockNames`) | `<div class="xm-block xm-NAME">` with `<span class="xm-block-label">Theorem 1.2</span>` when numbered |
| GFM `table` | `<table class="xm-table">`, first row in `<thead>`, alignments from `properties.alignments` as `style="text-align:…"` |
| image | `<figure class="xm-figure"><img src alt width><figcaption>` (figure number from accumulator) |
| `hrule` | `<hr class="xm-hrule">` |
| `Verbatim "code"` | `<pre class="xm-code"><code class="language-X">` escaped |
| `Verbatim "math"` | display `xm-math` div |
| `equation` / `aligned` / `array` | display `xm-math` div wrapped in `<div class="xm-equation">` with `<span class="xm-equation-number">(2.3)</span>` when numbered; `aligned` → `\begin{aligned}…\end{aligned}` |
| `chem` | display math with `\ce{…}` |
| anything else | `<div class="xm-unsupported" data-name="NAME">` escaped source text |

Inline

| AST | HTML |
|---|---|
| `Text` | escaped text |
| `bold`/`b`/`strong` | `<strong>` |
| `italic`/`i`/`em` | `<em>` |
| `link`/`a` | `<a href>`; label/URL split as in `LaTeX.Inline.link` (URL is the last word) |
| `image`/`img` inline | `<img>` (same parsing as `LaTeX.Image.fromText`) |
| `VFun "code"` | `<code>` escaped |
| `VFun "math"`/`"m"` | inline `xm-math` span; empty math emits nothing |
| `VFun "chem"` | inline math with `\ce{…}` |
| unknown `Fun`/`VFun` | `<span class="xm-unsupported" data-name="NAME">` with escaped content |

Math text goes through `ETeX.Transform.transformETeX Dict.empty`, as in
`src/Render/Math.elm:44`. Math blocks read `meta.sourceText`, as the LaTeX
exporter does (spec adjustment 3 in the LaTeX plan).

## Numbering and the accumulator

**Rule (Claude's call): number exactly what the live renderer displays, no
more.** The live renderer shows no equation, `aligned`, `array` or figure
numbers, and `AST.Acc` doesn't reliably assign them (equations share
`blockCounter` with theorems; Markdown images are `Paragraph`s, so the
`figure` counter never fires). So this version emits no equation or figure
numbers and does not change `AST.Acc`. Numbered-block labels (Theorem 1.2)
appear only if the live renderer shows them. The `xm-equation-number` /
figure-number markup in the mapping tables is therefore omitted for now.

Section numbers (and slugs) are added by `AST.Acc.transformAccumulate`, not by
`parseFromString`. `toTextHtml` runs it on the forest inside the `AST`.

### Section numbers (`SectionNumbers`)

Before numbering, apply the LaTeX exporter's two passes,
`LaTeX.Block.normalizeSectionLevels` and `LaTeX.Block.stripSectionNumbers`
(moved to a shared module if that's cleaner, with LaTeX output unchanged).
This is in **both** modes *(Claude's call)*:
- a document that starts at `##` gets proper levels, not labels like `0.1`;
- hand-typed numbers (`# 1. Intro`) are removed, so `WithSectionNumbers`
  never shows `1. 1. Intro`.

Then:
- `WithSectionNumbers`: every section heading gets
  `<span class="xm-section-number">2.1</span>` from the accumulator's `label`,
  at all levels *(Claude's call: the app's `numberToLevel` depth limit isn't
  carried over)*.
- `WithoutSectionNumbers`: no number span.

The same choice applies to TOC entries.

## Table of contents (`WithTOC`)

- `<nav class="xm-toc">` after the title block: nested `<ul>` built from
  `AST.ASTTools.tableOfContents`, entries `<a href="#slug">2.1 Heading text</a>`
  (number only with `WithSectionNumbers`).
- Duplicate heading slugs get `-2`, `-3`, … so ids are unique and TOC links
  are unambiguous *(Claude's call)*.
- Sections get `id="slug"` (accumulator `tag` property) whether or not a TOC is
  emitted, so links into the page work either way.
- `WithoutTOC`: no `<nav>`.

## Modules

| Module | Role |
|---|---|
| `XMarkdown.AST` (internal) | `type AST = AST (Forest ExpressionBlock)` |
| `XMarkdown.API` (exposed, extended) | `AST` alias, `parse` |
| `HTML.Export` (exposed) | `TOC`, `SectionNumbers`, `toTextHtml`, page assembly, title |
| `HTML.Escape` | text and attribute escaping (`& < > " '`) |
| `HTML.Inline` | expressions → HTML |
| `HTML.Block` | blocks, list grouping, tables, figures, math blocks |
| `HTML.Style` | the default stylesheet string, and the KaTeX head/script strings |

Reuse `LaTeX.Image.fromText`, `LaTeX.Inline.plainText`, `LaTeX.Block`'s list
grouping logic where it fits, moving shared pieces out if needed, without
changing the LaTeX output.

## Testing

`tests/HTMLExportTest.elm` (and siblings as the modules grow), in the style of
`LaTeXExportTest.elm`:
- escaping in prose, code and attributes (`<script>`, `&`, `"`)
- each block and inline mapping in the tables above
- compact and loose nested lists
- `WithSectionNumbers` vs `WithoutSectionNumbers`; a document starting at
  `##`; hand-typed `# 1. Intro` never doubles up
- no equation or figure numbers are emitted
- `WithTOC` vs `WithoutTOC`; TOC anchors match section ids; duplicate
  headings get unique ids
- `parse` then `toTextHtml` works from source text (the app's path)
- title fallbacks (title block, first heading, `Untitled`)
- ETeX math is transformed; an ETeX error still produces a page
- the output starts with `<!doctype html>` and has exactly one `<body>`

Manual: export the sample document in the demo app, open it in a browser,
check math, tables, images, TOC links.

## Wiring into an app (follow-up, separate change)

An "Export HTML" item in the demo apps' File menu: `File.Download.string`
in the browser, the native save dialog in the desktop app. Not part of the
compiler change.

## Left to the builder

Exact default CSS, heading-level offset, class names beyond those listed,
whitespace/indentation of the emitted HTML, internal function names, how
`AST` is made opaque (one approach suggested above), mappings for `desc` /
`descriptionList` if they turn up.

## Release

This adds exposed API (`HTML.Export`, `XMarkdown.API.AST`, `parse`), which
makes it a minor version bump: 2.1.6 → 2.2.0. `elm bump` will confirm.

## Open questions

None.

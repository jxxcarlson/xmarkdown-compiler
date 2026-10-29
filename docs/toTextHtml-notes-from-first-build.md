# toTextHtml: notes from the first build

Date: 2026-10-29. Branch `html-export`, uncommitted (no commits until the
user has tested). 297/297 tests pass.

Related: [plan-for-textHtml-export.md](plan-for-textHtml-export.md),
[design](superpowers/specs/2026-10-29-html-export-design.md),
[implementation plan](superpowers/plans/2026-10-29-html-export.md).

An app's button does:

```elm
source |> XMarkdown.API.parse |> HTML.Export.toTextHtml WithTOC WithSectionNumbers
```

## What changed

- **New modules:** `HTML.Export` (public), plus internal `HTML.Escape`,
  `HTML.Inline`, `HTML.Block`, `HTML.Style` and `XMarkdown.AST`.
- **`XMarkdown.API`:** gains the opaque `AST` type and `parse`.
- **`LaTeX.Block`:** now also exposes `mathSource`. LaTeX output is unchanged.
- **Also:** `elm.json` lists `HTML.Export`; `CLAUDE.md` and the changelog are
  updated; there are five new test files, `tests/HTML*Test.elm`.

## Review

A fresh reviewer read the whole change and found four important problems, all
now fixed with tests that failed first:

1. A heading called "Notes 2" could get the same id as the second "Notes".
   Ids are now checked against every id already used.
2. Headings below level 4 repeated the level-4 number, because the compiler's
   numbering (`AST.Acc`) stops at four levels. Numbers are now computed in the
   exporter at any depth.
3. `javascript:` links and image URLs reached the page, and KaTeX ran with
   `trust: true`. Such URLs are now replaced (links point to `#`), and KaTeX
   trusts only http, https and relative URLs.
4. Headings with markup lost words in the page title and ids
   (`# Intro to *Elm*` gave `intro-to`). Text inside markup and math is now
   kept.

## Decisions made during the build (and what each costs if wrong)

- `AST` is a type alias in `XMarkdown.API`. The package docs show the type's
  internal module name (`XMarkdown.AST.AST`); if that bothers you, it's a
  small switch.
- The empty-math and no-caption tests use different inputs from the plan,
  because `$$` alone and `![](url)` are parsed differently from what the plan
  assumed.
- The small loose-list grouping helper is copied into `HTML.Block` rather than
  shared with `LaTeX.Block`, so the LaTeX code stays untouched. Cost: two
  copies to keep in step.
- Blank lines inside code blocks and verse are preserved. The plan's checks
  for missing elements now look for the elements themselves, because the
  default CSS mentions every class name.
- Section ids come from the heading text after hand-typed numbers are
  removed, so `# 1. Intro` gets `intro`. They may differ from the live app's
  ids.
- A skipped heading level counts as 0: `# A` then `### B` gives 1 and 1.0.1.
  The old numbering gave 1.1.
- KaTeX gets an allowlist instead of having trust turned off, so `\href` to
  ordinary web pages still works.
- One of the `javascript:` link tests had its input changed after the fix, so
  it wasn't seen failing first. It goes through the same code as a test that
  did.

## Deferred minors

- A table-of-contents entry for a heading that contains a link puts one link
  inside another.
- With a table of contents, about 3000 headings overflow the stack. Compact
  lists of about 3000 items overflow too, as they already do in the LaTeX
  export.
- `/begin theorem` blocks have no visible "Theorem" label.
- Unknown block names render as a generic styled block with their content,
  not as "unsupported" text as the design's table says.
- A few small test gaps: `## 2.1 Results`, an empty document, a quote in an
  image caption.

## Not yet checked

The exported HTML has been read but not viewed in a browser. The demo app's
sample document is exported to [sample-export.html](sample-export.html). Opening it in a browser is the real test of math, tables, images
and the table-of-contents links.

The HTML also shows two problems in the parser, not the export:

- a whitespace-only line in the sample's "Indentation" section swallows the
  `# Tables` heading;
- the document ends with an empty paragraph.

## Next steps

- The user tests the exported page.
- Commit.
- Add the "Export HTML" menu item to the apps.

Progress notes from the build are in
`.superpowers/sdd/2026-10-29-html-export/progress.md` (git-ignored).

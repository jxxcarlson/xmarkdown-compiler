# XMarkdown → LaTeX export — design

Date: 2026-10-01
Status: implemented (branch latex-export)

## Goal

Export XMarkdown source to LaTeX, either as a complete compilable `.tex`
document or as a body fragment to paste into an existing document. LaTeX
export existed before (`Render.Export.LaTeX`, removed in `af39ce1`), but it
targeted the old Scripta/MiniLaTeX AST. This is a fresh, compact exporter for
the current `AST.Language` types, reusing the proven ideas from the old code
(on-demand preamble, figure emission, list grouping).

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| Location | `src/LaTeX/` (part of the package; the demos see it via `../src`) |
| Output | Both: full document and body only |
| Title / author / date | Passed in by the caller as a record; `\maketitle` omitted when all three are empty |
| Images | Local path derived from the URL (`image/<filename>`), plus `imageUrls` returning `(url, localPath)` pairs for the app to download |
| Public API | New exposed module `LaTeX.Export`; `XMarkdown.API` unchanged |

## Modules

| Module | Responsibility |
|---|---|
| `LaTeX.Export` (exposed) | Public entry points (below). Parses with `XMarkdown.Compiler.parseFromString`, assembles the document. |
| `LaTeX.Block` | `ExpressionBlock` forest → LaTeX. Recurses into tree children so nested lists work. |
| `LaTeX.Inline` | `Expression` → LaTeX; escaping of plain text. |
| `LaTeX.Image` | Image → `\includegraphics` / `figure`; URL → local path; width property. |
| `LaTeX.Preamble` | Preamble with packages included only when the body needs them. |

### Public API (`LaTeX.Export`)

```elm
type alias DocumentInfo =
    { title : String, authors : List String, date : String }

exportDocument : DocumentInfo -> String -> String
exportBody : String -> String
imageUrls : String -> List ( String, String )   -- (url, localPath)
```

`exportDocument` = preamble + optional `\title{}`/`\author{}`/`\date{}` +
`\begin{document}` + optional `\maketitle` + body + `\end{document}`.
Authors are joined with ` \and `.

## Mappings

| XMarkdown (AST) | LaTeX |
|---|---|
| `Ordinary "section"`, property `level` 1–4 | `\section`, `\subsection`, `\subsubsection`, `\paragraph` (LaTeX numbers them) |
| `Paragraph` | inline content, then a blank line |
| compact `Ordinary "itemList"` / `"numberedList"` (one `ExprList` per item, with indent) | `itemize` / `enumerate`, nested by indent |
| loose `Ordinary "item"` / `"numbered"` sibling trees | consecutive siblings grouped into one `itemize` / `enumerate`, nested via tree children |
| `Ordinary "quotation"` | `quote` environment |
| `Verbatim "code"` | `verbatim` environment (body not escaped) |
| `Verbatim "math"` (`$$`, `\[…\]`) | `\[ … \]` after `ETeX.Transform.transformETeX` |
| `equation` / `aligned` | `equation` / `align*`, through the ETeX transform |
| `array` | `\[ \begin{array}{…} … \end{array} \]`; column spec from the block args (`\| array c c` → `cc`), else `c` × (number of `&` in the first row + 1) |
| `chem` | `\[ \ce{…} \]`, **not** ETeX-transformed (mhchem syntax, not math) |
| `Ordinary "table"` (property `alignments`) | `tabular` with column alignment, bold header row, `\hline` |
| inline `b`/`strong`/`bold` | `\textbf{}` |
| inline `i`/`em`/`italic` | `\emph{}` |
| inline `code` | `\texttt{}` (escaped) |
| inline `math`/`m` | `$…$` after ETeX transform |
| inline `chem` | `\ce{}` |
| inline `a`/`link` | `\href{url}{text}` |
| inline `image`/`img` | `figure` (with `\caption` if a caption is given), `\includegraphics[width=…]{image/<file>}` |
| unknown block/inline | `% unsupported: <name>` followed by the escaped text |

Math blocks are read from source, not the parsed body: `$$` / `\[` blocks
(`Verbatim "math"`) use the `Left` body minus the closing `$$`; `Ordinary`
math blocks use `meta.sourceText` minus its first line. (`| aligned` bodies
containing `\\` currently parse with a `tokenError`.)

Description lists are not exported: the parser never produces `desc` /
`descriptionList` blocks.

Plain text outside math escapes `\ # $ % & _ { } ~ ^`.

Image width: a `width:N` property (pixels) is converted to a fraction of
`\textwidth`, assuming a 600px reference width, capped at 1.0. With no width,
`0.75\textwidth`.

Local image path: `image/` + the last path segment of the URL with any query
string or fragment removed, and characters other than `[A-Za-z0-9._-]`
replaced by `-`.

## Preamble

`\documentclass[11pt]{article}` plus, only when used:

- `amsmath`, `amssymb`: when the body contains any math
- `graphicx`: images
- `hyperref`: links
- `mhchem`: chemistry

`inputenc`/`fontenc` (utf8/T1) are always included.

## Error handling

If `transformETeX` returns a string starting with `[ETeX error]`, emit the
original math source unchanged, preceded by a `% ETeX error` comment line,
so a single bad formula does not stop the document from compiling.

## Testing

- `tests/LaTeXExportTest.elm`: one focused test per row of the mapping table,
  plus escaping, image-path derivation, `imageUrls`, the omitted-`\maketitle`
  case, and the ETeX-error fallback.
- End-to-end: export the DemoTOC+Sync sample document with `exportDocument`
  and, if `pdflatex` is installed, check that it compiles. (Manual check, not
  part of `elm-test`.)
- `LaTeX.Export` added to `exposed-modules` in `elm.json`; the standard
  `elm make … && npx elm-test` must pass.

## Out of scope

Table of contents, BibTeX/citations, downloading images, cross-references /
labels for equations, LaTeX → XMarkdown.

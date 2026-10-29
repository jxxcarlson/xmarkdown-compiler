# Plan for text HTML export

Signature:

```elm
toTextHtml : TOC -> SectionNumbers -> AST -> String

type TOC = WithTOC | WithoutTOC
type SectionNumbers = WithSectionNumbers | WithoutSectionNumbers
```

`XMarkdown.API` gets an opaque `AST` type and `parse : String -> AST`, so an
app's "Export HTML" button does

```elm
source |> XMarkdown.API.parse |> HTML.Export.toTextHtml WithTOC WithSectionNumbers
```

and saves the resulting string as a complete web page (KaTeX from a CDN).

Full design: [superpowers/specs/2026-10-29-html-export-design.md](superpowers/specs/2026-10-29-html-export-design.md)

## Decisions made by Claude (reviewed by the user)

1. **KaTeX 0.16.9**, the version the apps actually load (their `index.html`
   files still mention 0.12.0).
2. **No equation or figure numbers.** The export numbers exactly what the
   live renderer shows; `AST.Acc` is not touched.
3. **Section-level fix-ups in both modes**, as in the LaTeX exporter: a
   document that starts at `##` gets proper levels, and hand-typed numbers
   like `# 1. Intro` are stripped, so `WithSectionNumbers` never shows
   `1. 1. Intro`.
4. **`WithSectionNumbers` numbers all levels.** The app's `numberToLevel`
   depth limit isn't carried over.
5. **Duplicate headings get unique ids** (`-2`, `-3`, …) so TOC links land
   correctly.
6. **Version bump to 2.2.0**, since new API is exposed.
7. **No commits** until the user has tested the change.

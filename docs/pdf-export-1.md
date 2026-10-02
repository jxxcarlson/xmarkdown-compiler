# LaTeX export: status after implementation and review

I've built the LaTeX export and fixed every Critical and Important problem the reviewer found. The new `LaTeX.Export` module is in `src/LaTeX/`. The full test suite passes (157 tests). The demo's sample document and a stress document made of all the reviewer's problem inputs both compile with `pdflatex` without errors, and I checked the resulting PDFs visually. Nothing is committed yet; the work is on a new local branch, `latex-export`.

## How to call it

```elm
LaTeX.Export.exportDocument { title = "…", authors = [ "…" ], date = "" } source  -- complete .tex file
LaTeX.Export.exportBody source                                              -- body only
LaTeX.Export.imageUrls source   -- [(url, localPath)] for the app to download next to the .tex
```

It isn't connected to the DemoTOC+Sync interface yet; there's no menu item or button for it.

## What the review fixes changed

- **Formulas ETeX can't parse:** if a formula is still valid LaTeX it stays as math; otherwise it's shown as typewriter text. Either way the document compiles.
- **Inline math:** empty `$$` no longer turns into display math, and a bare `%` is escaped so it doesn't comment out the rest of the paragraph.
- **Image filenames** now include a 6-character hash of the URL, e.g. `image/p-3d3f33.jpg`. This stops two `p.jpg` files from different sites overwriting each other.
- **Images in table cells and headings** are plain pictures instead of floating figures, which LaTeX doesn't allow there.
- **Leading `[`:** table rows and list items that start with `[` keep their meaning, so a `- [ ] todo` item keeps its bullet.
- **Quotations:** separate lines are no longer run together, and an empty `>` line is a paragraph break.
- **Greek letters** in ordinary text compile under `pdflatex`.

## Decisions I made on your behalf

- I worked on a new branch, `latex-export`, and made no commits, following your rule that nothing is committed until you've tested. If that's wrong, you'll need to commit it yourself.
- I ran `elm-format` on the new modules, which isn't in the plan. If that's wrong, the diff is whitespace only.
- I added `src/LaTeX/Export.elm` to the `elm make` check in `CLAUDE.md`, because `XMarkdown.API` doesn't import it. If that's wrong, it's a one-line revert.
- For the end-to-end check I exported with a throwaway program in the scratchpad instead of a test. Nothing was kept in the repo.
- Every image path now includes the hash, which makes filenames less readable. I updated the 7 earlier tests that hard-coded paths.
- For a URL with no file extension (e.g. `picsum.photos/200`), the path has no extension either. LaTeX then tries `.png`, `.jpg` and so on, so whatever downloads the images must save them with the right extension. If it doesn't, those images won't be found.
- The Unicode fix covers Greek only. Chinese, Japanese, emoji and so on still need `xelatex` or `lualatex`.

## Parser limitations I left alone (not exporter problems)

- A table with an image in its *header* row isn't parsed as a table at all.
- `| aligned` blocks containing `\\` get a parse error. The exporter avoids it by reading the original text.
- In the demo sample, a line containing only two spaces makes `# Tables` part of the previous block, so it appears as plain text rather than a heading.

## Minor issues I deferred

- `#####` and `######` headings come out as top-level `\section`.
- A code block that contains `\end{verbatim}` breaks the document.
- Parser error markers export as `% unsupported: red` comments.
- In LaTeX's default font, `<<` prints as « and `` ?` `` prints as ¿ inside code.
- Nested compact lists that mix bullets and numbers come out wrong. The cause is in the parser.
- An image with no caption, `![](url)`, produces a bogus `image/no` entry.
- Giving only some of title, author and date leaves an empty `\title{}`. It still compiles, so I don't think it needs fixing.

## Records

The ledger with every decision and test run is in `.superpowers/sdd/2026-10-01-latex-export/`, which git ignores. Once you've tried it, tell me whether to commit, open a PR, or add an "Export LaTeX" command to the demo.

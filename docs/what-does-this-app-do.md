# What does this app do?

This isn't an app on its own. It's an **Elm package** (`jxxcarlson/xmarkdown-compiler`, v2.0.3) that compiles **XMarkdown** source text into elm-ui HTML. The repo also holds demo apps that use it.

**XMarkdown** is Markdown with additions aimed at scientific writing:

- **Math:** display math goes in `$$ … $$` blocks, where each `$$` must be on its own line. The math can be written in standard TeX (`\frac{1}{n+1}`) or in ETeX, a simpler form (`frac(1,n+1)`). Rendering uses the `jxxcarlson/etex` package.
- **The usual Markdown:** bold, italic, lists, links and so on, plus tables (including GFM-style tables) and better image handling.
- **Automatic section numbering** and a live, auto-generated table of contents.
- **Two-way sync between source and rendered text:** clicking rendered text highlights the matching source and scrolls to it, and selecting source text does the same in the rendered view. Recent commits have been refining this down to individual words.

## How the code is organised

There is one folder per pipeline stage:

- `Parser/`: turns source text into an AST, with block-level and inline parsers.
- `AST/`: the data model and the passes that run after parsing.
- `Render/`: turns the AST into HTML.
- `XMarkdown/`: the public API and the driver (`XMarkdown.Compiler`).

## Other things in the repo

- `DemoTOC/` and `DemoTOC+Sync/`: demo apps showing the table of contents and the sync feature.
- `CLI/` and `Benchmark/`.
- An online demo at https://xmarkdowndemo.netlify.app/

## Note

One small mismatch: `CLAUDE.md` says the package exposes `XMarkdown.API` and `XMarkdown.Types`, but `elm.json` also exposes `Render.Theme`.

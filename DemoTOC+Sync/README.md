# DemoTOC+Sync — XMarkdown TOC Demo

A small three-panel demo app for the standalone **XMarkdown** compiler:

```
┌─────────────┬──────────────────┬───────────────┐
│ Source text │  Rendered Text   │ Table of      │
│ (editable)  │  (live elm-ui)   │ Contents      │
└─────────────┴──────────────────┴───────────────┘
```

It is the single-language analogue of `DemoTOC`: where `DemoTOC` offered a
language switcher (L0 / MicroLaTeX / XMarkdown), this app renders **XMarkdown
only** (`ScriptaV2.Language.SMarkdownLang`), which is the only language the
extracted compiler supports.

## How it works

- `src/Main.elm` — a `Browser.element` app. It compiles the source text with
  `ScriptaV2.Compiler.compile` and lays out the resulting `body` and `toc` with
  `mdgriffith/elm-ui`. Clicking a TOC section toggles open/closed nodes via the
  `ScriptaV2.Msg.ToggleTOCNodeID` message.
- `src/Data/XMarkdown.elm` — the initial sample document (headings, lists,
  links, an image, inline/display math, and a code block).
- The compiler itself is pulled in through `elm.json`'s
  `source-directories: ["src", "../src"]` — i.e. the package source one level up.
- `assets/katex.js` defines the `math-text` custom element and loads KaTeX +
  mhchem from a CDN so `$...$` / `$$...$$` math renders in the browser.

## Run it

```bash
cd DemoTOC+Sync
./run.sh        # starts `elm-watch hot` + serve.py on :8200, opens http://localhost:8200/index.html
```

`assets/editor.js` is an ES module (it imports CodeMirror from a CDN), and
browsers **refuse to load ES modules over `file://`**. So the app must be served
over HTTP — do **not** open `assets/index.html` as a file (you'll get a white
screen and a "Module source URI is not allowed" / "CORS request not http"
console error).

Or manually:

```bash
npx elm-watch hot                              # writes assets/main.js with hot reload
python3 serve.py 8200                          # serve assets/ over HTTP (any port works)
# then open http://localhost:8200/index.html
```

## File > Export PDF

Exports the current document to LaTeX (`LaTeX.Export` in `../src/LaTeX/`) and
downloads it as a PDF. The browser can't run pdflatex, so `serve.py` does it:
`POST /export-pdf` downloads the document's images into a temporary folder,
runs `pdflatex`, and returns the PDF. An image that can't be downloaded is
replaced by a framed "image not available" note. Needs `pdflatex` on the PATH
or in `/Library/TeX/texbin` (MacTeX), and the demo served by `serve.py`
(`./run.sh`), not by `python3 -m http.server`. Errors appear in the header;
the full pdflatex log goes to the browser console.

Server tests: `python3 -m unittest test_serve`

The generated `assets/main.js` and `elm-stuff/` are git-ignored; the committed
`assets/index.html` is the real entry point.

## Build check

```bash
elm make src/Main.elm --output=assets/main.js
```

Expected: `Success!`.

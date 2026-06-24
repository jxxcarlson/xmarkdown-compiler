# DemoTOCMd — XMarkdown TOC Demo

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
cd DemoTOCMd
./run.sh        # kills elm-watch's port, starts `elm-watch hot`, opens index.html
```

Or manually:

```bash
npx elm-watch hot          # serves assets/main.js with hot reload
open assets/index.html     # in a browser
```

The generated `assets/main.js` and `elm-stuff/` are git-ignored; the committed
`assets/index.html` is the real entry point.

## Build check

```bash
elm make src/Main.elm --output=assets/main.js
```

Expected: `Success!`.

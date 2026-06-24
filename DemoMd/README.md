# DemoMd — XMarkdown file-reader demo

A minimal Elm app: click a button, pick a `.md` file, and the XMarkdown
(SMarkdown) compiler renders it to the screen.

It compiles against the in-repo compiler via `../src` (see `elm.json`
`source-directories`), using `ScriptaV2.APISimple.compile` with
`ScriptaV2.Language.SMarkdownLang`. When the standalone `xmarkdown`
package is extracted, this app works unchanged (same API, same language).

## Run

```bash
cd DemoMd
npx elm-watch hot          # hot-reloading dev server
# then open assets/index.html in a browser
```

Or build once and open the file:

```bash
elm make src/Main.elm --output=assets/main.js
open assets/index.html
```

Math requires KaTeX, which `assets/index.html` loads (`assets/katex.js` +
the KaTeX CDN). Without it, `$...$`/`$$...$$` won't render.

# Changelog

## Unreleased (2.2.0): export a standalone HTML page — 2026-10-29

New `HTML.Export.toTextHtml : TOC -> SectionNumbers -> AST -> String` turns a
parsed document into a complete web page (`<!doctype html>` … `</html>`) that
any browser displays. Math is typeset by KaTeX 0.16.9 (with mhchem) from the
jsDelivr CDN. `type TOC = WithTOC | WithoutTOC` adds a table of contents;
`type SectionNumbers = WithSectionNumbers | WithoutSectionNumbers` numbers the
headings. Apps get the `AST` from the new `XMarkdown.API.parse : String -> AST`
(opaque). The page uses plain semantic HTML with `xm-*` classes and a small
default stylesheet (`<style id="xm-default-style">`), so it can be restyled.
As in the LaTeX export, a document starting at `##` is renumbered from 1 and
hand-typed heading numbers are dropped. No equation or figure numbers.
Design: `docs/superpowers/specs/2026-10-29-html-export-design.md`.

## Demo app: buttons stopped responding after clicking the rendered text — 2026-10-16

After clicking a word in the rendered text, every later click (toolbar
buttons, menus, the rendered text) did nothing until the selection moved.
`editor.js`'s mouseup handler maps a click on a word to its source and then
swallows the following click, so Elm doesn't also highlight the whole block;
but it looked only at the document selection, not where the mouse was. A
button click leaves the selection on the last word, so each click was taken
for a click on that word and swallowed. The handler now acts only on a mouseup
inside `.rendered-panel`.

## Demo app: wider Recent menu — 2026-10-16

The Recent menu is 40% wider (357px instead of 255px), and titles and file
names are shortened at 34 characters instead of 24, so more of a long title
shows.

## Demo app: Escape removes the highlight — 2026-10-16

Escape now also un-highlights the rendered text, whether the highlight came
from clicking it (`selectId`) or from a left-to-right sync (the injected CSS
rule). Before, Escape did anything only while a menu, dialog or the print
message was open.

## Demo app: Normalize strips escaped section numbers — 2026-10-16

File > Normalize now also removes section numbers whose dot is escaped, as
Markdown exporters write them: `# 3\. MORE TEXT` and `## 7\. MORE TEXT`
become `# MORE TEXT` and `## MORE TEXT` (`Normalize.numberedHeading`).

## Desktop app: Recent menu — 2026-10-16

A **Recent ▾** menu next to File lists the last 10 documents opened or
created, most recent first; choosing one opens it. Each item shows the
document's title (its `%title` line), or its file name if it has none, and its
folder, on one line, with the full path as the tooltip. The menu is 50% wider
than File (255px); a long title or name is shortened in the middle, keeping
its end and extension (`smartEllipsis`, 24 characters), and a long folder
name at its end. A file that has since been moved or deleted is reported and
dropped from the list.

- **Page** (`DemoTOC+Sync/assets/desktop.js`): the list lives in localStorage
  (`xmarkdown.recentFiles`, as `[{ path, title? }]`; the older
  `xmarkdown.lastFile` seeds it) and is sent to Elm as `recent { files }`. A
  file counts when it becomes the current document (`opened`, `created`,
  `savedAs`), not on `saved`, which can be the auto-save of the document just
  left; a save only updates its title. New op `openRecent { path }`. Startup
  reopens the top of the list.
- **Elm** (`DemoTOC+Sync/src/Main.elm`): `fileMenuOpen : Bool` became
  `openMenu : Maybe Menu` (`FileMenu | RecentMenu`); new `recentMenu` view and
  `smartEllipsis`.

## Desktop app: open .md files from the Finder — 2026-10-16

XMarkdown is registered as an editor for Markdown files (`.md`, `.markdown`),
so it appears under Open With, can be made the default app, and opens the file
it is given: both when that starts the app and when it is already running.
Before, a file passed this way was ignored and the last file was reopened.

- **Config:** `bundle.fileAssociations` in `desktop/src-tauri/tauri.conf.json`
  (XMarkdownNetlifyDemo), using macOS's own Markdown type,
  `net.daringfireball.markdown`.
- **Rust** (`desktop/src-tauri/src/lib.rs`): handles `RunEvent::Opened`. A
  file that arrives before the page has loaded is kept until the page asks for
  it (`take_opened_file`); later ones are sent as the `xm-open` event.
- **Page** (`DemoTOC+Sync/assets/desktop.js`): at startup, opens that file
  instead of the last one, and listens for `xm-open`.
- **Checked:** with `open -a`, which hands over a file as the Finder does, both
  with the app running and from a cold start.

## xmarkdown-compiler 2.1.6: `/begin NAME ... /end NAME` blocks and verse — 2026-10-13

### `/begin NAME ... /end NAME`

A line `/begin NAME` opens a block named NAME. Every line up to the matching
`/end NAME` line belongs to it, blank lines included. Both delimiter lines
must stand alone on their lines.

- **Before the block:** `/begin` must start a block, i.e. come at the start of
  the document or after a blank line.
- **After the block:** the line after `/end NAME` starts a new block; no blank
  line is needed.
- **No `/end`:** the block runs to the end of the document.
- **Wrong name:** `/end poem` doesn't close `/begin verse`; it's an ordinary
  line of the verse.
- **No name:** `/begin` on its own is an error.
- **Other names:** any name works (`/begin theorem`). Names without a renderer
  of their own use the generic block renderer.

### Verse

```
/begin verse
Roses are *red*,
    violets are **blue**.

Sugar is sweet
/end verse
```

- **Lines:** each source line is a line of the poem. Leading spaces indent it
  (one space = 1ch in HTML, half an em in LaTeX).
- **Blank lines:** kept, however many there are.
- **Markup:** italic, bold and the rest of the inline markup work, but cannot
  run across a line break, as in quotations.
- **LaTeX:** a `verse` environment. A blank line starts a new stanza, and each
  further blank line adds a line of space.
- **Editor sync:** source positions inside the verse are exact, so clicking
  rendered text finds it in the source.

### How it works

- **Block chunking** (`Parser.Block.PrimitiveBlock`): a `/begin` line opens a
  block, and until `/end` every line is added to it instead of the usual
  blank-line-ends-block rule. The block's source text covers both delimiter
  lines.
- **Inline parsing** (`Parser.Block.Pipeline.parseVerseLines`): one
  `ExprList indent exprs` per line. The leading spaces are removed before
  parsing because the inline parser doesn't keep runs of spaces.
- **HTML:** `Render.Blocks.Text.verse`.
- **LaTeX:** `LaTeX.Block.verse`.

### Checked

- **Tests:** 12 new, in `tests/VerseTest.elm`; 237 passing in all.
- **LaTeX:** an exported verse compiles under LuaLaTeX with no errors.
- **Browser:** DemoTOC+Sync shows the rendering correctly in headless Chrome.

## Desktop app: File > Make header — 2026-10-11

The new last item in the File menu, **Make header**, puts a standard header at
the top of the document, followed by a blank line:

```
%title
%author
%date October 11, 2026
%type
%subject
%source notes.md
```

- **Date:** today's local date, from `Date.today` (`justinmimbs/date`, already
  a dependency of the demo).
- **Source:** the document's file name.
- **Already has a header:** if the first non-blank line is a `%key` line, the
  app says "The document already has a header." and changes nothing.
- **Saving:** it counts as an edit, so a desktop document that already has a
  file is auto-saved; otherwise use Save.
- **Editor:** it reloads with the new text, so the cursor goes back to the top.

Files: `DemoTOC+Sync/src/Main.elm` (`header`, `hasHeader`, the menu item and
the command).

## Desktop app: ⌘O for Open — 2026-10-11

⌘O runs File > Open, and the menu shows "⌘O" next to "Open…". Like ⌘N, it is
desktop only. It is ignored while a dialog or the print message is showing,
and the webview is kept from acting on it too.

Files: `DemoTOC+Sync/src/Main.elm` (`keyDecoder`, `fileMenu`),
`DemoTOC+Sync/assets/desktop.js`; in XMarkdownNetlifyDemo, `docs/desktop.md`.

## Desktop app: Normalize spaces out display math — 2026-10-11

File > Normalize now also puts a blank line before and after display math
written as `\[ ... \]`, whether it takes several lines or one. No blank line
is added at the start or end of the document, or where there already is one.

- **Inside math:** lines between `\[` and `\]` are not changed, so a line
  starting with `#` there isn't treated as a heading.
- **Code fences:** a `\[` inside a code fence is left alone.
- **Message:** when there's nothing to change, it now says "Nothing to
  normalize."
- **Code:** `DemoTOC+Sync/src/Normalize.elm` (`Normalize.headings` is now
  `Normalize.normalize`).

## Desktop app: File > Normalize — 2026-10-11

Changes to the demo app (DemoTOC+Sync, synced to XMarkdownNetlifyDemo). No
compiler release.

The new last item in the File menu, **Normalize**, removes hand-written
numbers from the headings in the source and saves the file:

- `# 1. Intro` → `# Intro`
- `## 2.1 blah blah` → `## blah blah`
- `### 2.1.3. Deep` → `### Deep`

Details:

- **What counts as a number:** the number must contain a dot, so
  `# 2024 Results` is left alone.
- **What isn't touched:** headings inside code fences, and lines that aren't
  headings.
- **Saving:** works like Save. A document with no file opens the save dialog;
  the web version downloads the file.
- **Nothing to change:** the app says "No numbered headings to normalize."
  and doesn't save.
- **Editor:** it reloads with the new text, so the cursor goes back to the top.

Files: `DemoTOC+Sync/src/Normalize.elm` (new: the heading rewrite) and
`DemoTOC+Sync/src/Main.elm` (the menu item and the command).

## Desktop app: keyboard shortcuts and File > New — 2026-10-11

Changes to the demo app (DemoTOC+Sync, synced to XMarkdownNetlifyDemo). No
compiler release.

### Keyboard shortcuts

| Key | Does | Shown |
|---|---|---|
| ⌘N | File > New | next to "New…" in the File menu (desktop only) |
| ⌘P | File > Print | next to "Print" |
| ⌘E | Open/Close Editor | when you hover over the editor button |

- **Save As** has no shortcut. ⌘S still triggers left-to-right sync in the
  editor.
- **When shortcuts are ignored:** while a dialog or the print message is
  showing, and when the key is held down.
- **The web version** only gets ⌘E. Browsers don't let a page take over ⌘N,
  and Print is desktop-only.

### File > New

On the desktop, New opens the macOS save dialog, starting at `untitled.md` in
the current folder. The empty file is created wherever you save it, and the
dialog asks before replacing an existing file. This replaces the old name
prompt, which always created the file in the current folder.

### Checked

In headless Chrome, with a fake of the Tauri file and dialog functions:

- ⌘E works on web and desktop, including with the cursor in the editor.
- ⌘N goes through the save dialog, creates the file and loads it.
- ⌘P generates the PDF and then prints.
- The menu labels appear only where they should, and Escape still closes the
  menu.

Not covered by that check: whether the real app's own menu or webview catches
⌘N or ⌘P first.

### Files

- `DemoTOC+Sync/src/Main.elm`: shortcuts (`keyDecoder`), menu labels and the
  new New flow.
- `DemoTOC+Sync/assets/desktop.js`: the `new` request (save dialog; replaces
  `create`), and stopping the webview's own ⌘N/⌘P/⌘E.
- `DemoTOC+Sync/assets/style.css`: the shortcut labels.
- XMarkdownNetlifyDemo: the synced copies, plus `docs/desktop.md` updated for
  New and the shortcuts.

## xmarkdown-compiler 2.1.5 — 2026-10-10

Requires `jxxcarlson/etex` 1.0.8. The ETeX releases below are what make math
like `O(\|\delta\|^4)` work; this release adds LaTeX export support for the
new commands.

| Release | What changed |
|---|---|
| ETeX 1.0.6 | `ldots`, `cdots`, `vdots`, `ddots` and `dots` (plus amsmath's `dotsb` … `dotso`) and about 240 more KaTeX commands; 20 names removed that KaTeX doesn't define (`sech`, `lcm`, `scr`, …), which showed as red errors. All 736 names are checked against KaTeX 0.16.9. |
| ETeX 1.0.7 | `\|` fixed: a backslash followed by any character that isn't a letter or digit (`\| \! \: \> \# \& \_`, …) passes through unchanged. Before, it was an ETeX error. |
| ETeX 1.0.8 | ETeX no longer silently drops the rest of a formula at the first character it can't parse: `x in [0,1) cup (2,3]` used to become `x \in [0,1`. |
| xmarkdown-compiler 2.1.5 | Uses ETeX 1.0.8, and the LaTeX/PDF export defines the new commands. |

### Details

**Unmatched parentheses (ETeX 1.0.8).** An unmatched `(` or `)` is now kept
as an ordinary symbol, as in TeX, so half-open intervals work. Anything else
ETeX can't parse becomes an `[ETeX error]`, which falls back to the source
text instead of disappearing. Whether a `(` is closed is decided by looking
ahead for a matching `)`. An earlier, unreleased version used backtracking,
which got exponentially slower with each unclosed parenthesis. The released
version handles 200 unclosed parentheses instantly.

**Commands ETeX deliberately doesn't treat as names.** Single letters and
ordinary words (`P`, `R`, `S`, `it`, `set`, `real`, `empty`, …), delimiter
sizes (`left`, `right`, `big`, …), colours, font sizes, TeX primitives and
HTML commands. Otherwise `P(A)` would become `\P(A)`, the ¶ sign. All of these
still work when written with a backslash.

**LaTeX export (2.1.5).**

- The preamble loads `mathtools` whenever there's math, and `braket`, `bm`,
  `esint` and `arydshln` only when the document uses them.
- The remaining commands get a `\providecommand` definition, again only when
  used: capital Greek, `argmax`, the colon relations, a few rare arrows.
- A few definitions are approximations, e.g. `\oiiint` prints as `\iiint`.
- A document using all 247 new commands was exported through xmarkdown's own
  export code and compiled under LuaLaTeX with no errors.

**Tests.** ETeX: 89 passing; xmarkdown: 225 passing. Three xmarkdown tests used
`a\:b` as an example of math ETeX rejects. ETeX now accepts it, so they use
`a"b` instead.

## xmarkdown-compiler 2.1.4 — 2026-10-09

Requires `jxxcarlson/etex` 1.0.5 (code identical to 1.0.4). A function call
nested inside another function's arguments is converted:
`o(frac(x,log x))` → `o(\frac{x}{\log x})`. Before, it came out as
`o(\frac(x,\log x))`. The same fix applies to `sqrt(frac(x,y))` →
`\sqrt{\frac{x}{y}}`.

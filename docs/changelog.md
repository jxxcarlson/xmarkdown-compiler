# Changelog

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

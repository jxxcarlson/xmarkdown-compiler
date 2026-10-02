# Title block: `%title` / `%author` / `%date`

Status: implemented (2026-10-01, branch latex-export)

## Example

```
%title Consistency and Models
%author ChatGPT
%date October 1, 2026
```

**Rendered (HTML):**

- "Consistency and Models": centered, font size 2em
- "ChatGPT": centered, font size 1.5em
- "October 1, 2026": centered, font size 1.5em
- 1.5em between lines, 3em below the last line

**LaTeX export:**

```latex
\title{Consistency and Models}
\author{ChatGPT}
\date{October 1, 2026}
```

## Decisions

| Question | Decision |
|---|---|
| Other `%` lines in the block (e.g. `%titel`, `% note to self`) | Hidden: treated as comments, not rendered, not exported |
| Multiple authors | Repeat `%author`, one author per line. HTML shows each on its own centered line; LaTeX gets `\author{A \and B}` |

## Design

**Syntax.** A block (lines with no blank line between them) whose first line starts with `%` is a title block. Its `%title`, `%author` (may repeat) and `%date` lines set the fields. Any other `%` line in it is a hidden comment. Only the first title block in a document counts. A later one renders nothing and exports nothing.

**Parser** (`Parser/Block/PrimitiveBlock.elm`, `getHeadingData`). A first line starting with `%` gives a new `Ordinary "titleBlock"` block. The existing `!!` → `"title"` block is not reused: it feeds a different header path (`Compiler.header`), which the demo doesn't use.

A new shared module, `AST.TitleBlock`, reads the fields from the block's source lines:

```elm
fromForest : Forest ExpressionBlock -> Maybe { title : String, authors : List String, date : String }
```

Both the renderer and the exporter use it, so they can't disagree.

**HTML** (`Render/`). The block renders where it appears, normally at the top:

- the title centered at 2em;
- each author and the date centered at 1.5em;
- 1.5em between lines, and 3em below the last line.

Missing fields are just left out. The block isn't numbered and doesn't appear in the table of contents (both are driven by `#` sections). It carries the block's id, so clicking it selects the source lines like any other block.

**LaTeX** (`LaTeX.Export`):

- The title block emits nothing in the body.
- `exportDocument` fills `\title{…}`, `\author{A \and B}` and `\date{…}` from it, escaped as usual, followed by `\maketitle`.
- If the caller passes a non-empty field in `DocumentInfo`, that field wins. Otherwise the source supplies it, so the demo's Export PDF (which passes empty fields) picks the title up automatically.
- `exportBody` ignores the title block.

## Tests

- **Parser:** the heading is `titleBlock`.
- **`AST.TitleBlock`:** the three keys, repeated authors, hidden unknown lines, extra spaces, fields missing, only the first block counts.
- **LaTeX:** the exact `\title`/`\author`/`\date` lines above, `\maketitle`, two authors joined by `\and`, nothing in the body, caller fields win.
- **Renderer:** if the test setup has `Test.Html`, check the centered elements and font sizes there; otherwise check visually in the demo.
- Then the full suite, plus a `pdflatex` compile of the example.

## Out of scope

- `%` comments outside the title block.
- Inline markup or math inside title, author and date (treated as plain text).

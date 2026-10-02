# XMarkdown → LaTeX Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Export XMarkdown source to LaTeX, either as a complete compilable document or as a body fragment.

**Architecture:** Parse with the existing `XMarkdown.Compiler.parseFromString` (source → `Forest ExpressionBlock`), then walk the forest in new `LaTeX.*` modules: `Escape` (text/URL escaping), `Image` (image text → figure + local path), `Inline` (expressions), `Block` (blocks and lists), `Preamble` (on-demand packages), and the public `Export`.

**Tech Stack:** Elm 0.19.x, `jxxcarlson/etex` (`ETeX.Transform.transformETeX`), `elmcraft/core-extra` (`List.Extra`), the rose-tree package already used as `RoseTree.Tree`, `elm-explorations/test`.

**Spec:** `docs/superpowers/specs/2026-10-01-latex-export-design.md`

## Global Constraints

- All new modules live under `src/LaTeX/` with names `LaTeX.*`.
- Only `LaTeX.Export` is public; add it to `exposed-modules` in `elm.json` (edit `exposed-modules` by hand — it is not a dependency, so `elm-json` does not apply).
- Do not change `XMarkdown.API` or any existing renderer module.
- Verification after every task (from `CLAUDE.md`):
  `elm make src/XMarkdown/API.elm src/XMarkdown/Types.elm src/Render/Theme.elm src/LaTeX/Export.elm --output=/dev/null && npx elm-test`
  (`src/LaTeX/Export.elm` is added to the command once it exists, in Task 3.)
- **Do not commit.** The user's standing rule: no commits until they have tested the change. Each task ends with verification, not a commit.
- Plain text escapes exactly: `\ # $ % & _ { } ~ ^`.
- ETeX failure is detected by the transform output starting with `[ETeX error]`.

## Spec adjustments discovered while planning

These are recorded here and applied to the spec in Task 6:

1. **Description lists are dropped.** The parser never produces `desc` or `descriptionList` blocks (no match in `src/Parser/`), so there is nothing to export. They fall through to the "unsupported" case.
2. **`chem` blocks are not ETeX-transformed.** `\ce{…}` content is mhchem syntax, not math; it is emitted verbatim inside `\ce{}`.
3. **Math blocks read `meta.sourceText`, not the parsed body.** `| aligned` bodies containing `\\` currently parse with a `tokenError` (an existing parser issue, out of scope). For `Ordinary` math blocks (`equation`, `aligned`, `array`, `chem`) the exporter uses `meta.sourceText` minus its first line. For `Verbatim "math"` it uses the `Left` body with the trailing `$$` removed.
4. **`array` needs a column spec.** Use `block.args` concatenated if non-empty (`| array c c` → `cc`), otherwise `c` repeated (number of `&` on the first row + 1). Emitted inside `\[ … \]`.
5. **`aligned` → `align*`** (unnumbered), `equation` → `equation` (numbered).

## AST facts the implementer needs

Probed with `elm repl` against the current parser:

| Source | Block heading | Body |
|---|---|---|
| `## Intro *x*` | `Ordinary "section"`, `properties` has `level = "2"` | `Right [Text " Intro ", Fun "italic" [Text "x"]]` |
| `Hello **b** *i* `` `c` `` $x$ [NYT](https://n.com)` | `Paragraph` | `Text`, `Fun "bold" […]`, `Fun "italic" […]`, `VFun "code" "c"`, `VFun "math" "x"`, `Fun "link" [Text "NYT https://n.com"]` (URL is the **last** word) |
| `- a\n- b` (compact) | `Ordinary "itemList"` | `Right [ExprList 0 [Text "a"], ExprList 0 [Text "b"]]`; nested items have larger indent (`ExprList 2 …`) |
| `. one\n. two` (compact) | `Ordinary "numberedList"` | same shape as `itemList` |
| `- a\n\n  - nested\n\n- b` (loose) | sibling trees with `Ordinary "item"`; nested items are tree **children** | `Right [Text "a"]` |
| `. one\n\n. two` (loose) | sibling trees with `Ordinary "numbered"` | `Right [Text "one"]` |
| GFM table | `Ordinary "table"`, `properties` has `alignments = "l,r"` | `Right [Fun "table" [Fun "row" [Fun "cell" […], …], …]]`, first row is the header, separator row already removed |
| `![European Robin width:400](https://x.com/a.jpg)` | `Paragraph` | `Right [Fun "image" [Text "https://x.com/a.jpg European Robin width:400"]]` (URL is the **first** word) |
| `> quote` | `Ordinary "quotation"` | `Right [Text "quote"]` |
| fenced code | `Verbatim "code"` | `Left "def f(n):\n  return 1"` |
| `$$\nx^2\n$$` and `\[\nx^2\n\]` | `Verbatim "math"` | `Left "x^2\n$$"` |
| `\| equation\nx^2` | `Ordinary "equation"` | `meta.sourceText = "\| equation\nx^2"` |

Helpers that already exist: `XMarkdown.Compiler.parseFromString : String -> Forest ExpressionBlock` (`AST.Forest.Forest a = List (Tree a)`), `Library.Tree.flatten : Tree a -> List a`, `RoseTree.Tree.value`, `RoseTree.Tree.children`, `List.Extra.span`, `List.Extra.getAt`, `List.Extra.unique`.

Known ETeX failure input (useful in tests): `a\:b` → `[ETeX error]a\:b`.

## Review Focus

1. **Special characters in ordinary prose** (`50% & #1`, `snake_case`, `~/path`): must be escaped, or pdflatex fails. Covered in Task 2.
2. **Remote image URLs with query strings / `%20`**: local path must be a safe filename and `imageUrls` must report the same path. Covered in Task 1 and Task 5.
3. **A formula the ETeX parser rejects**: the document must still compile. Covered in Task 2 (inline) and Task 3 (block).
4. **Nested lists, both compact and loose**: must produce nested environments, not flat items. Covered in Task 4.
5. **Empty document info** (no title/author/date): no `\maketitle`, otherwise LaTeX errors with "No \title given". Covered in Task 5.

---

### Task 1: `LaTeX.Escape` and `LaTeX.Image`

**Files:**
- Create: `src/LaTeX/Escape.elm`
- Create: `src/LaTeX/Image.elm`
- Test: `tests/LaTeXImageTest.elm`

**Interfaces:**
- Produces:
  - `LaTeX.Escape.text : String -> String`
  - `LaTeX.Escape.url : String -> String`
  - `type alias LaTeX.Image.Image = { url : String, caption : String, width : Maybe Int }`
  - `LaTeX.Image.fromText : String -> Image`
  - `LaTeX.Image.localPath : String -> String`
  - `LaTeX.Image.toLaTeX : Image -> String`

- [ ] **Step 1: Write the failing tests**

`tests/LaTeXImageTest.elm`:

```elm
module LaTeXImageTest exposing (suite)

import Expect
import LaTeX.Escape
import LaTeX.Image
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "LaTeX.Escape and LaTeX.Image"
        [ test "escapes every LaTeX special character" <|
            \_ ->
                LaTeX.Escape.text "\\ # $ % & _ { } ~ ^"
                    |> Expect.equal "\\textbackslash{} \\# \\$ \\% \\& \\_ \\{ \\} \\textasciitilde{} \\textasciicircum{}"
        , test "leaves ordinary text alone" <|
            \_ -> LaTeX.Escape.text "Hello, world." |> Expect.equal "Hello, world."
        , test "escapes % and # in URLs only" <|
            \_ ->
                LaTeX.Escape.url "https://x.com/a%20b#top_1"
                    |> Expect.equal "https://x.com/a\\%20b\\#top_1"
        , test "fromText: url first, caption, width property" <|
            \_ ->
                LaTeX.Image.fromText "https://x.com/a.jpg European Robin width:400"
                    |> Expect.equal { url = "https://x.com/a.jpg", caption = "European Robin", width = Just 400 }
        , test "fromText: colon words other than width/height stay in the caption" <|
            \_ ->
                LaTeX.Image.fromText "https://x.com/a.jpg Note: robin"
                    |> Expect.equal { url = "https://x.com/a.jpg", caption = "Note: robin", width = Nothing }
        , test "localPath: last segment, query and fragment dropped, unsafe chars replaced" <|
            \_ ->
                LaTeX.Image.localPath "https://x.com/a/b%20c.jpg?x=1#f"
                    |> Expect.equal "image/b-20c.jpg"
        , test "localPath: empty segment falls back to 'image'" <|
            \_ -> LaTeX.Image.localPath "https://x.com/" |> Expect.equal "image/image"
        , test "toLaTeX with caption: figure, width as fraction of 600px" <|
            \_ ->
                LaTeX.Image.toLaTeX { url = "https://x.com/a.jpg", caption = "A & B", width = Just 400 }
                    |> Expect.equal "\\begin{figure}[h]\n\\centering\n\\includegraphics[width=0.67\\textwidth]{image/a.jpg}\n\\caption{A \\& B}\n\\end{figure}"
        , test "toLaTeX without caption or width: centered, 0.75 textwidth" <|
            \_ ->
                LaTeX.Image.toLaTeX { url = "https://x.com/a.jpg", caption = "", width = Nothing }
                    |> Expect.equal "\\begin{center}\n\\includegraphics[width=0.75\\textwidth]{image/a.jpg}\n\\end{center}"
        , test "toLaTeX caps width at full textwidth" <|
            \_ ->
                LaTeX.Image.toLaTeX { url = "a.jpg", caption = "", width = Just 2000 }
                    |> String.contains "[width=1\\textwidth]"
                    |> Expect.equal True
        ]
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx elm-test tests/LaTeXImageTest.elm`
Expected: compile error, `I cannot find a \`LaTeX.Escape\` import`.

- [ ] **Step 3: Implement**

`src/LaTeX/Escape.elm`:

```elm
module LaTeX.Escape exposing (text, url)

{-| Escaping for text placed in a LaTeX document.
-}


{-| Escape the characters LaTeX treats specially in running text.
-}
text : String -> String
text str =
    str
        |> String.toList
        |> List.map escapeChar
        |> String.concat


escapeChar : Char -> String
escapeChar c =
    case c of
        '\\' ->
            "\\textbackslash{}"

        '#' ->
            "\\#"

        '$' ->
            "\\$"

        '%' ->
            "\\%"

        '&' ->
            "\\&"

        '_' ->
            "\\_"

        '{' ->
            "\\{"

        '}' ->
            "\\}"

        '~' ->
            "\\textasciitilde{}"

        '^' ->
            "\\textasciicircum{}"

        _ ->
            String.fromChar c


{-| Escape a URL for the first argument of hyperref's \\href.
Only % and # need it there.
-}
url : String -> String
url str =
    str
        |> String.replace "%" "\\%"
        |> String.replace "#" "\\#"
```

`src/LaTeX/Image.elm`:

```elm
module LaTeX.Image exposing (Image, fromText, localPath, toLaTeX)

{-| Images: the text of an XMarkdown image element ("url caption width:400")
to a LaTeX figure. Remote URLs can't be loaded by \\includegraphics, so the
figure points at a local file derived from the URL (see `localPath`); the app
downloads the files using `LaTeX.Export.imageUrls`.
-}

import LaTeX.Escape


type alias Image =
    { url : String, caption : String, width : Maybe Int }


{-| The URL is the first word; `width:N` / `height:N` words are properties;
the remaining words are the caption.
-}
fromText : String -> Image
fromText str =
    case String.words str of
        [] ->
            { url = "", caption = "", width = Nothing }

        url :: rest ->
            let
                isProperty word =
                    String.startsWith "width:" word || String.startsWith "height:" word

                ( properties, captionWords ) =
                    List.partition isProperty rest

                width =
                    properties
                        |> List.filterMap
                            (\p ->
                                if String.startsWith "width:" p then
                                    String.toInt (String.dropLeft 6 p)

                                else
                                    Nothing
                            )
                        |> List.head
            in
            { url = url, caption = String.join " " captionWords, width = width }


{-| "https://x.com/a/b%20c.jpg?x=1" -> "image/b-20c.jpg"
-}
localPath : String -> String
localPath url =
    let
        before sep s =
            String.split sep s |> List.head |> Maybe.withDefault s

        safe c =
            if Char.isAlphaNum c || c == '.' || c == '_' || c == '-' then
                c

            else
                '-'

        name =
            url
                |> before "?"
                |> before "#"
                |> String.split "/"
                |> List.reverse
                |> List.head
                |> Maybe.withDefault ""
                |> String.map safe
    in
    "image/"
        ++ (if name == "" then
                "image"

            else
                name
           )


toLaTeX : Image -> String
toLaTeX image =
    let
        graphic =
            "\\includegraphics[width=" ++ widthSpec image.width ++ "]{" ++ localPath image.url ++ "}"
    in
    if image.caption == "" then
        "\\begin{center}\n" ++ graphic ++ "\n\\end{center}"

    else
        "\\begin{figure}[h]\n\\centering\n"
            ++ graphic
            ++ "\n\\caption{"
            ++ LaTeX.Escape.text image.caption
            ++ "}\n\\end{figure}"


{-| Pixel width as a fraction of \\textwidth, taking 600px as the full width.
-}
widthSpec : Maybe Int -> String
widthSpec width =
    case width of
        Nothing ->
            "0.75\\textwidth"

        Just px ->
            let
                fraction =
                    min 1 (toFloat px / 600)
            in
            String.fromFloat (toFloat (round (fraction * 100)) / 100) ++ "\\textwidth"
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx elm-test tests/LaTeXImageTest.elm`
Expected: all 10 tests PASS.

- [ ] **Step 5: Full verification**

Run: `elm make src/XMarkdown/API.elm src/XMarkdown/Types.elm src/Render/Theme.elm src/LaTeX/Image.elm --output=/dev/null && npx elm-test`
Expected: `Success!` and all tests pass. Do not commit.

---

### Task 2: `LaTeX.Inline`

**Files:**
- Create: `src/LaTeX/Inline.elm`
- Test: `tests/LaTeXInlineTest.elm`

**Interfaces:**
- Consumes: `LaTeX.Escape.text`, `LaTeX.Escape.url`, `LaTeX.Image.fromText`, `LaTeX.Image.toLaTeX` (Task 1).
- Produces:
  - `LaTeX.Inline.exportExprs : List Expression -> String`
  - `LaTeX.Inline.math : String -> String -> String -> String` — `math open close source`: ETeX → LaTeX wrapped in `open`/`close`; on ETeX failure, `"% ETeX error\n" ++ open ++ trimmed source ++ close`.
  - `LaTeX.Inline.plainText : List Expression -> String` — concatenation of the `Text` strings, trimmed.

- [ ] **Step 1: Write the failing tests**

`tests/LaTeXInlineTest.elm`:

```elm
module LaTeXInlineTest exposing (suite)

import AST.Language exposing (Expr(..), Expression, emptyExprMeta)
import Expect
import LaTeX.Inline
import Test exposing (Test, describe, test)


t : String -> Expression
t s =
    Text s emptyExprMeta


f : String -> List Expression -> Expression
f name args =
    Fun name args emptyExprMeta


v : String -> String -> Expression
v name content =
    VFun name content emptyExprMeta


suite : Test
suite =
    describe "LaTeX.Inline"
        [ test "plain text is escaped" <|
            \_ -> LaTeX.Inline.exportExprs [ t "50% & #1" ] |> Expect.equal "50\\% \\& \\#1"
        , test "bold and italic, nested" <|
            \_ ->
                LaTeX.Inline.exportExprs [ f "bold" [ t "a ", f "italic" [ t "b" ] ] ]
                    |> Expect.equal "\\textbf{a \\emph{b}}"
        , test "inline code is escaped inside texttt" <|
            \_ -> LaTeX.Inline.exportExprs [ v "code" "co_de" ] |> Expect.equal "\\texttt{co\\_de}"
        , test "inline math goes through ETeX" <|
            \_ -> LaTeX.Inline.exportExprs [ v "math" "frac(1,2)" ] |> Expect.equal "$\\frac{1}{2}$"
        , test "inline TeX math is kept" <|
            \_ -> LaTeX.Inline.exportExprs [ v "math" "x^2" ] |> Expect.equal "$x^2$"
        , test "inline math the ETeX parser rejects falls back to the source" <|
            \_ ->
                LaTeX.Inline.exportExprs [ v "math" "a\\:b" ]
                    |> Expect.equal "% ETeX error\n$a\\:b$"
        , test "link: last word is the URL" <|
            \_ ->
                LaTeX.Inline.exportExprs [ f "link" [ t "New York Times https://nytimes.com/a#b" ] ]
                    |> Expect.equal "\\href{https://nytimes.com/a\\#b}{New York Times}"
        , test "image becomes a figure" <|
            \_ ->
                LaTeX.Inline.exportExprs [ f "image" [ t "https://x.com/a.jpg Robin" ] ]
                    |> String.startsWith "\\begin{figure}"
                    |> Expect.equal True
        , test "unknown function: comment plus its contents" <|
            \_ ->
                LaTeX.Inline.exportExprs [ f "red" [ t "x" ] ]
                    |> Expect.equal "% unsupported: red\nx"
        , test "plainText concatenates Text and trims" <|
            \_ -> LaTeX.Inline.plainText [ t " a ", f "bold" [ t "ignored" ], t "b " ] |> Expect.equal "a b"
        ]
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx elm-test tests/LaTeXInlineTest.elm`
Expected: compile error, cannot find `LaTeX.Inline`.

- [ ] **Step 3: Implement**

`src/LaTeX/Inline.elm`:

```elm
module LaTeX.Inline exposing (exportExprs, math, plainText)

{-| Inline XMarkdown expressions to LaTeX.
-}

import AST.Language exposing (Expr(..), Expression)
import Dict
import ETeX.Transform
import LaTeX.Escape
import LaTeX.Image


exportExprs : List Expression -> String
exportExprs exprs =
    exprs |> List.map exportExpr |> String.concat


exportExpr : Expression -> String
exportExpr expr =
    case expr of
        Text str _ ->
            LaTeX.Escape.text str

        Fun name args _ ->
            fun name args

        VFun name content _ ->
            vfun name content

        ExprList _ exprs _ ->
            exportExprs exprs


fun : String -> List Expression -> String
fun name args =
    if List.member name [ "bold", "b", "strong" ] then
        "\\textbf{" ++ exportExprs args ++ "}"

    else if List.member name [ "italic", "i", "em" ] then
        "\\emph{" ++ exportExprs args ++ "}"

    else if name == "link" || name == "a" then
        link (plainText args)

    else if name == "image" || name == "img" then
        LaTeX.Image.toLaTeX (LaTeX.Image.fromText (plainText args))

    else
        unsupported name (exportExprs args)


vfun : String -> String -> String
vfun name content =
    if name == "math" || name == "m" then
        math "$" "$" content

    else if name == "chem" then
        "\\ce{" ++ content ++ "}"

    else if name == "code" then
        "\\texttt{" ++ LaTeX.Escape.text content ++ "}"

    else
        unsupported name (LaTeX.Escape.text content)


{-| The parser gives a link as one Text: "label words url".
-}
link : String -> String
link str =
    case List.reverse (String.words str) of
        [] ->
            ""

        url :: labelWords ->
            "\\href{"
                ++ LaTeX.Escape.url url
                ++ "}{"
                ++ LaTeX.Escape.text (String.join " " (List.reverse labelWords))
                ++ "}"


{-| ETeX -> LaTeX, wrapped in `open` and `close`. If the ETeX parser rejects
the input, emit the original source behind a comment, so one bad formula
doesn't stop the document from compiling.
-}
math : String -> String -> String -> String
math open close source =
    let
        trimmed =
            String.trim source

        latex =
            ETeX.Transform.transformETeX Dict.empty trimmed
    in
    if String.startsWith "[ETeX error]" latex then
        "% ETeX error\n" ++ open ++ trimmed ++ close

    else
        open ++ latex ++ close


plainText : List Expression -> String
plainText exprs =
    exprs
        |> List.map
            (\expr ->
                case expr of
                    Text str _ ->
                        str

                    _ ->
                        ""
            )
        |> String.concat
        |> String.trim


unsupported : String -> String -> String
unsupported name body =
    "% unsupported: " ++ name ++ "\n" ++ body
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx elm-test tests/LaTeXInlineTest.elm`
Expected: all 10 tests PASS. If "inline math goes through ETeX" fails, run the input through `elm repl` (`ETeX.Transform.transformETeX Dict.empty "frac(1,2)"`) and set the expected string to the actual ETeX output only if it is valid LaTeX for ½.

- [ ] **Step 5: Full verification**

Run: `elm make src/XMarkdown/API.elm src/XMarkdown/Types.elm src/Render/Theme.elm src/LaTeX/Inline.elm --output=/dev/null && npx elm-test`
Expected: success. Do not commit.

---

### Task 3: `LaTeX.Block` (non-list blocks) and `LaTeX.Export.exportBody`

**Files:**
- Create: `src/LaTeX/Block.elm`
- Create: `src/LaTeX/Export.elm` (only `exportBody` for now)
- Test: `tests/LaTeXBlockTest.elm`

**Interfaces:**
- Consumes: `LaTeX.Inline.exportExprs`, `LaTeX.Inline.math`, `LaTeX.Escape.text`; `XMarkdown.Compiler.parseFromString`.
- Produces:
  - `LaTeX.Block.exportForest : Forest ExpressionBlock -> String` — blocks separated by one blank line.
  - `LaTeX.Export.exportBody : String -> String`

- [ ] **Step 1: Write the failing tests**

`tests/LaTeXBlockTest.elm`:

```elm
module LaTeXBlockTest exposing (suite)

import Expect
import LaTeX.Export exposing (exportBody)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "LaTeX.Block via exportBody"
        [ test "headings map to section levels" <|
            \_ ->
                exportBody "# One\n\n## Two\n\n### Three\n\n#### Four"
                    |> Expect.equal "\\section{One}\n\n\\subsection{Two}\n\n\\subsubsection{Three}\n\n\\paragraph{Four}"
        , test "heading with inline markup" <|
            \_ -> exportBody "## Intro *x*" |> Expect.equal "\\subsection{Intro \\emph{x}}"
        , test "paragraphs separated by a blank line, text escaped" <|
            \_ ->
                exportBody "Hello **world**.\n\n50% off"
                    |> Expect.equal "Hello \\textbf{world}.\n\n50\\% off"
        , test "quotation" <|
            \_ ->
                exportBody "> What we know is not much."
                    |> Expect.equal "\\begin{quote}\nWhat we know is not much.\n\\end{quote}"
        , test "code block is verbatim, not escaped" <|
            \_ ->
                exportBody "```\ndef f(n_1):\n  return 1\n```"
                    |> Expect.equal "\\begin{verbatim}\ndef f(n_1):\n  return 1\n\\end{verbatim}"
        , test "$$ display math, ETeX transformed" <|
            \_ ->
                exportBody "$$\nfrac(1,2)\n$$"
                    |> Expect.equal "\\[\n\\frac{1}{2}\n\\]"
        , test "\\[ display math is the same as $$" <|
            \_ ->
                exportBody "\\[\nx^2\n\\]"
                    |> Expect.equal "\\[\nx^2\n\\]"
        , test "display math the ETeX parser rejects falls back to the source" <|
            \_ ->
                exportBody "$$\na\\:b\n$$"
                    |> Expect.equal "% ETeX error\n\\[\na\\:b\n\\]"
        , test "equation block" <|
            \_ ->
                exportBody "| equation\nx^2"
                    |> Expect.equal "\\begin{equation}\nx^2\n\\end{equation}"
        , test "aligned block reads source text, so \\\\ survives" <|
            \_ ->
                exportBody "| aligned\na &= b \\\\\nc &= d"
                    |> String.contains "a &= b \\\\"
                    |> Expect.equal True
        , test "aligned block uses align*" <|
            \_ ->
                exportBody "| aligned\na &= b"
                    |> String.startsWith "\\begin{align*}\n"
                    |> Expect.equal True
        , test "array block: column spec from the first row" <|
            \_ ->
                exportBody "| array\n1 & 2"
                    |> String.contains "\\begin{array}{cc}"
                    |> Expect.equal True
        , test "chem block is not ETeX transformed" <|
            \_ ->
                exportBody "| chem\nH2O"
                    |> Expect.equal "\\[\n\\ce{H2O}\n\\]"
        , test "GFM table: tabular, alignment, bold header" <|
            \_ ->
                exportBody "| A | B |\n|:--|--:|\n| 1 | $x$ |"
                    |> Expect.equal "\\begin{center}\n\\begin{tabular}{lr}\n\\hline\n\\textbf{A} & \\textbf{B} \\\\\n\\hline\n1 & $x$ \\\\\n\\hline\n\\end{tabular}\n\\end{center}"
        , test "image paragraph becomes a figure" <|
            \_ ->
                exportBody "![Robin width:300](https://x.com/robin.jpg)"
                    |> Expect.equal "\\begin{figure}[h]\n\\centering\n\\includegraphics[width=0.5\\textwidth]{image/robin.jpg}\n\\caption{Robin}\n\\end{figure}"
        ]
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx elm-test tests/LaTeXBlockTest.elm`
Expected: compile error, cannot find `LaTeX.Export`.

- [ ] **Step 3: Implement `LaTeX.Block`**

`src/LaTeX/Block.elm`:

```elm
module LaTeX.Block exposing (exportForest)

{-| XMarkdown blocks to LaTeX.
-}

import AST.Forest exposing (Forest)
import AST.Language exposing (Expr(..), ExpressionBlock, Heading(..))
import Dict
import Either exposing (Either(..))
import LaTeX.Escape
import LaTeX.Inline
import List.Extra
import RoseTree.Tree as Tree exposing (Tree)


exportForest : Forest ExpressionBlock -> String
exportForest forest =
    forest
        |> List.map exportTree
        |> String.join "\n\n"


exportTree : Tree ExpressionBlock -> String
exportTree tree =
    case Tree.children tree of
        [] ->
            exportBlock (Tree.value tree)

        children ->
            exportBlock (Tree.value tree) ++ "\n\n" ++ exportForest children


exportBlock : ExpressionBlock -> String
exportBlock block =
    case block.heading of
        Paragraph ->
            inlineBody block

        Ordinary "section" ->
            section block

        Ordinary "quotation" ->
            environment "quote" (inlineBody block)

        Ordinary "table" ->
            table block

        Ordinary "equation" ->
            LaTeX.Inline.math "\\begin{equation}\n" "\n\\end{equation}" (mathSource block)

        Ordinary "aligned" ->
            LaTeX.Inline.math "\\begin{align*}\n" "\n\\end{align*}" (mathSource block)

        Ordinary "array" ->
            array block

        Ordinary "chem" ->
            "\\[\n\\ce{" ++ mathSource block ++ "}\n\\]"

        Verbatim "math" ->
            LaTeX.Inline.math "\\[\n" "\n\\]" (mathSource block)

        Verbatim "code" ->
            case block.body of
                Left str ->
                    environment "verbatim" str

                Right _ ->
                    environment "verbatim" ""

        Ordinary name ->
            unsupported name block

        Verbatim name ->
            unsupported name block


inlineBody : ExpressionBlock -> String
inlineBody block =
    case block.body of
        Right exprs ->
            LaTeX.Inline.exportExprs exprs

        Left str ->
            LaTeX.Escape.text str


section : ExpressionBlock -> String
section block =
    let
        command =
            case Dict.get "level" block.properties |> Maybe.andThen String.toInt of
                Just 2 ->
                    "subsection"

                Just 3 ->
                    "subsubsection"

                Just 4 ->
                    "paragraph"

                _ ->
                    "section"
    in
    "\\" ++ command ++ "{" ++ String.trim (inlineBody block) ++ "}"


{-| The math source of a math block. `$$` / `\[` blocks are Verbatim with the
closing `$$` still on the body. Ordinary blocks (`| equation` etc.) are read
from the source text, because their parsed body can contain token errors
(e.g. for `\\`).
-}
mathSource : ExpressionBlock -> String
mathSource block =
    case ( block.heading, block.body ) of
        ( Verbatim _, Left str ) ->
            str |> String.trim |> dropSuffix "$$" |> dropSuffix "\\]" |> String.trim

        _ ->
            block.meta.sourceText
                |> String.lines
                |> List.drop 1
                |> String.join "\n"
                |> String.trim


dropSuffix : String -> String -> String
dropSuffix suffix str =
    if String.endsWith suffix str then
        String.dropRight (String.length suffix) str

    else
        str


array : ExpressionBlock -> String
array block =
    let
        source =
            mathSource block

        columns =
            if List.isEmpty block.args then
                source
                    |> String.lines
                    |> List.head
                    |> Maybe.withDefault ""
                    |> String.indexes "&"
                    |> List.length
                    |> (\n -> String.repeat (n + 1) "c")

            else
                String.concat block.args
    in
    LaTeX.Inline.math ("\\[\n\\begin{array}{" ++ columns ++ "}\n") "\n\\end{array}\n\\]" source


table : ExpressionBlock -> String
table block =
    let
        rows =
            case block.body of
                Right [ Fun "table" rowExprs _ ] ->
                    List.filterMap row rowExprs

                _ ->
                    []

        row expr =
            case expr of
                Fun "row" cells _ ->
                    Just (List.map cell cells)

                _ ->
                    Nothing

        cell expr =
            case expr of
                Fun "cell" exprs _ ->
                    String.trim (LaTeX.Inline.exportExprs exprs)

                other ->
                    String.trim (LaTeX.Inline.exportExprs [ other ])

        alignments =
            Dict.get "alignments" block.properties
                |> Maybe.map (String.split ",")
                |> Maybe.withDefault []

        columnCount =
            rows |> List.map List.length |> List.maximum |> Maybe.withDefault 0

        alignment i =
            case List.Extra.getAt i alignments of
                Just a ->
                    if List.member a [ "l", "c", "r" ] then
                        a

                    else
                        "l"

                Nothing ->
                    "l"

        columnSpec =
            List.range 0 (columnCount - 1) |> List.map alignment |> String.concat

        line cells =
            String.join " & " cells ++ " \\\\"

        bold c =
            "\\textbf{" ++ c ++ "}"
    in
    case rows of
        [] ->
            ""

        header :: body ->
            environment "center"
                ("\\begin{tabular}{"
                    ++ columnSpec
                    ++ "}\n"
                    ++ String.join "\n"
                        ([ "\\hline", line (List.map bold header), "\\hline" ]
                            ++ List.map line body
                            ++ [ "\\hline" ]
                        )
                    ++ "\n\\end{tabular}"
                )


unsupported : String -> ExpressionBlock -> String
unsupported name block =
    "% unsupported: " ++ name ++ "\n" ++ inlineBody block


environment : String -> String -> String
environment name body =
    "\\begin{" ++ name ++ "}\n" ++ body ++ "\n\\end{" ++ name ++ "}"
```

- [ ] **Step 4: Implement `LaTeX.Export.exportBody`**

`src/LaTeX/Export.elm`:

```elm
module LaTeX.Export exposing (exportBody)

{-| Export XMarkdown source to LaTeX.

@docs exportBody

-}

import LaTeX.Block
import XMarkdown.Compiler


{-| The LaTeX for the document body only, with no preamble, for pasting into
an existing LaTeX document.
-}
exportBody : String -> String
exportBody source =
    source
        |> XMarkdown.Compiler.parseFromString
        |> LaTeX.Block.exportForest
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `npx elm-test tests/LaTeXBlockTest.elm`
Expected: all 15 tests PASS. If the GFM-table test fails only because the parser emits alignments differently (e.g. `"left,right"`), adapt `alignment` to map the parser's actual values, after checking them in `elm repl`; do not change the expected LaTeX.

- [ ] **Step 6: Full verification**

Run: `elm make src/XMarkdown/API.elm src/XMarkdown/Types.elm src/Render/Theme.elm src/LaTeX/Export.elm --output=/dev/null && npx elm-test`
Expected: success. Do not commit.

---

### Task 4: Lists in `LaTeX.Block`

**Files:**
- Modify: `src/LaTeX/Block.elm`
- Test: `tests/LaTeXListTest.elm`

**Interfaces:**
- Consumes: everything in `LaTeX.Block` from Task 3.
- Produces: no new public names. `exportForest` now groups consecutive loose `item` / `numbered` trees into one environment and exports compact `itemList` / `numberedList` blocks.

- [ ] **Step 1: Write the failing tests**

`tests/LaTeXListTest.elm`:

```elm
module LaTeXListTest exposing (suite)

import Expect
import LaTeX.Export exposing (exportBody)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "LaTeX lists"
        [ test "compact bullet list" <|
            \_ ->
                exportBody "- a\n- b *c*"
                    |> Expect.equal "\\begin{itemize}\n\\item a\n\\item b \\emph{c}\n\\end{itemize}"
        , test "compact numbered list" <|
            \_ ->
                exportBody ". one\n. two"
                    |> Expect.equal "\\begin{enumerate}\n\\item one\n\\item two\n\\end{enumerate}"
        , test "compact nested list" <|
            \_ ->
                exportBody "- a\n  - a1\n  - a2\n- b"
                    |> Expect.equal "\\begin{itemize}\n\\item a\n\\begin{itemize}\n\\item a1\n\\item a2\n\\end{itemize}\n\\item b\n\\end{itemize}"
        , test "loose bullet list is one environment" <|
            \_ ->
                exportBody "- a\n\n- b"
                    |> Expect.equal "\\begin{itemize}\n\\item a\n\\item b\n\\end{itemize}"
        , test "loose nested list" <|
            \_ ->
                exportBody "- a\n\n  - nested\n\n- b"
                    |> Expect.equal "\\begin{itemize}\n\\item a\n\\begin{itemize}\n\\item nested\n\\end{itemize}\n\\item b\n\\end{itemize}"
        , test "loose numbered list" <|
            \_ ->
                exportBody ". one\n\n. two"
                    |> Expect.equal "\\begin{enumerate}\n\\item one\n\\item two\n\\end{enumerate}"
        , test "a paragraph between loose items splits the list" <|
            \_ ->
                exportBody "- a\n\nText\n\n- b"
                    |> Expect.equal "\\begin{itemize}\n\\item a\n\\end{itemize}\n\nText\n\n\\begin{itemize}\n\\item b\n\\end{itemize}"
        ]
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx elm-test tests/LaTeXListTest.elm`
Expected: FAIL — compact lists come out as `% unsupported: itemList`, loose items as `% unsupported: item`.

- [ ] **Step 3: Implement**

In `src/LaTeX/Block.elm`, replace `exportForest` with the grouping version, add the `Group` type and helpers, and add the two compact-list cases to `exportBlock`:

```elm
exportForest : Forest ExpressionBlock -> String
exportForest forest =
    forest
        |> group
        |> List.map exportGroup
        |> String.join "\n\n"


{-| Consecutive loose list items (separate `item` / `numbered` trees) become one
LaTeX list environment; every other tree stands alone.
-}
type Group
    = Single (Tree ExpressionBlock)
    | Items String (List (Tree ExpressionBlock))


group : Forest ExpressionBlock -> List Group
group forest =
    List.foldr
        (\tree acc ->
            case ( listEnvironment tree, acc ) of
                ( Just env, (Items env2 trees) :: rest ) ->
                    if env == env2 then
                        Items env (tree :: trees) :: rest

                    else
                        Items env [ tree ] :: acc

                ( Just env, _ ) ->
                    Items env [ tree ] :: acc

                ( Nothing, _ ) ->
                    Single tree :: acc
        )
        []
        forest


listEnvironment : Tree ExpressionBlock -> Maybe String
listEnvironment tree =
    case (Tree.value tree).heading of
        Ordinary "item" ->
            Just "itemize"

        Ordinary "numbered" ->
            Just "enumerate"

        _ ->
            Nothing


exportGroup : Group -> String
exportGroup g =
    case g of
        Single tree ->
            exportTree tree

        Items env trees ->
            environment env (trees |> List.map exportItem |> String.join "\n")


exportItem : Tree ExpressionBlock -> String
exportItem tree =
    let
        item =
            "\\item " ++ inlineBody (Tree.value tree)
    in
    case Tree.children tree of
        [] ->
            item

        children ->
            item ++ "\n" ++ exportForest children
```

Add to `exportBlock`, before the `Ordinary name ->` fallback:

```elm
        Ordinary "itemList" ->
            compactList "itemize" block

        Ordinary "numberedList" ->
            compactList "enumerate" block
```

Add the compact-list helpers:

```elm
{-| A compact list is one block whose body is one ExprList per item, carrying
the item's indentation. Items indented deeper than the item before them open
a nested environment of the same kind.
-}
compactList : String -> ExpressionBlock -> String
compactList env block =
    case block.body of
        Right exprs ->
            nestItems env (List.filterMap toItem exprs)

        Left str ->
            LaTeX.Escape.text str


toItem : Expression -> Maybe ( Int, String )
toItem expr =
    case expr of
        ExprList indent exprs _ ->
            Just ( indent, LaTeX.Inline.exportExprs exprs )

        _ ->
            Nothing


nestItems : String -> List ( Int, String ) -> String
nestItems env items =
    case items of
        [] ->
            ""

        ( base, _ ) :: _ ->
            environment env (String.join "\n" (itemsAtLevel env base items))


itemsAtLevel : String -> Int -> List ( Int, String ) -> List String
itemsAtLevel env base items =
    case items of
        [] ->
            []

        ( _, text ) :: rest ->
            let
                ( deeper, remaining ) =
                    List.Extra.span (\( indent, _ ) -> indent > base) rest

                nested =
                    if List.isEmpty deeper then
                        ""

                    else
                        "\n" ++ nestItems env deeper
            in
            ("\\item " ++ text ++ nested) :: itemsAtLevel env base remaining
```

Add `Expression` to the `AST.Language` import: `import AST.Language exposing (Expr(..), Expression, ExpressionBlock, Heading(..))`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx elm-test tests/LaTeXListTest.elm`
Expected: all 7 PASS.

- [ ] **Step 5: Full verification**

Run: `elm make src/XMarkdown/API.elm src/XMarkdown/Types.elm src/Render/Theme.elm src/LaTeX/Export.elm --output=/dev/null && npx elm-test`
Expected: success, including Task 3's `LaTeXBlockTest`. Do not commit.

---

### Task 5: `LaTeX.Preamble`, `exportDocument`, `imageUrls`, expose the module

**Files:**
- Create: `src/LaTeX/Preamble.elm`
- Modify: `src/LaTeX/Export.elm`
- Modify: `elm.json` (`exposed-modules`)
- Test: `tests/LaTeXExportTest.elm`

**Interfaces:**
- Consumes: `LaTeX.Export.exportBody` (Task 3), `LaTeX.Image.fromText`, `LaTeX.Image.localPath` (Task 1), `LaTeX.Inline.plainText`, `LaTeX.Escape.text` (Tasks 1–2), `Library.Tree.flatten`.
- Produces:
  - `LaTeX.Preamble.make : String -> String` — preamble for a given body.
  - `type alias LaTeX.Export.DocumentInfo = { title : String, authors : List String, date : String }`
  - `LaTeX.Export.exportDocument : DocumentInfo -> String -> String`
  - `LaTeX.Export.imageUrls : String -> List ( String, String )`

- [ ] **Step 1: Write the failing tests**

`tests/LaTeXExportTest.elm`:

```elm
module LaTeXExportTest exposing (suite)

import Expect
import LaTeX.Export exposing (exportDocument, imageUrls)
import LaTeX.Preamble
import Test exposing (Test, describe, test)


noInfo : LaTeX.Export.DocumentInfo
noInfo =
    { title = "", authors = [], date = "" }


suite : Test
suite =
    describe "LaTeX.Export"
        [ test "plain document: minimal preamble, no maketitle" <|
            \_ ->
                exportDocument noInfo "Hello."
                    |> Expect.equal "\\documentclass[11pt]{article}\n\\usepackage[utf8]{inputenc}\n\\usepackage[T1]{fontenc}\n\n\\begin{document}\n\nHello.\n\n\\end{document}\n"
        , test "title block and maketitle when info is given" <|
            \_ ->
                exportDocument { title = "Black Holes", authors = [ "A. Einstein", "K. Schwarzschild" ], date = "1916" } "Hi."
                    |> String.contains "\\title{Black Holes}\n\\author{A. Einstein \\and K. Schwarzschild}\n\\date{1916}\n\n\\begin{document}\n\n\\maketitle\n\nHi."
                    |> Expect.equal True
        , test "math pulls in amsmath and amssymb" <|
            \_ ->
                LaTeX.Preamble.make "$x$"
                    |> Expect.all
                        [ String.contains "\\usepackage{amsmath}" >> Expect.equal True
                        , String.contains "\\usepackage{amssymb}" >> Expect.equal True
                        ]
        , test "images pull in graphicx, links pull in hyperref, chem pulls in mhchem" <|
            \_ ->
                LaTeX.Preamble.make "\\includegraphics{a} \\href{u}{t} \\ce{H2O}"
                    |> Expect.all
                        [ String.contains "\\usepackage{graphicx}" >> Expect.equal True
                        , String.contains "\\usepackage{hyperref}" >> Expect.equal True
                        , String.contains "\\usepackage[version=4]{mhchem}" >> Expect.equal True
                        ]
        , test "no optional packages for plain text" <|
            \_ ->
                LaTeX.Preamble.make "Hello."
                    |> String.contains "amsmath"
                    |> Expect.equal False
        , test "imageUrls: (url, localPath) pairs in order, without duplicates, including images in lists" <|
            \_ ->
                imageUrls "![A](https://x.com/a.jpg)\n\n- ![B](https://y.org/p/b%20c.png?s=1)\n\n![A again](https://x.com/a.jpg)"
                    |> Expect.equal
                        [ ( "https://x.com/a.jpg", "image/a.jpg" )
                        , ( "https://y.org/p/b%20c.png?s=1", "image/b-20c.png" )
                        ]
        , test "exported figure path matches imageUrls" <|
            \_ ->
                exportDocument noInfo "![A](https://y.org/p/b%20c.png?s=1)"
                    |> String.contains "{image/b-20c.png}"
                    |> Expect.equal True
        ]
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx elm-test tests/LaTeXExportTest.elm`
Expected: compile error — `LaTeX.Preamble` not found / `exportDocument` not exposed.

- [ ] **Step 3: Implement `LaTeX.Preamble`**

`src/LaTeX/Preamble.elm`:

```elm
module LaTeX.Preamble exposing (make)

{-| The document preamble. Optional packages are included only when the
exported body uses them.
-}


make : String -> String
make body =
    let
        uses str =
            String.contains str body

        usesMath =
            uses "$" || uses "\\[" || uses "\\begin{equation}" || uses "\\begin{align"

        optional condition packages =
            if condition then
                packages

            else
                []
    in
    String.join "\n"
        (List.concat
            [ [ "\\documentclass[11pt]{article}"
              , "\\usepackage[utf8]{inputenc}"
              , "\\usepackage[T1]{fontenc}"
              ]
            , optional usesMath [ "\\usepackage{amsmath}", "\\usepackage{amssymb}" ]
            , optional (uses "\\ce{") [ "\\usepackage[version=4]{mhchem}" ]
            , optional (uses "\\includegraphics") [ "\\usepackage{graphicx}" ]

            -- hyperref should be loaded last
            , optional (uses "\\href") [ "\\usepackage{hyperref}" ]
            ]
        )
```

- [ ] **Step 4: Extend `LaTeX.Export`**

Replace `src/LaTeX/Export.elm` with:

```elm
module LaTeX.Export exposing
    ( DocumentInfo
    , exportDocument, exportBody
    , imageUrls
    )

{-| Export XMarkdown source to LaTeX.

@docs DocumentInfo
@docs exportDocument, exportBody
@docs imageUrls

-}

import AST.Language exposing (Expr(..), Expression, ExpressionBlock)
import Either exposing (Either(..))
import LaTeX.Block
import LaTeX.Escape
import LaTeX.Image
import LaTeX.Inline
import LaTeX.Preamble
import Library.Tree
import List.Extra
import XMarkdown.Compiler


{-| Title-block information. When all fields are empty, the document has no
\\maketitle.
-}
type alias DocumentInfo =
    { title : String
    , authors : List String
    , date : String
    }


{-| A complete .tex document, ready for pdflatex once the images listed by
`imageUrls` have been downloaded.
-}
exportDocument : DocumentInfo -> String -> String
exportDocument info source =
    let
        body =
            exportBody source

        hasTitle =
            info.title /= "" || not (List.isEmpty info.authors) || info.date /= ""

        titleBlock =
            if hasTitle then
                [ "\\title{" ++ LaTeX.Escape.text info.title ++ "}"
                , "\\author{" ++ String.join " \\and " (List.map LaTeX.Escape.text info.authors) ++ "}"
                , "\\date{" ++ LaTeX.Escape.text info.date ++ "}"
                ]

            else
                []

        maketitle =
            if hasTitle then
                [ "\\maketitle", "" ]

            else
                []
    in
    String.join "\n"
        (LaTeX.Preamble.make body
            :: titleBlock
            ++ [ "", "\\begin{document}", "" ]
            ++ maketitle
            ++ [ body, "", "\\end{document}", "" ]
        )


{-| The LaTeX for the document body only, with no preamble, for pasting into
an existing LaTeX document.
-}
exportBody : String -> String
exportBody source =
    source
        |> XMarkdown.Compiler.parseFromString
        |> LaTeX.Block.exportForest


{-| Every image in the document as (url, local path), in order and without
duplicates. The exported LaTeX refers to the local paths; download each url
to its path, relative to the .tex file.
-}
imageUrls : String -> List ( String, String )
imageUrls source =
    source
        |> XMarkdown.Compiler.parseFromString
        |> List.concatMap Library.Tree.flatten
        |> List.concatMap blockImages
        |> List.Extra.unique


blockImages : ExpressionBlock -> List ( String, String )
blockImages block =
    case block.body of
        Right exprs ->
            List.concatMap exprImages exprs

        Left _ ->
            []


exprImages : Expression -> List ( String, String )
exprImages expr =
    case expr of
        Fun name args _ ->
            if name == "image" || name == "img" then
                let
                    image =
                        LaTeX.Image.fromText (LaTeX.Inline.plainText args)
                in
                [ ( image.url, LaTeX.Image.localPath image.url ) ]

            else
                List.concatMap exprImages args

        ExprList _ exprs _ ->
            List.concatMap exprImages exprs

        _ ->
            []
```

- [ ] **Step 5: Expose the module**

In `elm.json`, change `exposed-modules` to:

```json
    "exposed-modules": [
        "XMarkdown.API",
        "XMarkdown.Types",
        "Render.Theme",
        "LaTeX.Export"
    ],
```

Also update the `CLAUDE.md` "Public entry points" line to list `LaTeX.Export`, and add `src/LaTeX/` to its module layout list: "`LaTeX/` — XMarkdown → LaTeX export (public entry: `LaTeX.Export`)."

- [ ] **Step 6: Run tests to verify they pass**

Run: `npx elm-test tests/LaTeXExportTest.elm`
Expected: all 7 PASS.

- [ ] **Step 7: Full verification and docs check**

Run: `elm make src/XMarkdown/API.elm src/XMarkdown/Types.elm src/Render/Theme.elm src/LaTeX/Export.elm --output=/dev/null && npx elm-test && elm make --docs=/private/tmp/latex-docs.json`
Expected: success; `elm make --docs` succeeds (every exposed value of `LaTeX.Export` has a doc comment). Do not commit.

---

### Task 6: End-to-end check and spec update

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-latex-export-design.md`
- Create (scratch, not committed): a throwaway Elm script or `elm repl` input in the session scratchpad.

- [ ] **Step 1: Export the demo document**

Create a throwaway test (do not keep it) that prints the export of the demo sample through `Debug.log`-free means: the simplest is a one-off test file in the scratchpad's copy of the repo. Concretely:

1. Copy `DemoTOC+Sync/src/Data/XMarkdown.elm` to `tests/DataSample.elm`, renaming its module line to `module DataSample exposing (text)`.
2. Create `tests/LaTeXSampleDump.elm`:

```elm
module LaTeXSampleDump exposing (suite)

import DataSample
import Expect
import LaTeX.Export
import Test exposing (Test, test)


suite : Test
suite =
    test "dump" <|
        \_ ->
            LaTeX.Export.exportDocument { title = "Sample", authors = [ "XMarkdown" ], date = "" } DataSample.text
                |> Expect.equal ""
```

3. Run `npx elm-test tests/LaTeXSampleDump.elm`. It fails and prints the actual document; copy the printed string (it is shown as an Elm string literal, so un-escape it with a short Python `ast.literal_eval`-style step or `elm repl`) into `<scratchpad>/sample.tex`.
4. Delete `tests/DataSample.elm` and `tests/LaTeXSampleDump.elm`.

- [ ] **Step 2: Compile it with pdflatex, if available**

```bash
command -v pdflatex && (cd $S && mkdir -p image && pdflatex -interaction=nonstopmode -halt-on-error sample.tex)
```

Expected: exits 0, except for missing image files. If the only error is `File 'image/....jpg' not found`, download the files listed by `LaTeX.Export.imageUrls` into `$S/image/` and rerun; it must then compile. Any other LaTeX error is a bug: write a failing test for it in the relevant test file and fix it in the owning module. If `pdflatex` is not installed, say so in the report and skip this step.

- [ ] **Step 3: Update the spec**

Apply the five items from "Spec adjustments discovered while planning" to `docs/superpowers/specs/2026-10-01-latex-export-design.md`: remove `descriptionList` from the mapping table; change the `chem` row to "not ETeX-transformed"; add the `meta.sourceText` note to "Mappings"; add the `array` column-spec rule; change `aligned` → `align*`.

- [ ] **Step 4: Final verification**

Run: `elm make src/XMarkdown/API.elm src/XMarkdown/Types.elm src/Render/Theme.elm src/LaTeX/Export.elm --output=/dev/null && npx elm-test && npx elm-review --ignore-dirs src/Evergreen/`
Expected: compile and tests pass. Report any `elm-review` findings in the new `LaTeX.*` modules and fix them; leave findings in pre-existing modules alone. Do not commit — hand back to the user to test.

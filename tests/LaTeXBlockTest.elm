module LaTeXBlockTest exposing (suite)

import Expect
import LaTeX.Export exposing (exportBody)
import LaTeX.Image
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
                    |> Expect.equal ("\\begin{figure}[h]\n\\centering\n\\includegraphics[width=0.5\\textwidth]{" ++ LaTeX.Image.localPath "https://x.com/robin.jpg" ++ "}\n\\caption{Robin}\n\\end{figure}")
        ]

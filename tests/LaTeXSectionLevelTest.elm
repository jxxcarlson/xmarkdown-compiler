module LaTeXSectionLevelTest exposing (suite)

{-| In the LaTeX export, heading levels are shifted so that the document's
first heading becomes level 1 (`\section`).
-}

import Expect
import LaTeX.Export exposing (exportBody)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "section levels in the LaTeX export"
        [ test "first heading ## : every heading moves up one level" <|
            \_ ->
                exportBody "## One\n\n### Two\n\n## Three"
                    |> Expect.equal "\\section{One}\n\n\\subsection{Two}\n\n\\section{Three}"
        , test "first heading ### : shift by two" <|
            \_ ->
                exportBody "### One\n\n#### Two"
                    |> Expect.equal "\\section{One}\n\n\\subsection{Two}"
        , test "first heading # : nothing changes" <|
            \_ ->
                exportBody "# One\n\n## Two\n\n### Three"
                    |> Expect.equal "\\section{One}\n\n\\subsection{Two}\n\n\\subsubsection{Three}"
        , test "a heading shallower than the first is clamped to \\section" <|
            \_ ->
                exportBody "### One\n\n# Zero\n\n#### Two"
                    |> Expect.equal "\\section{One}\n\n\\section{Zero}\n\n\\subsection{Two}"
        , test "text before the first heading does not count as a heading" <|
            \_ ->
                exportBody "Intro text.\n\n## One\n\n### Two"
                    |> Expect.equal "Intro text.\n\n\\section{One}\n\n\\subsection{Two}"
        , test "a document with no headings is unchanged" <|
            \_ -> exportBody "Just text." |> Expect.equal "Just text."
        ]

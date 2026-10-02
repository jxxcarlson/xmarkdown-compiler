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

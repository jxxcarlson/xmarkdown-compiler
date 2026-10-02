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

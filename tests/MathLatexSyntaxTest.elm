module MathLatexSyntaxTest exposing (suite)

import Expect
import AST.Language exposing (Expr(..))
import Test exposing (Test, describe, test)
import Parser.Inline.Expression


{-| Extract all VFun "math" expressions from parsed inline expressions
-}
getMathExprs : String -> List String
getMathExprs str =
    Parser.Inline.Expression.parse 0 str
        |> List.filterMap
            (\expr ->
                case expr of
                    VFun "math" content _ ->
                        Just content

                    _ ->
                        Nothing
            )


suite : Test
suite =
    describe "Math LaTeX syntax \\(...\\)"
        [ test "\\(x^2\\) produces same AST as $x^2$" <|
            \_ ->
                let
                    dollarSyntax =
                        getMathExprs "$x^2$"

                    latexSyntax =
                        getMathExprs "\\(x^2\\)"
                in
                Expect.equal latexSyntax dollarSyntax
        , test "\\(a + b\\) parses as math" <|
            \_ ->
                getMathExprs "\\(a + b\\)"
                    |> Expect.equal [ "a + b" ]
        , test "\\(\\sum_{i=0}^n x_i\\) parses as math" <|
            \_ ->
                getMathExprs "\\(\\sum_{i=0}^n x_i\\)"
                    |> Expect.equal [ "\\sum_{i=0}^n x_i" ]
        , test "mixed $...$ and \\(...\\) in same line" <|
            \_ ->
                getMathExprs "We have $x^2$ and \\(y^2\\) here"
                    |> Expect.equal [ "x^2", "y^2" ]
        , test "\\(\\) empty math parses" <|
            \_ ->
                getMathExprs "\\(\\)"
                    |> Expect.equal [ "" ]
        , test "multiple \\(...\\) on same line" <|
            \_ ->
                getMathExprs "\\(a\\) and \\(b\\) and \\(c\\)"
                    |> Expect.equal [ "a", "b", "c" ]
        , test "\\( inside $...$ is literal text" <|
            \_ ->
                -- Inside $...$, \( and \) should be treated as literal text
                -- This should still parse as a single math expression
                let
                    result =
                        getMathExprs "$x \\( y\\)$"
                in
                List.length result
                    |> Expect.equal 1
        , test "text between delimiters: \\(a + b + c\\)" <|
            \_ ->
                getMathExprs "\\(a + b + c\\)"
                    |> Expect.equal [ "a + b + c" ]
        ]

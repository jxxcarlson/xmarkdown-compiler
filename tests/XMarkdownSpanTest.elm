module XMarkdownSpanTest exposing (suite)

import Expect
import AST.Language
import Test exposing (Test, describe, test)
import Parser.Inline.Expression


{-| Flatten the top-level expressions to (id, begin, end) triples so we can SEE
the source spans the parser now produces.
-}
spans : String -> List ( String, Int, Int )
spans str =
    Parser.Inline.Expression.parse 0 str
        |> List.map
            (\expr ->
                let
                    m =
                        AST.Language.getMeta expr
                in
                ( m.id, m.begin, m.end )
            )


suite : Test
suite =
    describe "XMarkdown source spans"
        [ test "inline expressions carry accurate within-line column spans" <|
            \_ ->
                -- Hello **world** and *there* [Elm](https://elm-lang.org)
                -- 0    5 6     14 ...        ...  28                    54
                -- The `id` carries the line (e-<line>.<tok>); begin/end are
                -- within-line columns. Before the fix every styled span was 0,0.
                spans "Hello **world** and *there* [Elm](https://elm-lang.org)"
                    |> Expect.equal
                        [ ( "e-0.0", 0, 5 )
                        , ( "e-0.4", 6, 14 )
                        , ( "e-0.0", 15, 19 )
                        , ( "e-0.8", 20, 26 )
                        , ( "e-0.0", 27, 27 )
                        , ( "e-0.15", 28, 54 )
                        ]
        , test "a bold span is non-degenerate (begin < end)" <|
            \_ ->
                spans "x **bold** y"
                    |> List.filter (\( _, b, e ) -> e > b)
                    |> List.isEmpty
                    |> Expect.equal False
        ]

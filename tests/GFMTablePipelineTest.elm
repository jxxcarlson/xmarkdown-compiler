module GFMTablePipelineTest exposing (suite)

import Dict
import Either exposing (Either(..))
import Expect
import Generic.Language exposing (Expr(..), Heading(..))
import Library.Tree
import ScriptaV2.Compiler
import Test exposing (Test, describe, test)


{-| Flatten a parsed table source into (heading, alignments, rowCount, firstCellText). -}
probe : String -> Maybe ( String, String, ( Int, String ) )
probe src =
    ScriptaV2.Compiler.parseFromString src
        |> List.concatMap Library.Tree.flatten
        |> List.head
        |> Maybe.map
            (\b ->
                let
                    heading =
                        case b.heading of
                            Ordinary n ->
                                "Ordinary:" ++ n

                            _ ->
                                "other"

                    aligns =
                        Dict.get "alignments" b.properties |> Maybe.withDefault "NONE"

                    ( nRows, firstCell ) =
                        case b.body of
                            Right [ Fun "table" rows _ ] ->
                                ( List.length rows, firstCellText rows )

                            _ ->
                                ( -1, "NOT-A-TABLE" )
                in
                ( heading, aligns, ( nRows, firstCell ) )
            )


firstCellText : List (Expr a) -> String
firstCellText rows =
    case rows of
        (Fun "row" (cell :: _) _) :: _ ->
            case cell of
                Fun "cell" exprs _ ->
                    exprs |> List.map exprText |> String.join ""

                _ ->
                    "?"

        _ ->
            "?"


exprText : Expr a -> String
exprText e =
    case e of
        Text s _ ->
            String.trim s

        _ ->
            "?"


suite : Test
suite =
    describe "GFM table via the pipeline"
        [ test "a table source becomes Ordinary table with the right AST + alignments" <|
            \_ ->
                probe "| Name | Age |\n|---|---:|\n| Alice | 29 |\n| Bob | 34 |"
                    |> Expect.equal (Just ( "Ordinary:table", "l,r", ( 3, "Name" ) ))
        , test "a non-table pipe block is unaffected (no table AST)" <|
            \_ ->
                probe "| theorem\nThe body of a theorem."
                    |> Maybe.map (\( h, _, _ ) -> h)
                    |> Expect.equal (Just "Ordinary:theorem")
        , test "a table with a trailing newline (finalized block) is still detected" <|
            \_ ->
                probe "| Name | Age |\n|---|---:|\n| Alice | 29 |\n| Bob | 34 |\n"
                    |> Expect.equal (Just ( "Ordinary:table", "l,r", ( 3, "Name" ) ))
        , test "a table followed by a blank line and more content (real document) is detected" <|
            \_ ->
                probe "| Name | Age |\n|---|---:|\n| Alice | 29 |\n| Bob | 34 |\n\nSome following text."
                    |> Expect.equal (Just ( "Ordinary:table", "l,r", ( 3, "Name" ) ))
        ]

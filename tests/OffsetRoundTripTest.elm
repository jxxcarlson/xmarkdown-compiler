module OffsetRoundTripTest exposing (suite)

{-| Every Text run's (begin, end) must slice its own text back out of the
source document. This is what makes rendered→editor sync land on the right
characters; see docs 2026-07-26-xmarkdown-word-level-sync-design.md.
-}

import AST.Language exposing (Expr(..))
import Either exposing (Either(..))
import Expect
import Library.Tree
import Test exposing (Test, describe, test)
import XMarkdown.Compiler


{-| Each Text run paired with the source text its offsets actually point at.
A correct compiler makes both halves of every pair equal.
-}
roundTrip : String -> List ( String, String )
roundTrip doc =
    let
        go expr =
            case expr of
                Text s m ->
                    [ ( s, String.slice m.begin (m.end + 1) doc ) ]

                Fun _ cs _ ->
                    List.concatMap go cs

                ExprList _ cs _ ->
                    List.concatMap go cs

                VFun _ _ _ ->
                    []
    in
    XMarkdown.Compiler.parseFromString doc
        |> List.concatMap Library.Tree.flatten
        |> List.concatMap
            (\b ->
                case b.body of
                    Right exprs ->
                        List.concatMap go exprs

                    Left _ ->
                        []
            )


{-| The runs whose offsets do NOT point at their own text. Empty means correct.
-}
mismatches : String -> List ( String, String )
mismatches doc =
    roundTrip doc |> List.filter (\( run, sliced ) -> run /= sliced)


suite : Test
suite =
    describe "Text run offsets round-trip through the source"
        [ test "plain paragraph" <|
            \_ ->
                mismatches "intro line\n\nsecond paragraph here\n"
                    |> Expect.equal []
        , test "bold and italic inside a paragraph" <|
            \_ ->
                mismatches "some **bold** and *italic* words here\n"
                    |> Expect.equal []
        , test "heading" <|
            \_ ->
                mismatches "intro line\n\n# Head\n\ntail line\n"
                    |> Expect.equal []
        , test "heading levels 2 and 3" <|
            \_ ->
                mismatches "## Two\n\n### Three\n"
                    |> Expect.equal []
        , test "heading followed by a paragraph it must not disturb" <|
            \_ ->
                mismatches "# Head\n\nsome **bold** words here\n"
                    |> Expect.equal []
        , test "title marker" <|
            \_ ->
                mismatches "!! My Title\n\nbody text\n"
                    |> Expect.equal []
        , test "block quote" <|
            \_ ->
                mismatches "> quoted words here\n"
                    |> Expect.equal []
        , test "title block" <|
            \_ ->
                mismatches "!! The Title\n\nbody text\n"
                    |> Expect.equal []
        , test "bulleted list" <|
            \_ ->
                mismatches "intro\n\n- alpha beta\n- gamma delta\n"
                    |> Expect.equal []
        , test "numbered list, dot marker" <|
            \_ ->
                mismatches "intro\n\n. alpha beta\n. gamma delta\n"
                    |> Expect.equal []
        , test "numbered list, 1. marker" <|
            \_ ->
                mismatches "intro\n\n1. alpha beta\n2. gamma delta\n"
                    |> Expect.equal []
        , test "indented nested list" <|
            \_ ->
                mismatches "- outer item\n  - inner item\n"
                    |> Expect.equal []
        , test "bold inside a list item" <|
            \_ ->
                mismatches "- item with **bold** inside\n"
                    |> Expect.equal []

        -- A lone numbered item (no second numbered line follows) stays
        -- classified as the single-item "numbered" block, routed through
        -- PrimitiveBlock.transformBlock rather than Pipeline's
        -- "numberedList" branch. This is the numbered counterpart of
        -- "bold inside a list item" above, added to cover the symmetric
        -- fix applied to transformBlock's `Just "numbered"` case.
        , test "lone numbered item" <|
            \_ ->
                mismatches ". only item here\n"
                    |> Expect.equal []
        , test "GFM table cells" <|
            \_ ->
                mismatches "| a one | b two |\n|---|---|\n| c three | d four |\n"
                    |> Expect.equal []
        , test "multi-line block quote" <|
            \_ ->
                mismatches "> quoted words\n> more words\n"
                    |> Expect.equal []
        , test "a block quote produces text runs at all" <|
            \_ ->
                List.length (roundTrip "> quoted words here\n")
                    |> Expect.greaterThan 0
        , test "a table produces text runs at all" <|
            \_ ->
                List.length (roundTrip "| a | b |\n|---|---|\n| c | d |\n")
                    |> Expect.greaterThan 0
        ]

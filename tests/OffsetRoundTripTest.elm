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
        ]

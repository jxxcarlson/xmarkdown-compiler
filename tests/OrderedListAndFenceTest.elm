module OrderedListAndFenceTest exposing (suite)

{-| Standard-Markdown ordered lists (`1. alpha`) and code fences carrying a
language tag (```` ```elm ````) must compile the same way as their XMarkdown
counterparts (`. alpha` and a bare ```` ``` ````).
-}

import AST.Language exposing (Expr(..), ExpressionBlock, Heading(..))
import Either exposing (Either(..))
import Expect
import Library.Tree
import Test exposing (Test, describe, test)
import XMarkdown.Compiler


blocks : String -> List ExpressionBlock
blocks str =
    XMarkdown.Compiler.parseFromString str
        |> List.concatMap Library.Tree.flatten


{-| The heading of every block in the document.
-}
headings : String -> List Heading
headings str =
    blocks str |> List.map .heading


{-| The plain text of every block that holds inline expressions.
-}
texts : String -> List String
texts str =
    let
        go expr =
            case expr of
                Text s _ ->
                    [ s ]

                Fun _ cs _ ->
                    List.concatMap go cs

                ExprList _ cs _ ->
                    List.concatMap go cs

                VFun _ _ _ ->
                    []
    in
    blocks str
        |> List.concatMap
            (\b ->
                case b.body of
                    Right exprs ->
                        List.concatMap go exprs

                    Left _ ->
                        []
            )


{-| The verbatim text of every block that holds a literal body.
-}
verbatimBodies : String -> List String
verbatimBodies str =
    blocks str
        |> List.filterMap
            (\b ->
                case b.body of
                    Left s ->
                        Just s

                    Right _ ->
                        Nothing
            )


suite : Test
suite =
    describe "Ordered lists and code fences"
        [ describe "ordered lists"
            [ test "`1. alpha` is a numbered item, like `. alpha`" <|
                \_ ->
                    headings "1. alpha\n2. beta\n"
                        |> Expect.equal (headings ". alpha\n. beta\n")
            , test "`1. alpha` keeps its text, with the marker stripped" <|
                \_ ->
                    texts "1. alpha\n2. beta\n"
                        |> Expect.equal [ "alpha", "beta" ]
            , test "`1) alpha` is also a numbered item" <|
                \_ ->
                    ( headings "1) alpha\n2) beta\n", texts "1) alpha\n2) beta\n" )
                        |> Expect.equal ( headings ". alpha\n. beta\n", [ "alpha", "beta" ] )
            , test "a number that is not a list marker stays a paragraph" <|
                \_ ->
                    headings "1.5 kilometers to go\n"
                        |> Expect.equal [ Paragraph ]
            , test "only the leading marker is stripped, not later periods" <|
                \_ ->
                    texts ". Take one. Then stop\n"
                        |> Expect.equal [ "Take one. Then stop" ]
            ]
        , describe "code fences"
            [ test "a bare fence is a code block" <|
                \_ ->
                    headings "```\nf x = x\n```\n"
                        |> Expect.equal [ Verbatim "code" ]
            , test "a fence with a language tag is also a code block" <|
                \_ ->
                    headings "```elm\nf x = x\n```\n"
                        |> Expect.equal [ Verbatim "code" ]
            , test "the language tag does not leak into the code" <|
                \_ ->
                    verbatimBodies "```elm\nf x = x\n```\n"
                        |> Expect.equal [ "f x = x" ]
            , test "a tagged fence yields the same code as a bare one" <|
                \_ ->
                    verbatimBodies "```elm\nf x = x\ng y = y\n```\n"
                        |> Expect.equal (verbatimBodies "```\nf x = x\ng y = y\n```\n")
            , test "the language tag is kept as a block argument" <|
                \_ ->
                    blocks "```elm\nf x = x\n```\n"
                        |> List.map .args
                        |> Expect.equal [ [ "elm" ] ]
            ]
        ]

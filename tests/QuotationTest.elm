module QuotationTest exposing (suite)

{-| Quotations used to render only their first line, as raw text: the committed
body kept just the continuation lines, nothing restored the first, and the
renderer read the "firstLine" property instead of the parsed body. So a
multi-line quote lost everything after line 1, and inline markup showed
literally.
-}

import AST.Language exposing (Expr(..))
import Either exposing (Either(..))
import Expect
import Library.Tree
import Test exposing (Test, describe, test)
import XMarkdown.Compiler


{-| The text of every run in the document's blocks, in order.
-}
runs : String -> List String
runs doc =
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


{-| Every function name applied in the document, e.g. "b" for bold.
-}
functions : String -> List String
functions doc =
    let
        go expr =
            case expr of
                Fun name cs _ ->
                    name :: List.concatMap go cs

                ExprList _ cs _ ->
                    List.concatMap go cs

                _ ->
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


suite : Test
suite =
    describe "Quotation blocks"
        [ test "a single-line quote produces its text" <|
            \_ ->
                runs "> quoted words here\n"
                    |> Expect.equal [ "quoted words here" ]
        , test "a multi-line quote keeps every line" <|
            \_ ->
                runs "> line one\n> line two\n> line three\n"
                    |> Expect.equal [ "line one", "line two", "line three" ]
        , test "the leading > is stripped from continuation lines" <|
            \_ ->
                runs "> alpha\n> beta\n"
                    |> List.filter (String.contains ">")
                    |> Expect.equal []
        , test "inline markup inside a quote is parsed, not literal" <|
            \_ ->
                functions "> quoted **words**\n"
                    |> Expect.equal [ "bold" ]
        , test "markup on a continuation line is parsed too" <|
            \_ ->
                functions "> plain line\n> with *emphasis*\n"
                    |> Expect.equal [ "italic" ]
        , test "a quote surrounded by paragraphs does not swallow them" <|
            \_ ->
                runs "before\n\n> quoted\n\nafter\n"
                    |> Expect.equal [ "before", "quoted", "after" ]
        ]

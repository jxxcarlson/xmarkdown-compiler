module VerseTest exposing (suite)

{-| `/begin NAME ... /end NAME` blocks, and verse (`/begin verse`): line
endings, leading spaces and blank lines are kept; inline markup works.
-}

import AST.Language exposing (Expr(..), Heading(..))
import Either exposing (Either(..))
import Expect
import Html
import LaTeX.Export exposing (exportBody)
import RoseTree.Tree as Tree
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import XMarkdown.API
import XMarkdown.Compiler
import XMarkdown.Types


sample : String
sample =
    String.join "\n"
        [ "Intro"
        , ""
        , "/begin verse"
        , "Roses are *red*,"
        , "    violets are **blue**."
        , ""
        , ""
        , "Sugar is sweet"
        , "/end verse"
        , "After the verse."
        ]


blocks : String -> List AST.Language.ExpressionBlock
blocks =
    XMarkdown.Compiler.parseFromString >> List.map Tree.value


headings : String -> List Heading
headings =
    blocks >> List.map .heading


verseBlock : String -> Maybe AST.Language.ExpressionBlock
verseBlock src =
    blocks src |> List.filter (\b -> b.heading == Ordinary "verse") |> List.head


{-| The verse's lines as (indentation, number of expressions).
-}
verseLines : String -> List ( Int, Int )
verseLines src =
    case Maybe.map .body (verseBlock src) of
        Just (Right exprs) ->
            List.filterMap
                (\expr ->
                    case expr of
                        ExprList indent list _ ->
                            Just ( indent, List.length list )

                        _ ->
                            Nothing
                )
                exprs

        _ ->
            []


rendered : String -> Query.Single XMarkdown.Types.MarkupMsg
rendered src =
    XMarkdown.API.compileString XMarkdown.API.defaultCompilerParameters src
        |> Html.div []
        |> Query.fromHtml


suite : Test
suite =
    describe "verse and /begin ... /end blocks"
        [ describe "parser"
            [ test "the verse is one block, and the text after /end is a new block" <|
                \_ ->
                    headings sample
                        |> Expect.equal [ Paragraph, Ordinary "verse", Paragraph ]
            , test "one line per source line, with indentation; blank lines are kept" <|
                \_ ->
                    verseLines sample
                        |> Expect.equal [ ( 0, 3 ), ( 4, 3 ), ( 0, 0 ), ( 0, 0 ), ( 0, 1 ) ]
            , test "source text, line number and line count cover both delimiters" <|
                \_ ->
                    verseBlock sample
                        |> Maybe.map (\b -> ( b.meta.lineNumber, b.meta.numberOfLines, String.lines b.meta.sourceText |> List.length ))
                        |> Expect.equal (Just ( 3, 7, 7 ))
            , test "inline positions are positions in the source" <|
                \_ ->
                    -- "*red*" starts at offset 30 of the sample
                    case Maybe.map .body (verseBlock sample) of
                        Just (Right ((ExprList _ [ _, Fun "italic" _ meta, _ ] _) :: _)) ->
                            Expect.equal ( meta.begin, String.slice meta.begin (meta.end + 1) sample ) ( 30, "*red*" )

                        other ->
                            Expect.fail (Debug.toString other)
            , test "a /begin block with no /end runs to the end of the document" <|
                \_ ->
                    verseLines "/begin verse\none\n\ntwo"
                        |> Expect.equal [ ( 0, 1 ), ( 0, 0 ), ( 0, 1 ) ]
            , test "/end must name the block" <|
                \_ ->
                    verseLines "/begin verse\none\n/end poem\ntwo\n/end verse"
                        |> List.length
                        |> Expect.equal 3
            , test "any name makes a block of that name" <|
                \_ ->
                    headings "/begin theorem\nFirst.\n\nSecond.\n/end theorem"
                        |> Expect.equal [ Ordinary "theorem" ]
            , test "/begin with no name is an error, not a block" <|
                \_ ->
                    headings "/begin\ntext"
                        |> Expect.equal [ Paragraph ]
            ]
        , describe "HTML"
            [ test "one line element per source line" <|
                \_ ->
                    rendered sample
                        |> Query.findAll [ Selector.style "min-height" "1.4em" ]
                        |> Query.count (Expect.equal 5)
            , test "leading spaces indent the line" <|
                \_ ->
                    rendered sample
                        |> Query.has [ Selector.style "padding-left" "4ch" ]
            , test "inline markup is rendered" <|
                \_ ->
                    rendered sample
                        |> Expect.all
                            [ Query.has [ Selector.text "red" ]
                            , Query.hasNot [ Selector.text "*red*" ]
                            , Query.hasNot [ Selector.text "/end verse" ]
                            ]
            ]
        , describe "LaTeX"
            [ test "exports a verse environment" <|
                \_ ->
                    exportBody sample
                        |> String.contains
                            (String.join "\n"
                                [ "\\begin{verse}"
                                , "Roses are \\emph{red}, \\\\"
                                , "\\hspace*{2em}violets are \\textbf{blue}."
                                , ""
                                , "\\vspace{\\baselineskip}"
                                , ""
                                , "Sugar is sweet"
                                , "\\end{verse}"
                                ]
                            )
                        |> Expect.equal True
            ]
        ]

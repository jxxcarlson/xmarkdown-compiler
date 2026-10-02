module TitleBlockTest exposing (suite)

{-| The %title / %author / %date block (docs/title-block.md).
-}

import AST.Language exposing (Heading(..))
import AST.TitleBlock
import Expect
import Html
import Html.Attributes
import LaTeX.Export exposing (exportBody, exportDocument)
import RoseTree.Tree as Tree
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import XMarkdown.API
import XMarkdown.Compiler
import XMarkdown.Types


example : String
example =
    "%title Consistency and Models\n%author ChatGPT\n%date October 1, 2026\n\n# Intro\n\nSome text."


titleBlock : String -> Maybe AST.TitleBlock.TitleBlock
titleBlock =
    XMarkdown.Compiler.parseFromString >> AST.TitleBlock.fromForest


noInfo : LaTeX.Export.DocumentInfo
noInfo =
    { title = "", authors = [], date = "" }


rendered : String -> Query.Single XMarkdown.Types.MarkupMsg
rendered src =
    XMarkdown.API.compileString XMarkdown.API.defaultCompilerParameters src
        |> Html.div []
        |> Query.fromHtml


suite : Test
suite =
    describe "title block"
        [ describe "parser"
            [ test "a block starting with % is a titleBlock" <|
                \_ ->
                    XMarkdown.Compiler.parseFromString example
                        |> List.map (Tree.value >> .heading)
                        |> List.head
                        |> Expect.equal (Just (Ordinary "titleBlock"))
            , test "the rest of the document is unaffected" <|
                \_ ->
                    XMarkdown.Compiler.parseFromString example
                        |> List.map (Tree.value >> .heading)
                        |> Expect.equal [ Ordinary "titleBlock", Ordinary "section", Paragraph ]
            ]
        , describe "AST.TitleBlock"
            [ test "reads title, author and date" <|
                \_ ->
                    titleBlock example
                        |> Expect.equal (Just { title = "Consistency and Models", authors = [ "ChatGPT" ], date = "October 1, 2026" })
            , test "repeated %author lines give several authors, in order" <|
                \_ ->
                    titleBlock "%title T\n%author A. Einstein\n%author K. Schwarzschild"
                        |> Maybe.map .authors
                        |> Expect.equal (Just [ "A. Einstein", "K. Schwarzschild" ])
            , test "other % lines are ignored" <|
                \_ ->
                    titleBlock "%title T\n% note to self\n%titel typo\n%date D"
                        |> Expect.equal (Just { title = "T", authors = [], date = "D" })
            , test "extra spaces are trimmed" <|
                \_ ->
                    titleBlock "%title    Spaced   Out  \n%author   X  "
                        |> Expect.equal (Just { title = "Spaced   Out", authors = [ "X" ], date = "" })
            , test "missing fields are empty" <|
                \_ ->
                    titleBlock "%author Only Me"
                        |> Expect.equal (Just { title = "", authors = [ "Only Me" ], date = "" })
            , test "no title block gives Nothing" <|
                \_ -> titleBlock "# Intro\n\nText" |> Expect.equal Nothing
            , test "only the first title block counts" <|
                \_ ->
                    titleBlock "%title First\n\nText\n\n%title Second"
                        |> Maybe.map .title
                        |> Expect.equal (Just "First")
            ]
        , describe "HTML"
            [ test "title is centered at 2em" <|
                \_ ->
                    rendered example
                        |> Query.find [ Selector.containing [ Selector.text "Consistency and Models" ], Selector.style "font-size" "2em" ]
                        |> Query.has [ Selector.style "text-align" "center" ]
            , test "author is centered at 1.5em" <|
                \_ ->
                    rendered example
                        |> Query.find [ Selector.style "font-size" "1.5em", Selector.containing [ Selector.text "ChatGPT" ] ]
                        |> Query.has [ Selector.style "text-align" "center", Selector.style "margin-bottom" "1.5em" ]
            , test "the last line has 3em below it" <|
                \_ ->
                    rendered example
                        |> Query.find [ Selector.style "font-size" "1.5em", Selector.containing [ Selector.text "October 1, 2026" ] ]
                        |> Query.has [ Selector.style "margin-bottom" "3em" ]
            , test "the % markers and hidden lines are not shown" <|
                \_ ->
                    rendered "%title T\n% secret note\n%author A"
                        |> Expect.all
                            [ Query.hasNot [ Selector.text "%title" ]
                            , Query.hasNot [ Selector.text "secret note" ]
                            ]
            , test "the title block carries its block id (for sync)" <|
                \_ ->
                    rendered example
                        |> Query.find [ Selector.style "font-size" "2em" ]
                        |> Query.has [ Selector.attribute (Html.Attributes.attribute "data-title-block" "true") ]
            ]
        , describe "LaTeX"
            [ test "exportDocument emits title, author and date, then maketitle" <|
                \_ ->
                    exportDocument noInfo example
                        |> String.contains "\\title{Consistency and Models}\n\\author{ChatGPT}\n\\date{October 1, 2026}\n\n\\begin{document}\n\n\\maketitle"
                        |> Expect.equal True
            , test "two authors are joined with \\and" <|
                \_ ->
                    exportDocument noInfo "%title T\n%author A\n%author B"
                        |> String.contains "\\author{A \\and B}"
                        |> Expect.equal True
            , test "the title block puts nothing in the body" <|
                \_ -> exportBody example |> Expect.equal "\\section{Intro}\n\nSome text."
            , test "a non-empty caller field wins over the source" <|
                \_ ->
                    exportDocument { noInfo | title = "Override" } example
                        |> Expect.all
                            [ String.contains "\\title{Override}" >> Expect.equal True
                            , String.contains "\\author{ChatGPT}" >> Expect.equal True
                            ]
            , test "special characters in the title are escaped" <|
                \_ ->
                    exportDocument noInfo "%title R&D at 100%"
                        |> String.contains "\\title{R\\&D at 100\\%}"
                        |> Expect.equal True
            ]
        ]

module HorizontalRuleTest exposing (suite)

{-| Horizontal rules: a line of three or more `-`, `*` or `_` (spaces allowed
between them), as in standard Markdown.
-}

import AST.Language exposing (Heading(..))
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


headings : String -> List Heading
headings =
    XMarkdown.Compiler.parseFromString >> List.map (Tree.value >> .heading)


rendered : String -> Query.Single XMarkdown.Types.MarkupMsg
rendered src =
    XMarkdown.API.compileString XMarkdown.API.defaultCompilerParameters src
        |> Html.div []
        |> Query.fromHtml


isRule : String -> Test
isRule line =
    test ("\"" ++ line ++ "\" is a rule") <|
        \_ ->
            headings ("Above\n\n" ++ line ++ "\n\nBelow")
                |> Expect.equal [ Paragraph, Ordinary "hrule", Paragraph ]


suite : Test
suite =
    describe "horizontal rule"
        [ describe "parser"
            [ isRule "---"
            , isRule "***"
            , isRule "___"
            , isRule "-----"
            , isRule "- - -"
            , isRule "* * *"
            , isRule "---   "
            , test "surrounding spaces are allowed" <|
                \_ ->
                    headings "  ---  "
                        |> Expect.equal [ Ordinary "hrule" ]
            , test "two dashes are not a rule" <|
                \_ ->
                    headings "--"
                        |> Expect.equal [ Paragraph ]
            , test "mixed characters are not a rule" <|
                \_ ->
                    headings "-*-"
                        |> Expect.equal [ Paragraph ]
            , test "a list item is still a list item" <|
                \_ ->
                    headings "- alpha"
                        |> Expect.equal [ Ordinary "item" ]
            , test "a heading is still a heading" <|
                \_ ->
                    headings "# Intro"
                        |> Expect.equal [ Ordinary "section" ]
            ]
        , describe "HTML"
            [ test "renders an <hr>" <|
                \_ ->
                    rendered "Above\n\n---\n\nBelow"
                        |> Query.findAll [ Selector.tag "hr" ]
                        |> Query.count (Expect.equal 1)
            , test "does not show the dashes" <|
                \_ ->
                    rendered "Above\n\n---\n\nBelow"
                        |> Query.hasNot [ Selector.text "---" ]
            , test "text on the lines after the rule is kept" <|
                \_ ->
                    rendered "---\nBelow the rule"
                        |> Expect.all
                            [ Query.findAll [ Selector.tag "hr" ] >> Query.count (Expect.equal 1)
                            , Query.has [ Selector.text "Below the rule" ]
                            ]
            ]
        , describe "LaTeX"
            [ test "exports a rule" <|
                \_ ->
                    exportBody "Above\n\n---\n\nBelow"
                        |> String.contains "\\noindent\\rule{\\linewidth}{0.4pt}"
                        |> Expect.equal True
            , test "does not export the dashes" <|
                \_ ->
                    exportBody "Above\n\n---\n\nBelow"
                        |> String.contains "---"
                        |> Expect.equal False
            ]
        ]

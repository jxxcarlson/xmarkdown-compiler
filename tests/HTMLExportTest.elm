module HTMLExportTest exposing (suite)

import Expect
import HTML.Export exposing (SectionNumbers(..), TOC(..), toTextHtml)
import Test exposing (Test, describe, test)
import XMarkdown.API


page : TOC -> SectionNumbers -> String -> String
page toc numbers source =
    toTextHtml toc numbers (XMarkdown.API.parse source)


contains : String -> String -> Expect.Expectation
contains fragment output =
    String.contains fragment output
        |> Expect.equal True
        |> Expect.onFail ("expected to contain\n\n" ++ fragment ++ "\n\nin\n\n" ++ output)


lacks : String -> String -> Expect.Expectation
lacks fragment output =
    String.contains fragment output
        |> Expect.equal False
        |> Expect.onFail ("expected not to contain\n\n" ++ fragment ++ "\n\nin\n\n" ++ output)


{-| The section numbers in the page, in order.
-}
sectionNumbers : String -> List String
sectionNumbers html =
    html
        |> String.split "<span class=\"xm-section-number\">"
        |> List.drop 1
        |> List.map (String.split "</span>" >> List.head >> Maybe.withDefault "")


suite : Test
suite =
    describe "HTML.Export"
        [ test "a complete page" <|
            \_ ->
                page WithoutTOC WithoutSectionNumbers "Hi."
                    |> Expect.all
                        [ String.startsWith "<!doctype html>\n<html lang=\"en\">" >> Expect.equal True
                        , contains "<p class=\"xm-paragraph\">Hi.</p>"
                        , contains "<title>Untitled</title>"
                        , contains "katex@0.16.9/dist/katex.min.css"
                        , contains "contrib/mhchem.min.js"
                        , contains "<style id=\"xm-default-style\">"
                        , String.indexes "<body>" >> List.length >> Expect.equal 1
                        , String.endsWith "</html>\n" >> Expect.equal True
                        ]
        , test "title block becomes the title and the header, escaped" <|
            \_ ->
                page WithoutTOC WithoutSectionNumbers "%title A <B>\n%author X\n%author Y\n%date 2026\n\n# Intro"
                    |> Expect.all
                        [ contains "<title>A &lt;B&gt;</title>"
                        , contains "<header class=\"xm-title-block\"><h1 class=\"xm-title\">A &lt;B&gt;</h1><p class=\"xm-authors\">X, Y</p><p class=\"xm-date\">2026</p></header>"
                        ]
        , test "without a title block the first heading is the title" <|
            \_ ->
                page WithoutTOC WithoutSectionNumbers "# First\n\nx"
                    |> Expect.all [ contains "<title>First</title>", lacks "<header" ]
        , test "section numbers" <|
            \_ ->
                page WithoutTOC WithSectionNumbers "# A\n\n## B\n\n# C"
                    |> sectionNumbers
                    |> Expect.equal [ "1", "1.1", "2" ]
        , test "a document starting at ## is numbered from 1" <|
            \_ ->
                page WithoutTOC WithSectionNumbers "## A\n\n## B"
                    |> sectionNumbers
                    |> Expect.equal [ "1", "2" ]
        , test "hand-typed numbers are replaced, not doubled" <|
            \_ ->
                page WithoutTOC WithSectionNumbers "# 1. Intro"
                    |> Expect.all
                        [ contains "<span class=\"xm-section-number\">1</span> Intro"
                        , lacks "1. Intro"
                        ]
        , test "WithoutSectionNumbers shows no numbers, in the body or the TOC" <|
            \_ -> page WithTOC WithoutSectionNumbers "# A" |> lacks "<span class=\"xm-section-number\""
        , test "table of contents, nested, with numbers" <|
            \_ ->
                page WithTOC WithSectionNumbers "# A\n\n## B"
                    |> contains "<nav class=\"xm-toc\"><ul><li><a href=\"#a\"><span class=\"xm-section-number\">1</span> A</a><ul><li><a href=\"#b\">"
        , test "WithoutTOC has no nav" <|
            \_ -> page WithoutTOC WithSectionNumbers "# A" |> lacks "<nav"
        , test "duplicate headings get unique ids and TOC links" <|
            \_ ->
                page WithTOC WithoutSectionNumbers "# Notes\n\nx\n\n# Notes"
                    |> Expect.all
                        [ contains "id=\"notes\""
                        , contains "id=\"notes-2\""
                        , contains "href=\"#notes\""
                        , contains "href=\"#notes-2\""
                        ]
        , test "a lone $ in prose is not math" <|
            \_ ->
                page WithoutTOC WithoutSectionNumbers "costs $5 and C:\\path"
                    |> lacks "<span class=\"xm-math\""
        , test "the page script renders only .xm-math elements" <|
            \_ ->
                page WithoutTOC WithoutSectionNumbers "Hi."
                    |> Expect.all [ contains "querySelectorAll(\".xm-math\")", contains "throwOnError: false" ]
        , test "a generated id never collides with a real heading's slug" <|
            \_ ->
                page WithTOC WithoutSectionNumbers "# Notes\n\nx\n\n# Notes\n\ny\n\n# Notes 2"
                    |> String.indexes "id=\"notes-2\""
                    |> List.length
                    |> Expect.equal 1
        , test "headings deeper than level 4 get their own numbers" <|
            \_ ->
                page WithoutTOC WithSectionNumbers "# A\n\n## B\n\n### C\n\n#### D\n\n##### E\n\n###### F"
                    |> sectionNumbers
                    |> Expect.equal [ "1", "1.1", "1.1.1", "1.1.1.1", "1.1.1.1.1", "1.1.1.1.1.1" ]
        , test "a skipped level counts as 0" <|
            \_ ->
                page WithoutTOC WithSectionNumbers "# A\n\n### Deep\n\n# B"
                    |> sectionNumbers
                    |> Expect.equal [ "1", "1.0.1", "2" ]
        , test "the page title keeps text inside markup and math" <|
            \_ ->
                page WithoutTOC WithoutSectionNumbers "# The **big** $x^2$ case"
                    |> contains "<title>The big x^2 case</title>"
        , test "a section id keeps text inside markup" <|
            \_ ->
                page WithoutTOC WithoutSectionNumbers "# Intro to *Elm*"
                    |> contains "id=\"intro-to-elm\""
        , test "KaTeX only trusts http(s) and relative URLs" <|
            \_ ->
                page WithoutTOC WithoutSectionNumbers "Hi."
                    |> Expect.all [ lacks "trust: true", contains "[\"http\", \"https\", \"_relative\"].includes(context.protocol)" ]
        , test "WithTOC puts the article and the TOC side by side in xm-layout" <|
            \_ ->
                page WithTOC WithoutSectionNumbers "# A\n\nx"
                    |> Expect.all
                        [ contains "<div class=\"xm-layout\">\n<article class=\"xm-document\">"
                        , contains "</article>\n<nav class=\"xm-toc\">"
                        , contains "</nav>\n</div>\n</body>"
                        ]
        , test "WithTOC keeps the title block at the top of the text column" <|
            \_ ->
                page WithTOC WithoutSectionNumbers "%title T\n\n# A"
                    |> contains "<article class=\"xm-document\">\n<header class=\"xm-title-block\">"
        , test "WithoutTOC has no layout wrapper" <|
            \_ -> page WithoutTOC WithoutSectionNumbers "# A" |> lacks "<div class=\"xm-layout\""
        , test "the TOC column stays in view, and goes above the text on narrow screens" <|
            \_ ->
                page WithTOC WithoutSectionNumbers "# A"
                    |> Expect.all [ contains "position: sticky", contains "@media (max-width: 900px)" ]
        , test "a wrapped TOC entry is inset as far as the next level" <|
            \_ ->
                page WithTOC WithoutSectionNumbers "# A"
                    |> Expect.all
                        [ contains ".xm-toc ul { list-style: none; padding-left: 0; margin: 0.2rem 0; }"
                        , contains ".xm-toc li { padding-left: 1.25rem; text-indent: -1.25rem; }"
                        ]
        ]

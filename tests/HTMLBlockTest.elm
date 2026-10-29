module HTMLBlockTest exposing (suite)

import AST.Acc
import Dict
import Expect
import HTML.Block
import RoseTree.Tree as Tree
import Test exposing (Test, describe, test)
import XMarkdown.Compiler


{-| The block HTML of a document, numbered as `HTML.Export` numbers it.
-}
block : String -> String
block source =
    XMarkdown.Compiler.parseFromString source
        |> AST.Acc.transformAccumulate
        |> Tuple.second
        |> HTML.Block.forest


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


suite : Test
suite =
    describe "HTML.Block"
        [ test "paragraph" <|
            \_ -> block "Hello." |> Expect.equal "<p class=\"xm-paragraph\">Hello.</p>"
        , test "section: heading tag is level + 1, id from the tag property, no number without a label" <|
            \_ ->
                XMarkdown.Compiler.parseFromString "## Results"
                    |> AST.Acc.transformAccumulate
                    |> Tuple.second
                    |> List.map (Tree.mapValues (\b -> { b | properties = Dict.remove "label" b.properties }))
                    |> HTML.Block.forest
                    |> Expect.all
                        [ contains "<h3 class=\"xm-section\" data-level=\"2\" id=\"results\">"
                        , contains "Results</h3>"
                        , lacks "xm-section-number"
                        ]
        , test "section with a label shows its number" <|
            \_ ->
                XMarkdown.Compiler.parseFromString "## Results"
                    |> List.map (Tree.mapValues (\b -> { b | properties = Dict.insert "label" "1.1" b.properties }))
                    |> HTML.Block.forest
                    |> contains "<span class=\"xm-section-number\">1.1</span> Results"
        , test "heading tag is capped at h6" <|
            \_ -> block "###### Deep" |> contains "<h6 class=\"xm-section\" data-level=\"6\""
        , test "compact bullet list, nested" <|
            \_ ->
                block "- a\n  - b\n- c"
                    |> Expect.equal "<ul class=\"xm-list\"><li>a<ul class=\"xm-list\"><li>b</li></ul></li><li>c</li></ul>"
        , test "compact numbered list" <|
            \_ -> block ". one\n. two" |> String.startsWith "<ol class=\"xm-list\"><li>one</li>" |> Expect.equal True
        , test "loose list: one list, child nested in the first item" <|
            \_ ->
                block "- a\n\n  - nested\n\n- b"
                    |> Expect.all
                        [ String.startsWith "<ul" >> Expect.equal True
                        , String.indexes "<ul class=\"xm-list\">" >> List.length >> Expect.equal 2
                        , contains "nested"
                        , contains "<li>b"
                        ]
        , test "quotation: an empty > line splits paragraphs" <|
            \_ ->
                block "> a\n>\n> b"
                    |> Expect.equal "<blockquote class=\"xm-quotation\"><p>a</p><p>b</p></blockquote>"
        , test "verse keeps lines, indentation and blank lines" <|
            \_ ->
                block "/begin verse\nRoses *red*,\n    violets\n\nSugar\n/end verse"
                    |> Expect.all
                        [ contains "<div class=\"xm-verse\">"
                        , contains "<div class=\"xm-verse-line\">Roses <em>red</em>,</div>"
                        , contains "<div class=\"xm-verse-line\" style=\"padding-left:2em\">violets</div>"
                        , contains "<div class=\"xm-verse-blank\"></div>"
                        ]
        , test "GFM table with header and alignments" <|
            \_ ->
                block "| A | B |\n|:--|--:|\n| 1 | 2 |"
                    |> contains "<table class=\"xm-table\"><thead><tr><th style=\"text-align:left\">A</th><th style=\"text-align:right\">B</th></tr></thead><tbody><tr><td style=\"text-align:left\">1</td>"
        , test "a paragraph that is only an image is a figure" <|
            \_ ->
                block "![Robin](https://x.com/a.jpg)"
                    |> Expect.equal "<figure class=\"xm-figure\"><img class=\"xm-image\" src=\"https://x.com/a.jpg\" alt=\"Robin\"><figcaption>Robin</figcaption></figure>"
        , test "a figure without a caption has no figcaption" <|
            \_ -> block "![width:300](https://x.com/a.jpg)" |> Expect.equal "<figure class=\"xm-figure\"><img class=\"xm-image\" src=\"https://x.com/a.jpg\" alt=\"\" width=\"300\"></figure>"
        , test "horizontal rule" <|
            \_ -> block "---" |> Expect.equal "<hr class=\"xm-hrule\">"
        , test "code block with language, escaped" <|
            \_ ->
                block "```elm\nx = a < b\n```"
                    |> Expect.equal "<pre class=\"xm-code\"><code class=\"language-elm\">x = a &lt; b</code></pre>"
        , test "code block without language" <|
            \_ -> block "```\nx\n```" |> Expect.equal "<pre class=\"xm-code\"><code>x</code></pre>"
        , test "display math goes through ETeX" <|
            \_ ->
                block "$$\nsqrt(2)\n$$"
                    |> Expect.equal "<div class=\"xm-math\" data-display=\"true\">\\sqrt{2}</div>"
        , test "equation, unnumbered" <|
            \_ ->
                block "| equation\nx^2"
                    |> Expect.equal "<div class=\"xm-equation\"><div class=\"xm-math\" data-display=\"true\">x^2</div></div>"
        , test "aligned" <|
            \_ ->
                block "| aligned\na &= b \\\\\nc &= d"
                    |> Expect.all [ contains "\\begin{aligned}", contains "\\end{aligned}" ]
        , test "chem" <|
            \_ -> block "| chem\nH2O" |> contains "data-display=\"true\">\\ce{H2O}</div>"
        , test "/begin NAME block" <|
            \_ ->
                block "/begin theorem\nAll *x*.\n/end theorem"
                    |> Expect.equal "<div class=\"xm-block xm-theorem\">All <em>x</em>.</div>"
        , test "the title block itself emits nothing" <|
            \_ -> block "%title T\n\nHi." |> Expect.equal "<p class=\"xm-paragraph\">Hi.</p>"
        ]

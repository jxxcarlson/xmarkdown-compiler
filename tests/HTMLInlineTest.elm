module HTMLInlineTest exposing (suite)

import AST.Language exposing (Expr(..), emptyExprMeta)
import Either exposing (Either(..))
import Expect
import HTML.Inline
import RoseTree.Tree as Tree
import Test exposing (Test, describe, test)
import XMarkdown.Compiler


{-| The inline HTML of a one-paragraph document.
-}
inline : String -> String
inline source =
    case XMarkdown.Compiler.parseFromString source |> List.map Tree.value of
        [ block ] ->
            case block.body of
                Right exprs ->
                    HTML.Inline.exprs exprs |> String.trim

                Left str ->
                    "Left: " ++ str

        blocks ->
            "expected one block, got " ++ String.fromInt (List.length blocks)


contains : String -> String -> Expect.Expectation
contains fragment output =
    String.contains fragment output
        |> Expect.equal True
        |> Expect.onFail ("expected to contain " ++ fragment ++ "\n\nin\n\n" ++ output)


suite : Test
suite =
    describe "HTML.Inline"
        [ test "text is escaped" <|
            \_ -> inline "a < b" |> Expect.equal "a &lt; b"
        , test "bold and italic" <|
            \_ -> inline "**b** and *i*" |> Expect.equal "<strong>b</strong> and <em>i</em>"
        , test "link" <|
            \_ -> inline "[NYT](https://n.com)" |> Expect.equal "<a href=\"https://n.com\">NYT</a>"
        , test "link label and url are escaped" <|
            \_ ->
                inline "[say \"hi\"](https://n.com?a=1&b=2)"
                    |> Expect.all
                        [ contains "href=\"https://n.com?a=1&amp;b=2\""
                        , contains ">say &quot;hi&quot;</a>"
                        ]
        , test "inline code is escaped" <|
            \_ -> inline "`a<b`" |> Expect.equal "<code>a&lt;b</code>"
        , test "inline math goes through ETeX" <|
            \_ ->
                inline "$sqrt(2)$"
                    |> Expect.equal "<span class=\"xm-math\" data-display=\"false\">\\sqrt{2}</span>"
        , test "math source is escaped" <|
            \_ -> inline "$a<b$" |> contains ">a&lt;b</span>"
        , test "a formula ETeX rejects is still shown" <|
            \_ ->
                inline "$a\\:b$"
                    |> Expect.all [ contains "class=\"xm-math\"", contains "a\\:b" ]
        , test "empty inline math emits nothing" <|
            \_ -> inline "a $$ b" |> Expect.equal "a  b"
        , test "image with caption and width" <|
            \_ ->
                inline "![Robin <1> width:400](https://x.com/a.jpg)"
                    |> Expect.equal "<img class=\"xm-image\" src=\"https://x.com/a.jpg\" alt=\"Robin &lt;1&gt;\" width=\"400\">"
        , test "unknown function is marked unsupported" <|
            \_ ->
                HTML.Inline.exprs [ Fun "frobnicate" [ Text "x" emptyExprMeta ] emptyExprMeta ]
                    |> Expect.equal "<span class=\"xm-unsupported\" data-name=\"frobnicate\">x</span>"
        , test "a javascript: link does not reach the page" <|
            \_ -> inline "[click](javascript:alert%281%29)" |> Expect.equal "<a href=\"#\">click</a>"
        , test "a JavaScript: link in any case does not reach the page" <|
            \_ -> inline "[click](JavaScript:alert)" |> Expect.equal "<a href=\"#\">click</a>"
        , test "mailto and relative links are kept" <|
            \_ ->
                inline "[a](mailto:x@y.com) [b](notes.html#s)"
                    |> Expect.all [ contains "href=\"mailto:x@y.com\"", contains "href=\"notes.html#s\"" ]
        , test "a javascript: image source does not reach the page" <|
            \_ -> inline "![x](javascript:alert)" |> Expect.equal "<img class=\"xm-image\" src=\"\" alt=\"x\">"
        ]

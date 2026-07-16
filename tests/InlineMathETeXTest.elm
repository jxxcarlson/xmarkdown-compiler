module InlineMathETeXTest exposing (suite)

{-| Inline math (`$...$` in prose and in table cells) must run the ETeX -> LaTeX
transform before handing content to KaTeX, exactly as block math does
(Render.Math.getMathContent). Regression test for the table cell `$sqrt(2)$`
rendering as literal "sqrt(2)" instead of \sqrt{2}.
-}

import AST.Language exposing (Expr(..))
import Expect
import Html.Attributes
import Render.Expression
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import XMarkdown.Types exposing (Theme(..))


renderInlineMath : String -> Query.Single XMarkdown.Types.MarkupMsg
renderInlineMath content =
    Render.Expression.render Light [] (VFun "math" content { begin = 0, end = 0, id = "e-0.0", index = 0 })
        |> Query.fromHtml


expectDataContent : String -> Query.Single XMarkdown.Types.MarkupMsg -> Expect.Expectation
expectDataContent expected query =
    Query.has [ Selector.attribute (Html.Attributes.attribute "data-content" expected) ] query


suite : Test
suite =
    describe "inline math applies the ETeX transform"
        [ test "sqrt(2) becomes \\sqrt{2}" <|
            \_ ->
                renderInlineMath "sqrt(2)"
                    |> expectDataContent "\\sqrt{2}"
        , test "n! is unchanged (already LaTeX)" <|
            \_ ->
                renderInlineMath "n!"
                    |> expectDataContent "n!"
        , test "3:2 is unchanged (already LaTeX)" <|
            \_ ->
                renderInlineMath "3:2"
                    |> expectDataContent "3:2"
        ]

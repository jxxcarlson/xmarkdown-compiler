module DisplayMathSpacingTest exposing (suite)

{-| Display math was surrounded by too much space, more above (52px) than
below (34px): the math-text element was inline, so the browser added a line
box on each side of KaTeX's block, and the paragraph above adds its 18px
bottom margin. The element is now a block whose margins combine with KaTeX's
16px .katex-display margin to give about 22px on each side.
-}

import Expect
import Html
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import XMarkdown.API
import XMarkdown.Types


mathElement : String -> Query.Single XMarkdown.Types.MarkupMsg
mathElement src =
    XMarkdown.API.compileString XMarkdown.API.defaultCompilerParameters src
        |> Html.div []
        |> Query.fromHtml
        |> Query.find [ Selector.tag "math-text" ]


displayStyles : Query.Single XMarkdown.Types.MarkupMsg -> Expect.Expectation
displayStyles =
    Query.has
        [ Selector.style "display" "block"
        , Selector.style "margin" "-12px 0 22px 0"
        , Selector.style "padding" "0"
        ]


suite : Test
suite =
    describe "display math spacing"
        [ test "$$ math is a block with balanced margins" <|
            \_ -> mathElement "Above.\n\n$$\nx^2\n$$\n\nBelow." |> displayStyles
        , test "\\[ math is the same" <|
            \_ -> mathElement "Above.\n\n\\[\nx^2\n\\]\n\nBelow." |> displayStyles
        , test "equation blocks are the same" <|
            \_ -> mathElement "| equation\nx^2" |> displayStyles
        , test "aligned blocks are the same" <|
            \_ -> mathElement "| aligned\na &= b" |> displayStyles
        , test "inline math is not affected" <|
            \_ ->
                mathElement "Inline $x^2$ here."
                    |> Query.hasNot [ Selector.style "display" "block" ]
        ]

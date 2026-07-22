module TreeIndentTest exposing (suite)

{-| Indentation of rendered blocks is relative: every node at depth > 0 gets
one constant unit (12px) of left padding on its own container, and deeper
nesting accumulates through the containment of child divs inside their
parent's div. So a block indented two levels sits at 24px absolute, but no
element ever carries more than one unit itself.

Regression test for a nested paragraph chain (indents 0, 2, 4) where the
middle block — a branch node, since it has a child — lost its indentation
entirely, because padding was applied only to leaf nodes.

-}

import Expect
import Html
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import XMarkdown.API
import XMarkdown.Types


render : String -> Query.Single XMarkdown.Types.MarkupMsg
render source =
    XMarkdown.API.compileString XMarkdown.API.defaultCompilerParameters source
        |> Html.div []
        |> Query.fromHtml


unit : Selector.Selector
unit =
    Selector.style "padding-left" "12px"


suite : Test
suite =
    describe "relative depth indentation"
        [ test "two blocks (indents 0, 2): the nested block carries one unit" <|
            \_ ->
                render "Oranges A\n\n  Oranges B\n"
                    |> Query.findAll [ unit ]
                    |> Query.count (Expect.equal 1)
        , test "three blocks (indents 0, 2, 4): each nested node carries one unit" <|
            \_ ->
                render "Oranges A\n\n  Oranges B\n\n    Oranges C\n"
                    |> Query.findAll [ unit ]
                    |> Query.count (Expect.equal 2)
        , test "three blocks: no node carries a multiplied unit" <|
            \_ ->
                render "Oranges A\n\n  Oranges B\n\n    Oranges C\n"
                    |> Query.findAll [ Selector.style "padding-left" "24px" ]
                    |> Query.count (Expect.equal 0)
        ]

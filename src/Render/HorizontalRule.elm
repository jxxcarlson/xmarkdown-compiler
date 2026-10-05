module Render.HorizontalRule exposing (render)

{-| A horizontal rule (`---`, `***`, `___`): a thin line across the text
column. Text on lines after the rule in the same block (no blank line in
between) is kept and rendered below it as a paragraph.
-}

import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock)
import Either exposing (Either(..))
import Html exposing (Html)
import Html.Attributes
import Render.Expression
import Render.Theme exposing (RenderSettings)
import XMarkdown.Types exposing (MarkupMsg)


render : Int -> Accumulator -> Int -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
render count _ depth settings _ block =
    let
        rest =
            case block.body of
                Right [] ->
                    []

                Right exprs ->
                    [ Html.p [] (List.map (Render.Expression.render settings.theme depth []) exprs) ]

                Left _ ->
                    []
    in
    Html.div
        [ Html.Attributes.id ("e-" ++ String.fromInt block.meta.lineNumber ++ "." ++ String.fromInt count)
        , Html.Attributes.attribute "data-line-number" (String.fromInt block.meta.lineNumber)
        , Html.Attributes.style "width" "100%"
        ]
        (Html.hr
            [ Html.Attributes.style "border" "none"
            , Html.Attributes.style "border-top" "1px solid currentColor"
            , Html.Attributes.style "opacity" "0.35"
            , Html.Attributes.style "margin" "1.25em 0"
            ]
            []
            :: rest
        )

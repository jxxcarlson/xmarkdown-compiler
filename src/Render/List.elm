module Render.List exposing (desc, item, numbered)

import Html exposing (Html)
import Html.Attributes
import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock)
import Render.Settings exposing (RenderSettings)
import XMarkdown.Types exposing (MarkupMsg)


{-| Render a list item
-}
item : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
item count acc settings attr block =
    let
        level = block.indent // 2
        indentation = 15 * level
    in
    Html.li
        ([ Html.Attributes.style "margin-left" (String.fromInt indentation ++ "px")
         , Html.Attributes.id block.meta.id
         ]
            ++ attr
        )
        [ Html.text "• list item" ]


{-| Render a numbered list item
-}
numbered : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
numbered count acc settings attr block =
    let
        level = block.indent // 2
        indentation = 15 * level
    in
    Html.li
        ([ Html.Attributes.style "margin-left" (String.fromInt indentation ++ "px")
         , Html.Attributes.id block.meta.id
         ]
            ++ attr
        )
        [ Html.text "1. list item" ]


{-| Render a description list item
-}
desc : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
desc count acc settings attr block =
    Html.dd
        ([ Html.Attributes.id block.meta.id
         ]
            ++ attr
        )
        [ Html.text "description item" ]

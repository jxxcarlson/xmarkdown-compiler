module Render.List exposing (desc, item, numbered)

import Html exposing (Html)
import Html.Attributes
import Either
import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock)
import Render.Expression
import Render.Theme exposing (RenderSettings)
import XMarkdown.Types exposing (MarkupMsg)


{-| Render a list item
-}
item : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
item count acc settings attr block =
    let
        level = block.indent // 2
        indentation = 15 * level

        content =
            case block.body of
                Either.Right exprs ->
                    List.map (Render.Expression.render count acc settings attr) exprs

                Either.Left _ ->
                    [ Html.text "" ]
    in
    Html.li
        ([ Html.Attributes.style "margin-left" (String.fromInt indentation ++ "px")
         , Html.Attributes.id block.meta.id
         ]
            ++ attr
        )
        content


{-| Render a numbered list item
-}
numbered : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
numbered count acc settings attr block =
    let
        level = block.indent // 2
        indentation = 15 * level

        content =
            case block.body of
                Either.Right exprs ->
                    List.map (Render.Expression.render count acc settings attr) exprs

                Either.Left _ ->
                    [ Html.text "" ]
    in
    Html.li
        ([ Html.Attributes.style "margin-left" (String.fromInt indentation ++ "px")
         , Html.Attributes.id block.meta.id
         ]
            ++ attr
        )
        content


{-| Render a description list item
-}
desc : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
desc count acc settings attr block =
    let
        content =
            case block.body of
                Either.Right exprs ->
                    List.map (Render.Expression.render count acc settings attr) exprs

                Either.Left _ ->
                    [ Html.text "" ]
    in
    Html.dd
        ([ Html.Attributes.id block.meta.id
         ]
            ++ attr
        )
        content

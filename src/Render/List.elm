module Render.List exposing (desc, item, numbered)

import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock)
import Either
import Html exposing (Html)
import Html.Attributes
import Render.Expression
import Render.Theme exposing (RenderSettings)
import XMarkdown.Types exposing (MarkupMsg)


{-| Render a list item
-}
item : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
item count _ _ attr block =
    let
        level =
            block.indent // 2

        indentation =
            15 * level

        blockId =
            "e-" ++ String.fromInt block.meta.lineNumber ++ "." ++ String.fromInt count

        content =
            case block.body of
                Either.Right exprs ->
                    List.map (Render.Expression.render attr) exprs

                Either.Left _ ->
                    [ Html.text "" ]
    in
    Html.li
        ([ Html.Attributes.style "margin-left" (String.fromInt indentation ++ "px")
         , Html.Attributes.id blockId
         , Html.Attributes.attribute "data-line-number" (String.fromInt block.meta.lineNumber)
         ]
            ++ attr
        )
        content


{-| Render a numbered list item
-}
numbered : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
numbered count _ _ attr block =
    let
        level =
            block.indent // 2

        indentation =
            15 * level

        blockId =
            "e-" ++ String.fromInt block.meta.lineNumber ++ "." ++ String.fromInt count

        content =
            case block.body of
                Either.Right exprs ->
                    List.map (Render.Expression.render attr) exprs

                Either.Left _ ->
                    [ Html.text "" ]
    in
    Html.li
        ([ Html.Attributes.style "margin-left" (String.fromInt indentation ++ "px")
         , Html.Attributes.id blockId
         , Html.Attributes.attribute "data-line-number" (String.fromInt block.meta.lineNumber)
         ]
            ++ attr
        )
        content


{-| Render a description list item
-}
desc : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
desc count _ _ attr block =
    let
        blockId =
            "e-" ++ String.fromInt block.meta.lineNumber ++ "." ++ String.fromInt count

        content =
            case block.body of
                Either.Right exprs ->
                    List.map (Render.Expression.render attr) exprs

                Either.Left _ ->
                    [ Html.text "" ]
    in
    Html.dd
        ([ Html.Attributes.id blockId
         , Html.Attributes.attribute "data-line-number" (String.fromInt block.meta.lineNumber)
         ]
            ++ attr
        )
        content

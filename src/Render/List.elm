module Render.List exposing (desc, item, numbered)

import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock)
import Dict
import Either
import Html exposing (Html)
import Html.Attributes
import Render.Expression
import Render.Theme exposing (RenderSettings)
import XMarkdown.Types exposing (MarkupMsg)


numberToLetter : Int -> String
numberToLetter n =
    if n > 0 && n <= 26 then
        String.fromChar (Char.fromCode (96 + n))
    else
        String.fromInt n


numberToRoman : Int -> String
numberToRoman n =
    let
        romanPairs =
            [ ( 1000, "m" ), ( 900, "cm" ), ( 500, "d" ), ( 400, "cd" ), ( 100, "c" ), ( 90, "xc" ), ( 50, "l" ), ( 40, "xl" ), ( 10, "x" ), ( 9, "ix" ), ( 5, "v" ), ( 4, "iv" ), ( 1, "i" ) ]

        toRoman num pairs =
            case pairs of
                [] ->
                    ""

                ( value, numeral ) :: rest ->
                    if num >= value then
                        numeral ++ toRoman (num - value) pairs
                    else
                        toRoman num rest
    in
    toRoman n romanPairs


formatListNumber : Int -> Int -> String
formatListNumber level number =
    case level of
        0 ->
            String.fromInt number

        1 ->
            numberToLetter number

        _ ->
            numberToRoman number


{-| Render a list item
-}
item : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
item count _ settings attr block =
    let
        level =
            block.indent // 2

        indentation =
            if level >= 3 then
                0
            else
                settings.leftIndentation

        blockId =
            "e-" ++ String.fromInt block.meta.lineNumber ++ "." ++ String.fromInt count

        bulletStyle =
            case level of
                0 ->
                    "disc"

                1 ->
                    "circle"

                _ ->
                    "none"

        content =
            case block.body of
                Either.Right exprs ->
                    List.map (Render.Expression.render attr) exprs

                Either.Left _ ->
                    [ Html.text "" ]

        finalContent =
            if level >= 2 then
                [ Html.span [ Html.Attributes.style "font-size" "0.67em" ] [ Html.text "□" ], Html.text " " ] ++ content
            else
                content
    in
    Html.li
        ([ Html.Attributes.style "margin-left" (String.fromInt (6 + indentation) ++ "px")
         , Html.Attributes.style "margin-bottom" (String.fromInt settings.listSpacing ++ "px")
         , Html.Attributes.style "width" (String.fromInt (settings.width - (6 + indentation)) ++ "px")
         , Html.Attributes.style "list-style-type" bulletStyle
         , Html.Attributes.id blockId
         , Html.Attributes.attribute "data-line-number" (String.fromInt block.meta.lineNumber)
         ]
            ++ attr
        )
        finalContent


{-| Render a numbered list item
-}
numbered : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
numbered count acc settings attr block =
    let
        level =
            block.indent // 2

        indentation =
            if level >= 3 then
                0
            else
                settings.leftIndentation

        blockId =
            "e-" ++ String.fromInt block.meta.lineNumber ++ "." ++ String.fromInt count

        itemNumber =
            Dict.get block.meta.id acc.numberedItemDict
                |> Maybe.map .index
                |> Maybe.withDefault 1

        content =
            case block.body of
                Either.Right exprs ->
                    List.map (Render.Expression.render attr) exprs

                Either.Left _ ->
                    [ Html.text "" ]

        formattedNumber =
            formatListNumber level itemNumber

        prefixedContent =
            [ Html.text (formattedNumber ++ ". ") ] ++ content
    in
    Html.li
        ([ Html.Attributes.style "margin-left" (String.fromInt (6 + indentation) ++ "px")
         , Html.Attributes.style "margin-bottom" (String.fromInt settings.listSpacing ++ "px")
         , Html.Attributes.style "width" (String.fromInt (settings.width - (6 + indentation)) ++ "px")
         , Html.Attributes.style "list-style" "none"
         , Html.Attributes.id blockId
         , Html.Attributes.attribute "data-line-number" (String.fromInt block.meta.lineNumber)
         ]
            ++ attr
        )
        prefixedContent


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

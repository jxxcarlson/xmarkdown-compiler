module Render.Blocks.Document exposing (registerRenderers)

import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock)
import Dict
import Either
import Html exposing (Html)
import Html.Attributes
import Render.BlockRegistry exposing (BlockRegistry)
import Render.Expression
import Render.Theme exposing (RenderSettings)
import XMarkdown.Types exposing (MarkupMsg)


{-| Register all document structure block renderers to the registry
-}
registerRenderers : BlockRegistry -> BlockRegistry
registerRenderers registry =
    Render.BlockRegistry.registerBatch
        [ ( "section", section )
        , ( "section*", unnumberedSection )
        ]
        registry


{-| Render a section heading
-}
section : Int -> Accumulator -> Int -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
section count _ depth settings attr block =
    let
        level : Int
        level =
            Dict.get "level" block.properties
                |> Maybe.andThen String.toInt
                |> Maybe.withDefault 2

        headingElement =
            case level of
                1 ->
                    Html.h1

                2 ->
                    Html.h2

                3 ->
                    Html.h3

                4 ->
                    Html.h4

                5 ->
                    Html.h5

                _ ->
                    Html.h6

        sectionNumber : Maybe String
        sectionNumber =
            if settings.numberToLevel > 0 && level <= settings.numberToLevel then
                Dict.get "label" block.properties

            else
                Nothing
    in
    let
        contentExprs =
            case block.body of
                Either.Right exprs ->
                    List.map (Render.Expression.render settings.theme depth attr) exprs

                Either.Left _ ->
                    [ Html.text "" ]

        content =
            case sectionNumber of
                Just num ->
                    Html.span [ Html.Attributes.style "margin-right" "8px" ] [ Html.text (num ++ " ") ] :: contentExprs

                Nothing ->
                    contentExprs
    in
    headingElement
        (attr
            ++ [ Html.Attributes.id ("e-" ++ String.fromInt block.meta.lineNumber ++ "." ++ String.fromInt count)
               , Html.Attributes.attribute "data-line-number" (String.fromInt block.meta.lineNumber)
               , Html.Attributes.style "margin-top" "16px"
               , Html.Attributes.style "margin-bottom" "12px"
               , Html.Attributes.style "font-weight" "400"
               ]
        )
        content


{-| Render an unnumbered section heading
-}
unnumberedSection : Int -> Accumulator -> Int -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
unnumberedSection count acc depth settings attr block =
    section count acc depth settings attr block

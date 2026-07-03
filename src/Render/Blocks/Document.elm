module Render.Blocks.Document exposing (registerRenderers)

import Html exposing (Html)
import Html.Attributes
import Either
import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock)
import Dict
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
section : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
section count acc settings attr block =
    let
        level : Int
        level =
            Dict.get "level" block.properties
                |> Maybe.andThen String.toInt
                |> Maybe.withDefault 2

        headingElement =
            case level of
                1 -> Html.h1
                2 -> Html.h2
                3 -> Html.h3
                4 -> Html.h4
                5 -> Html.h5
                _ -> Html.h6
    in
    let
        content =
            case block.body of
                Either.Right exprs ->
                    List.map (Render.Expression.render count acc settings attr) exprs

                Either.Left _ ->
                    [ Html.text "" ]
    in
    headingElement
        (attr
            ++ [ Html.Attributes.id ("e-" ++ String.fromInt block.meta.lineNumber ++ ".0")
               , Html.Attributes.style "margin-top" "16px"
               , Html.Attributes.style "margin-bottom" "8px"
               ]
        )
        content


{-| Render an unnumbered section heading
-}
unnumberedSection : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
unnumberedSection count acc settings attr block =
    section count acc settings attr block

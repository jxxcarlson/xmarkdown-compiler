module Render.Blocks.Container exposing (registerRenderers)

import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock)
import Either
import Html exposing (Html)
import Html.Attributes
import Render.BlockRegistry exposing (BlockRegistry)
import Render.Expression
import Render.List
import Render.Theme exposing (RenderSettings)
import XMarkdown.Types exposing (MarkupMsg)


registerRenderers : BlockRegistry -> BlockRegistry
registerRenderers registry =
    Render.BlockRegistry.registerBatch
        [ ( "itemList", itemList )
        , ( "numberedList", numberedList )
        , ( "descriptionList", descriptionList )
        ]
        registry


makeItem : RenderSettings -> Int -> Html MarkupMsg -> Html MarkupMsg
makeItem settings depth x =
    Html.div
        [ Html.Attributes.style "display" "flex"
        , Html.Attributes.style "align-items" "flex-start"
        , Html.Attributes.style "margin-bottom" "4px"
        , Html.Attributes.style "gap" "8px"
        , Html.Attributes.style "paddingLeft" (String.fromInt (depth * settings.leftIndentation) ++ "px")
        ]
        [ Html.div
            [ Html.Attributes.style "flex-shrink" "0"
            , Html.Attributes.style "display" "flex"
            , Html.Attributes.style "align-items" "center"
            , Html.Attributes.style "height" "1.4em"
            ]
            [ Render.List.bulletSymbol settings.theme depth ]
        , Html.div
            [ Html.Attributes.style "flex-grow" "1"
            , Html.Attributes.style "line-height" "1.4"
            ]
            [ x ]
        ]


{-| Render an item list
-}
itemList : Int -> Accumulator -> Int -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
itemList _ _ depth settings attrs block =
    let
        content =
            case block.body of
                Either.Right exprs ->
                    let
                        lev expr =
                            case expr of
                                AST.Language.ExprList k _ _ ->
                                    k // 2

                                _ ->
                                    0

                        levels =
                            List.map lev exprs

                        renderItem : Int -> AST.Language.Expression -> Html MarkupMsg
                        renderItem lev_ expr_ =
                            (Render.Expression.render settings.theme depth attrs >> makeItem settings lev_) expr_
                    in
                    Html.div [] (List.map2 renderItem levels exprs)

                Either.Left _ ->
                    Html.text ""
    in
    Html.div
        [ Html.Attributes.style "flex-grow" "1"
        ]
        [ content ]


{-| Render a numbered list
-}
numberedList : Int -> Accumulator -> Int -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
numberedList _ _ depth settings attrs block =
    let
        content =
            case block.body of
                Either.Right exprs ->
                    List.map (Render.Expression.render settings.theme depth attrs >> makeItem settings depth) exprs

                Either.Left _ ->
                    [ Html.text "" ]
    in
    -- Html.ol attrs [ Html.li [] content ]
    Html.ol attrs content


{-| Render a description list
-}
descriptionList : Int -> Accumulator -> Int -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
descriptionList _ _ depth settings attrs block =
    let
        content =
            case block.body of
                Either.Right exprs ->
                    List.map (Render.Expression.render settings.theme depth attrs) exprs

                Either.Left _ ->
                    [ Html.text "" ]
    in
    Html.dl attrs [ Html.dt [] content ]

module Render.Blocks.Container exposing (registerRenderers)

import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock)
import Either
import Html exposing (Html)
import Html.Attributes
import Render.BlockRegistry exposing (BlockRegistry)
import Render.Expression
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


makeItem : Html msg -> Html msg
makeItem x =
    Html.li [ Html.Attributes.style "margin-bottom" "4px" ] [ x ]


{-| Render an item list
-}
itemList : Int -> Accumulator -> Int -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
itemList _ _ _ settings attrs block =
    let
        content =
            case block.body of
                Either.Right exprs ->
                    List.map (Render.Expression.render settings.theme attrs >> makeItem) exprs

                Either.Left _ ->
                    [ Html.text "" ]
    in
    Html.div
        [ Html.Attributes.style "margin-left" "36px"
        , Html.Attributes.style "margin-bottom" "24px"
        ]
        content


{-| Render a numbered list
-}
numberedList : Int -> Accumulator -> Int -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
numberedList _ _ _ settings attrs block =
    let
        content =
            case block.body of
                Either.Right exprs ->
                    List.map (Render.Expression.render settings.theme attrs >> makeItem) exprs

                Either.Left _ ->
                    [ Html.text "" ]
    in
    -- Html.ol attrs [ Html.li [] content ]
    Html.ol attrs content


{-| Render a description list
-}
descriptionList : Int -> Accumulator -> Int -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
descriptionList _ _ _ settings attrs block =
    let
        content =
            case block.body of
                Either.Right exprs ->
                    List.map (Render.Expression.render settings.theme attrs) exprs

                Either.Left _ ->
                    [ Html.text "" ]
    in
    Html.dl attrs [ Html.dt [] content ]

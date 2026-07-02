module Render.Blocks.Container exposing (registerRenderers)

import Html exposing (Html)
import Html.Attributes
import Either
import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock)
import Render.BlockRegistry exposing (BlockRegistry)
import Render.Expression
import Render.Settings exposing (RenderSettings)
import XMarkdown.Types exposing (MarkupMsg)


{-| Register all container block renderers to the registry
-}
registerRenderers : BlockRegistry -> BlockRegistry
registerRenderers registry =
    Render.BlockRegistry.registerBatch
        [ ( "itemList", itemList )
        , ( "numberedList", numberedList )
        , ( "descriptionList", descriptionList )
        ]
        registry


{-| Render an item list
-}
itemList : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
itemList count acc settings attrs block =
    let
        content =
            case block.body of
                Either.Right exprs ->
                    List.map (Render.Expression.render count acc settings attrs) exprs
                Either.Left _ ->
                    [ Html.text "" ]
    in
    Html.ul attrs [ Html.li [] content ]


{-| Render a numbered list
-}
numberedList : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
numberedList count acc settings attrs block =
    let
        content =
            case block.body of
                Either.Right exprs ->
                    List.map (Render.Expression.render count acc settings attrs) exprs
                Either.Left _ ->
                    [ Html.text "" ]
    in
    Html.ol attrs [ Html.li [] content ]


{-| Render a description list
-}
descriptionList : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
descriptionList count acc settings attrs block =
    let
        content =
            case block.body of
                Either.Right exprs ->
                    List.map (Render.Expression.render count acc settings attrs) exprs
                Either.Left _ ->
                    [ Html.text "" ]
    in
    Html.dl attrs [ Html.dt [] content ]

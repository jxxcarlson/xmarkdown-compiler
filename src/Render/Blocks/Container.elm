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
itemList _ _ settings attrs block =
    let
        content =
            case block.body of
                Either.Right exprs ->
                    List.map (Render.Expression.render attrs) exprs

                Either.Left _ ->
                    [ Html.text "" ]

        indentPx =
            String.fromInt settings.leftIndentation ++ "px"
    in
    Html.div
        [ Html.Attributes.style "margin-left" indentPx
        ]
        [ Html.ul
            (attrs
                ++ [ Html.Attributes.style "padding-left" "24px"
                   , Html.Attributes.style "margin-left" "0"
                   ]
            )
            [ Html.li [] content ]
        ]


{-| Render a numbered list
-}
numberedList _ _ settings attrs block =
    let
        content =
            case block.body of
                Either.Right exprs ->
                    List.map (Render.Expression.render attrs) exprs

                Either.Left _ ->
                    [ Html.text "" ]

        indentPx =
            String.fromInt settings.leftIndentation ++ "px"
    in
    Html.div
        [ Html.Attributes.style "margin-left" indentPx
        ]
        [ Html.ol
            (attrs
                ++ [ Html.Attributes.style "padding-left" "24px"
                   , Html.Attributes.style "margin-left" "0"
                   , Html.Attributes.style "list-style" "none"
                   ]
            )
            [ Html.li [] content ]
        ]


{-| Render a description list
-}
descriptionList : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
descriptionList _ _ _ attrs block =
    let
        content =
            case block.body of
                Either.Right exprs ->
                    List.map (Render.Expression.render attrs) exprs

                Either.Left _ ->
                    [ Html.text "" ]
    in
    Html.dl attrs [ Html.dt [] content ]

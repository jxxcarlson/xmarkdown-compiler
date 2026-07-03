module Render.Blocks.Text exposing (registerRenderers)

{-| This module provides renderers for text-related blocks.

@docs registerRenderers

-}

import Dict
import Html exposing (Html)
import Html.Attributes
import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock)
import Render.BlockRegistry exposing (BlockRegistry)
import Render.Helper
import Render.Theme exposing (RenderSettings)
import Render.Sync
import XMarkdown.Types exposing (MarkupMsg)


{-| Register all text block renderers to the registry
-}
registerRenderers : BlockRegistry -> BlockRegistry
registerRenderers registry =
    Render.BlockRegistry.registerBatch
        [ ( "quotation", quotation )
        ]
        registry


{-| Render a quotation block (returns Html)
-}
quotation : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
quotation count acc settings attrs block =
    let
        content =
            Dict.get "firstLine" block.properties
                |> Maybe.map (\text -> [ Html.text text ])
                |> Maybe.withDefault []
    in
    Html.div
        [ Html.Attributes.style "display" "flex"
        , Html.Attributes.style "width" "100%"
        , Html.Attributes.id block.meta.id
        ]
        [ Html.div [ Html.Attributes.style "width" "40px" ] []
        , Html.p
            [ Html.Attributes.style "font-style" "italic"
            ]
            content
        ]

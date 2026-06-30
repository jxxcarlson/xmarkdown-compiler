module Render.Blocks.Text exposing (registerRenderers)

{-| This module provides renderers for text-related blocks.

@docs registerRenderers

-}

import Dict
import Element exposing (Element)
import Element.Font as Font
import Element.Background
import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock)
import Render.BlockRegistry exposing (BlockRegistry)
import Render.Helper
import Render.Settings exposing (RenderSettings)
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


{-| Render a quotation block
-}
quotation : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
quotation count acc settings attrs block =
    let
        content =
            Dict.get "firstLine" block.properties
                |> Maybe.map (\text -> [ Element.text text ])
                |> Maybe.withDefault []
    in
    Element.row
        [ Element.width Element.fill
        , Render.Helper.htmlId block.meta.id
        ]
        [ Element.el [ Element.width (Element.px 40) ] Element.none
        , Element.paragraph
            [ Font.italic
            ]
            content
        ]

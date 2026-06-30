module Render.Blocks.Text exposing (registerRenderers)

{-| This module provides renderers for text-related blocks.

@docs registerRenderers

-}

import Element exposing (Element)
import Element.Font as Font
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
    Element.column
        ([ Element.spacing 8
         , Element.width (Element.px (settings.width - 2 * 24))
         ]
            ++ Render.Sync.attributes settings block
        )
        [ Render.Helper.noteFromPropertyKey "title" [ Font.bold ] block
        , Element.paragraph
            (Element.centerX :: Render.Helper.blockAttributes settings block [])
            (Render.Helper.renderWithDefault "quotation" count acc settings attrs (AST.Language.getExpressionContent block))
        ]

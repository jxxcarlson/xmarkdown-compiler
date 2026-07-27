module Render.Blocks.Text exposing (registerRenderers)

{-| This module provides renderers for text-related blocks.

@docs registerRenderers

-}

import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock)
import Either exposing (Either(..))
import Html exposing (Html)
import Html.Attributes
import Render.BlockRegistry exposing (BlockRegistry)
import Render.Expression
import Render.Theme exposing (RenderSettings)
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
quotation : Int -> Accumulator -> Int -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
quotation count _ depth settings _ block =
    let
        -- Render the parsed body, not the "firstLine" property. The property
        -- holds only the block's first line as raw text, so quoting more than
        -- one line silently dropped everything after the first, and inline
        -- markup inside a quotation rendered literally ("**bold**").
        content =
            case block.body of
                Right exprs ->
                    List.map (Render.Expression.render settings.theme depth []) exprs

                Left text ->
                    [ Html.text text ]

        blockId =
            "e-" ++ String.fromInt block.meta.lineNumber ++ "." ++ String.fromInt count

        indentWidth =
            String.fromInt settings.leftIndentation ++ "px"
    in
    Html.div
        [ Html.Attributes.style "display" "flex"
        , Html.Attributes.style "width" "100%"
        , Html.Attributes.id blockId
        , Html.Attributes.attribute "data-line-number" (String.fromInt block.meta.lineNumber)
        ]
        [ Html.div [ Html.Attributes.style "width" indentWidth ] []
        , Html.p
            [ Html.Attributes.style "font-style" "italic"
            ]
            content
        ]

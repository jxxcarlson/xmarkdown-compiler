module Render.Blocks.Text exposing (registerRenderers)

{-| This module provides renderers for text-related blocks.

@docs registerRenderers

-}

import AST.Acc exposing (Accumulator)
import AST.Language exposing (Expr(..), ExpressionBlock)
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
        , ( "verse", verse )
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


{-| Render a verse block (`/begin verse ... /end verse`): one line per source
line, indented by the line's leading spaces; a blank line stays blank.
-}
verse : Int -> Accumulator -> Int -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
verse count _ depth settings _ block =
    let
        line expr =
            case expr of
                ExprList indent exprs _ ->
                    Html.div
                        [ Html.Attributes.style "padding-left" (String.fromInt indent ++ "ch")
                        , Html.Attributes.style "min-height" "1.4em"
                        ]
                        (List.map (Render.Expression.render settings.theme depth []) exprs)

                _ ->
                    Render.Expression.render settings.theme depth [] expr

        lines =
            case block.body of
                Right exprs ->
                    List.map line exprs

                Left text ->
                    [ Html.text text ]
    in
    Html.div
        [ Html.Attributes.id ("e-" ++ String.fromInt block.meta.lineNumber ++ "." ++ String.fromInt count)
        , Html.Attributes.attribute "data-line-number" (String.fromInt block.meta.lineNumber)
        , Html.Attributes.style "margin-left" (String.fromInt settings.leftIndentation ++ "px")
        , Html.Attributes.style "line-height" "1.4"
        , Html.Attributes.style "margin-bottom" "18px"
        ]
        lines

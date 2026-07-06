module Render.TreeSupport exposing (renderAttributes, renderBody)

{-| This module provides simplified versions of Block functions needed by Tree2
to avoid import cycles.

@docs renderAttributes, renderBody

-}

import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock, Heading(..))
import Dict
import Either exposing (Either(..))
import Html exposing (Html)
import Html.Attributes
import Render.Block
import Render.Sync
import Render.Theme exposing (RenderSettings)
import XMarkdown.Types exposing (MarkupMsg)


{-| Simplified version of Block.renderAttributes (now returns Html.Attribute)
-}
renderAttributes : RenderSettings -> ExpressionBlock -> List (Html.Attribute MarkupMsg)
renderAttributes settings block =
    syncAttributes settings block


{-| The standard attributes for a block are those needed for LR and RL sync
and for highlighting the block if it is selected.
-}
syncAttributes : RenderSettings -> ExpressionBlock -> List (Html.Attribute MarkupMsg)
syncAttributes settings block =
    Render.Sync.attributes settings block
        ++ [ Html.Attributes.attribute "data-line-number" (String.fromInt block.meta.lineNumber)
           ]


{-| Render block body using the real block renderer
-}
renderBody : XMarkdown.Types.CompilerParameters -> RenderSettings -> Accumulator -> ExpressionBlock -> List (Html MarkupMsg)
renderBody params settings acc block =
    renderBodyWithAttrs params settings acc (renderAttributes settings block) block


renderBodyWithAttrs : XMarkdown.Types.CompilerParameters -> RenderSettings -> Accumulator -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> List (Html MarkupMsg)
renderBodyWithAttrs params settings acc attrs block =
    let
        isHeading =
            Dict.member "level" block.properties

        spacer =
            if isHeading then
                [ Html.div [ Html.Attributes.style "height" (String.fromInt (round params.paddingAboveHeadings) ++ "px") ] [] ]

            else
                []
    in
    spacer ++ Render.Block.renderBody params.editCount acc settings attrs block


{-| Render a paragraph body (returns Html)
TODO: Phase 3+ - Implement expression rendering
-}
renderParagraphBody : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
renderParagraphBody count acc settings attrs block =
    let
        blockId = "e-" ++ String.fromInt block.meta.lineNumber ++ "." ++ String.fromInt count
    in
    case block.body of
        Right exprs ->
            Html.p (Html.Attributes.id blockId :: Html.Attributes.attribute "data-line-number" (String.fromInt block.meta.lineNumber) :: Html.Attributes.style "width" (String.fromInt settings.width ++ "px") :: attrs)
                [ Html.text "Paragraph content - TODO Phase 4" ]

        Left _ ->
            Html.text ""


{-| Helper for clickable paragraphs (returns Html)
TODO: Phase 5 - Wire up proper sync via Render.Sync module
-}
clickableParagraph : Int -> Int -> Html.Attribute MarkupMsg -> List (Html MarkupMsg) -> Html MarkupMsg
clickableParagraph lineNumber numberOfLines color elements =
    let
        id =
            String.fromInt lineNumber
    in
    Html.p
        [ Html.Attributes.id id
        , color
        ]
        elements


{-| Helper for indenting paragraphs (returns Html)
-}
indentParagraph : Int -> Html msg -> Html msg
indentParagraph indent x =
    if indent > 0 then
        Html.div [ Html.Attributes.style "margin-left" (String.fromInt (indent * 18) ++ "px") ] [ x ]

    else
        x

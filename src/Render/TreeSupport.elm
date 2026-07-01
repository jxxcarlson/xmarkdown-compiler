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
import Html.Events
import Render.Expression
import Render.Helper
import Render.Indentation
import Render.OrdinaryBlock
import Render.Settings exposing (RenderSettings)
import Render.Sync
import Render.Utility
import Render.VerbatimBlock as VerbatimBlock
import XMarkdown.Types exposing (MarkupMsg)
import XMarkdown.Types


{-| Simplified version of Block.renderAttributes (now returns Html.Attribute)
-}
renderAttributes : RenderSettings -> ExpressionBlock -> List (Html.Attribute MarkupMsg)
renderAttributes settings block =
    syncAttributes settings block


{-| The standard attributes for a block are those needed for LR and RL sync
and for highlighting the block if it is selected.
TODO: Phase 5 - Wire up proper sync via Render.Sync module
-}
syncAttributes : RenderSettings -> ExpressionBlock -> List (Html.Attribute MarkupMsg)
syncAttributes settings block =
    [ Html.Attributes.id (String.fromInt block.meta.lineNumber)
    , Html.Attributes.attribute "data-line-number" (String.fromInt block.meta.lineNumber)
    ]
        ++ (if String.fromInt block.meta.lineNumber == settings.selectedId then
                [ Html.Attributes.style "background-color" "rgba(160, 160, 255, 0.3)" ]
            else
                []
           )


{-| Simplified version of Block.renderBody (returns Html)
TODO: Phase 3+ - Implement actual block rendering
-}
renderBody : XMarkdown.Types.CompilerParameters -> RenderSettings -> Accumulator -> ExpressionBlock -> List (Html MarkupMsg)
renderBody params settings acc block =
    let
        isHeading =
            Dict.member "level" block.properties

        spacer =
            if isHeading then
                [ Html.div [ Html.Attributes.style "height" (String.fromInt (round params.paddingAboveHeadings) ++ "px") ] [] ]
            else
                []
    in
    case block.heading of
        Paragraph ->
            spacer ++ [ Html.div (renderAttributes settings block ++ [ Html.Attributes.style "padding" "8px" ]) [ renderParagraphBody params.editCount acc settings [] block ] ]

        Ordinary _ ->
            spacer ++ [ Html.div (renderAttributes settings block) [ Html.text "Ordinary block - TODO Phase 3" ] ]

        Verbatim _ ->
            spacer ++ [ Html.div (renderAttributes settings block) [ Html.text "Verbatim block - TODO Phase 3" ] ]


{-| Render a paragraph body (returns Html)
TODO: Phase 3+ - Implement expression rendering
-}
renderParagraphBody : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
renderParagraphBody count acc settings attrs block =
    case block.body of
        Right exprs ->
            Html.p (Html.Attributes.id block.meta.id :: Html.Attributes.style "width" (String.fromInt settings.width ++ "px") :: attrs)
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

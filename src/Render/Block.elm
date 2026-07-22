module Render.Block exposing (renderBody)

import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock, Heading(..))
import Either exposing (Either(..))
import Html exposing (Html)
import Html.Attributes
import Render.Expression
import Render.Helper
import Render.OrdinaryBlock
import Render.Theme exposing (RenderSettings)
import Render.VerbatimBlock as VerbatimBlock
import XMarkdown.Types exposing (MarkupMsg)


renderBody : Int -> Accumulator -> Int -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> List (Html MarkupMsg)
renderBody count acc depth settings attrs block =
    case block.heading of
        Paragraph ->
            [ renderParagraphBody count settings attrs block ]

        Ordinary _ ->
            [ Render.OrdinaryBlock.render count acc depth settings attrs block ]

        Verbatim _ ->
            [ VerbatimBlock.render count settings attrs block |> Render.Helper.showError settings.theme block.meta.error ]


renderParagraphBody : Int -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
renderParagraphBody count settings attrs block =
    case block.body of
        Right exprs ->
            Html.p
                (Html.Attributes.id ("e-" ++ String.fromInt block.meta.lineNumber ++ "." ++ String.fromInt count)
                    :: Html.Attributes.attribute "data-line-number" (String.fromInt block.meta.lineNumber)
                    :: Html.Attributes.style "width" (String.fromInt settings.width ++ "px")
                    :: Html.Attributes.style "margin" "0"
                    :: Html.Attributes.style "margin-bottom" "18px"
                    :: Html.Attributes.style "line-height" "1.4"
                    :: attrs
                )
                (List.map (Render.Expression.render settings.theme attrs) exprs)

        Left _ ->
            Html.text ""



---- SUBSIDIARY RENDERERS

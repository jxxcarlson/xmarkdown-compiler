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


renderBody : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> List (Html MarkupMsg)
renderBody count acc settings attrs block =
    case block.heading of
        Paragraph ->
            [ renderParagraphBody count acc settings attrs block ]

        Ordinary _ ->
            [ Render.OrdinaryBlock.render count acc settings attrs block ]

        Verbatim _ ->
            [ VerbatimBlock.render count acc settings attrs block |> Render.Helper.showError block.meta.error ]


renderParagraphBody : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
renderParagraphBody count acc settings attrs block =
    case block.body of
        Right exprs ->
            Html.p
                (Html.Attributes.id ("e-" ++ String.fromInt block.meta.lineNumber ++ "." ++ String.fromInt count)
                    :: Html.Attributes.attribute "data-line-number" (String.fromInt block.meta.lineNumber)
                    :: Html.Attributes.style "width" (String.fromInt settings.width ++ "px")
                    :: attrs
                )
                (List.map (Render.Expression.render count acc settings attrs) exprs)

        Left _ ->
            Html.text ""



---- SUBSIDIARY RENDERERS

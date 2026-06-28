module Render.Block exposing (renderBody)

import Dict
import Either exposing (Either(..))
import Element exposing (Element)
import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock, Heading(..))
import Render.Expression
import Render.Helper
import Render.OrdinaryBlock
import Render.Settings exposing (RenderSettings)
import Render.VerbatimBlock as VerbatimBlock
import XMarkdown.Msg exposing (MarkupMsg)


renderBody : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> List (Element MarkupMsg)
renderBody count acc settings attrs block =
    case block.heading of
        Paragraph ->
            Element.column [] [ renderParagraphBody count acc settings attrs block ]
                |> List.singleton

        Ordinary _ ->
            [ Render.OrdinaryBlock.render count acc settings attrs block ]

        Verbatim _ ->
            [ VerbatimBlock.render count acc settings attrs block |> Render.Helper.showError block.meta.error ]


renderParagraphBody : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
renderParagraphBody count acc settings attrs block =
    case block.body of
        Right exprs ->
            Element.paragraph
                (Render.Helper.htmlId block.meta.id
                    :: Element.width (Element.px settings.width)
                    :: attrs
                )
                (List.map (Render.Expression.render count acc settings attrs) exprs)

        Left _ ->
            Element.none



---- SUBSIDIARY RENDERERS

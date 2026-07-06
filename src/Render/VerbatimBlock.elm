module Render.VerbatimBlock exposing (render)

import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock, Heading(..))
import Either exposing (Either(..))
import Html exposing (Html)
import Html.Attributes
import Render.Math
import Render.Theme exposing (RenderSettings)
import XMarkdown.Types exposing (MarkupMsg, Theme(..))


{-| Render verbatim blocks (code, math, verse, etc.) as Html
-}
render : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
render count acc settings attrs block =
    case block.body of
        Right _ ->
            Html.text ""

        Left str ->
            case block.heading of
                Verbatim functionName ->
                    if functionName == "math" then
                        -- Render as display math, not code
                        Render.Math.displayedMath count acc settings attrs { block | body = Either.Left str }

                    else
                        -- Render as code
                        let
                            blockId = "e-" ++ String.fromInt block.meta.lineNumber ++ "." ++ String.fromInt count
                            indentPx = String.fromInt settings.leftIndentation ++ "px"
                        in
                        Html.div
                            [ Html.Attributes.style "margin-left" indentPx
                            ]
                            [ Html.pre
                                ([ Html.Attributes.id blockId
                                 , Html.Attributes.attribute "data-line-number" (String.fromInt block.meta.lineNumber)
                                 , Html.Attributes.style "padding-left" "0"

                                 --, case settings.theme of
                                 --   Light ->
                                 --       Html.Attributes.style "color" "blue"
                                 --
                                 --   Dark ->
                                 --       Html.Attributes.style "color" "pink"
                                 , Html.Attributes.style "overflow-x" "auto"
                                 , Html.Attributes.style "font-size" (String.fromInt (Render.Theme.scaleFont settings 16) ++ "px")
                                 ]
                                    ++ attrs
                                )
                                [ Html.code [] [ Html.text str ] ]
                            ]

                _ ->
                    Html.text ""

module Render.VerbatimBlock exposing (render)

import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock, Heading(..))
import Either exposing (Either(..))
import Html exposing (Html)
import Html.Attributes
import Render.Math
import Render.Settings exposing (RenderSettings)
import XMarkdown.Types exposing (MarkupMsg)


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
                        Html.pre
                            ([ Html.Attributes.id block.meta.id
                             , Html.Attributes.style "background-color" "#f5f5f5"
                             , Html.Attributes.style "padding" "12px"
                             , Html.Attributes.style "border-radius" "4px"
                             , Html.Attributes.style "overflow-x" "auto"
                             , Html.Attributes.style "font-size" (String.fromInt (Render.Settings.scaleFont settings 16) ++ "px")
                             ]
                                ++ attrs
                            )
                            [ Html.code [] [ Html.text str ] ]

                _ ->
                    Html.text ""

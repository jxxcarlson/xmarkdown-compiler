module Render.GHTable exposing (render)

import Html exposing (Html)
import Html.Attributes
import Either exposing (Either(..))
import AST.Acc exposing (Accumulator)
import AST.Language exposing (Expr(..), Expression, ExpressionBlock)
import Render.Expression
import Render.Settings exposing (RenderSettings)
import XMarkdown.Types exposing (MarkupMsg)


{-| Render a GFM table
-}
render : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
render count acc settings _ block =
    case block.body of
        Right [ Fun "table" rows _ ] ->
            Html.table
                [ Html.Attributes.style "border-collapse" "collapse"
                , Html.Attributes.style "width" "100%"
                , Html.Attributes.style "border" "1px solid #ddd"
                ]
                [ Html.tbody []
                    [ Html.tr []
                        [ Html.th
                            [ Html.Attributes.style "border" "1px solid #ddd"
                            , Html.Attributes.style "padding" "8px"
                            ]
                            [ Html.text "Table" ]
                        ]
                    ]
                ]

        _ ->
            Html.div [] [ Html.text "(table)" ]

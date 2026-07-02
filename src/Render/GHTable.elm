module Render.GHTable exposing (render)

import Html exposing (Html)
import Html.Attributes
import Either exposing (Either(..))
import AST.Acc exposing (Accumulator)
import AST.Language exposing (Expr(..), Expression, ExpressionBlock)
import Render.Expression
import Render.Theme exposing (RenderSettings)
import XMarkdown.Types exposing (MarkupMsg)


{-| Render a GFM table
-}
render : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
render count acc settings _ block =
    case block.body of
        Right [ Fun "table" rows _ ] ->
            let
                rowElements =
                    List.indexedMap (renderTableRow count acc settings) rows
            in
            Html.table
                [ Html.Attributes.style "border-collapse" "collapse"
                , Html.Attributes.style "width" "100%"
                , Html.Attributes.style "border" "1px solid #ddd"
                ]
                rowElements

        _ ->
            Html.div [] [ Html.text "(table)" ]


{-| Render a single table row
-}
renderTableRow : Int -> Accumulator -> RenderSettings -> Int -> Expression -> Html MarkupMsg
renderTableRow count acc settings rowIndex expr =
    case expr of
        Fun "row" cells _ ->
            let
                isHeader = rowIndex == 0
                cellElements =
                    List.map (renderTableCell count acc settings isHeader) cells

                element = if isHeader then Html.thead else Html.tbody
            in
            element [] [ Html.tr [] cellElements ]

        _ ->
            Html.tr [] []


{-| Render a single table cell
-}
renderTableCell : Int -> Accumulator -> RenderSettings -> Bool -> Expression -> Html MarkupMsg
renderTableCell count acc settings isHeader expr =
    case expr of
        Fun "cell" content _ ->
            let
                renderedContent =
                    List.map (Render.Expression.render count acc settings []) content

                element = if isHeader then Html.th else Html.td
            in
            element
                [ Html.Attributes.style "border" "1px solid #ddd"
                , Html.Attributes.style "padding" "8px"
                ]
                renderedContent

        _ ->
            Html.td [] []

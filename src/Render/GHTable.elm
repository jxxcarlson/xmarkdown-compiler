module Render.GHTable exposing (render)

import AST.Acc exposing (Accumulator)
import AST.Language exposing (Expr(..), Expression, ExpressionBlock)
import Dict
import Either exposing (Either(..))
import Html exposing (Html)
import Html.Attributes
import Render.Expression
import Render.Theme exposing (RenderSettings)
import XMarkdown.Types exposing (MarkupMsg, Theme)


{-| Render a GFM table
-}
render : Int -> Accumulator -> Int -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
render count _ _ settings _ block =
    case block.body of
        Right [ Fun "table" rows _ ] ->
            let
                alignments =
                    Dict.get "alignments" block.properties
                        |> Maybe.withDefault ""
                        |> String.split ","
                        |> List.map String.trim

                rowElements =
                    List.indexedMap (renderTableRow settings.theme alignments) rows

                blockId =
                    "e-" ++ String.fromInt block.meta.lineNumber ++ "." ++ String.fromInt count

                indentPx =
                    String.fromInt settings.leftIndentation ++ "px"

                tableWidth =
                    String.fromInt (settings.width - settings.leftIndentation) ++ "px"
            in
            Html.div
                [ Html.Attributes.style "margin-left" indentPx
                ]
                [ Html.table
                    [ Html.Attributes.id blockId
                    , Html.Attributes.attribute "data-line-number" (String.fromInt block.meta.lineNumber)
                    , Html.Attributes.style "border-collapse" "collapse"
                    , Html.Attributes.style "width" tableWidth
                    , Html.Attributes.style "border" "1px solid #ddd"
                    ]
                    rowElements
                ]

        _ ->
            Html.div [] [ Html.text "(table)" ]


{-| Render a single table row
-}
renderTableRow : Theme -> List String -> Int -> Expression -> Html MarkupMsg
renderTableRow theme alignments rowIndex expr =
    case expr of
        Fun "row" cells _ ->
            let
                isHeader =
                    rowIndex == 0

                cellElements =
                    List.indexedMap (renderTableCell theme alignments isHeader) cells

                element =
                    if isHeader then
                        Html.thead

                    else
                        Html.tbody
            in
            element [] [ Html.tr [] cellElements ]

        _ ->
            Html.tr [] []


{-| Render a single table cell
-}
renderTableCell : Theme -> List String -> Bool -> Int -> Expression -> Html MarkupMsg
renderTableCell theme alignments isHeader colIndex expr =
    case expr of
        Fun "cell" content _ ->
            let
                renderedContent =
                    List.map (Render.Expression.render theme []) content

                element =
                    if isHeader then
                        Html.th

                    else
                        Html.td

                alignment =
                    List.drop colIndex alignments |> List.head |> Maybe.withDefault "l"

                textAlign =
                    case alignment of
                        "c" ->
                            "center"

                        "r" ->
                            "right"

                        _ ->
                            "left"
            in
            element
                [ Html.Attributes.style "border" "1px solid #ddd"
                , Html.Attributes.style "padding" "8px"
                , Html.Attributes.style "text-align" textAlign
                ]
                renderedContent

        _ ->
            Html.td [] []

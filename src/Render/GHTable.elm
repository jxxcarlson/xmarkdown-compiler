module Render.GHTable exposing (render)

import Dict
import Either exposing (Either(..))
import Element exposing (Element)
import Element.Border as Border
import Element.Font as Font
import AST.Acc exposing (Accumulator)
import AST.Language exposing (Expr(..), Expression, ExpressionBlock)
import Render.Expression
import Render.Settings exposing (RenderSettings)
import Scripta.Msg exposing (MarkupMsg)


render : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
render count acc settings _ block =
    case block.body of
        Right [ Fun "table" rows _ ] ->
            let
                aligns : List (Element.Attribute MarkupMsg)
                aligns =
                    Dict.get "alignments" block.properties
                        |> Maybe.withDefault ""
                        |> String.split ","
                        |> List.map alignAttr

                allRows : List (List (List Expression))
                allRows =
                    List.map rowCells rows

                headerCells : List (List Expression)
                headerCells =
                    List.head allRows |> Maybe.withDefault []

                dataRows : List (List (List Expression))
                dataRows =
                    List.drop 1 allRows

                ncols : Int
                ncols =
                    List.length headerCells

                columns =
                    List.range 0 (ncols - 1)
                        |> List.map
                            (\i ->
                                { header = headerCell count acc settings (alignAt i aligns) (cellAt i headerCells)
                                , width = Element.fill
                                , view = \row -> dataCell count acc settings (alignAt i aligns) (cellAt i row)
                                }
                            )
            in
            Element.table [ Element.spacing 10, Element.paddingXY 0 8 ]
                { data = dataRows, columns = columns }

        _ ->
            Element.none


rowCells : Expression -> List (List Expression)
rowCells row =
    case row of
        Fun "row" cells _ ->
            List.map cellExprs cells

        _ ->
            []


cellExprs : Expression -> List Expression
cellExprs cell =
    case cell of
        Fun "cell" exprs _ ->
            exprs

        _ ->
            []


cellAt : Int -> List (List Expression) -> List Expression
cellAt i cells =
    List.drop i cells |> List.head |> Maybe.withDefault []


alignAt : Int -> List (Element.Attribute MarkupMsg) -> Element.Attribute MarkupMsg
alignAt i aligns =
    List.drop i aligns |> List.head |> Maybe.withDefault Element.alignLeft


alignAttr : String -> Element.Attribute MarkupMsg
alignAttr code =
    case code of
        "c" ->
            Element.centerX

        "r" ->
            Element.alignRight

        _ ->
            Element.alignLeft


headerCell : Int -> Accumulator -> RenderSettings -> Element.Attribute MarkupMsg -> List Expression -> Element MarkupMsg
headerCell count acc settings align exprs =
    Element.el
        [ Font.bold
        , Border.widthEach { bottom = 1, top = 0, left = 0, right = 0 }
        , Element.paddingXY 8 6
        , Element.width Element.fill
        ]
        (Element.paragraph [ align ] (List.map (Render.Expression.render count acc settings []) exprs))


dataCell : Int -> Accumulator -> RenderSettings -> Element.Attribute MarkupMsg -> List Expression -> Element MarkupMsg
dataCell count acc settings align exprs =
    Element.el [ Element.paddingXY 8 6, Element.width Element.fill ]
        (Element.paragraph [ align ] (List.map (Render.Expression.render count acc settings []) exprs))

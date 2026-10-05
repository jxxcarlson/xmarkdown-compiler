module Render.TitleBlock exposing (render)

{-| The %title / %author / %date block (AST.TitleBlock): centered lines,
the title at 2em and the authors (joined on one line: "A and B",
"A, B, and C") and date at 1.5em. Lines are 1.4625 body-ems apart (margins
are in each line's own em, so they are divided by its size), with 3em below
the last line. Only the document's first title block is drawn.
-}

import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock)
import AST.TitleBlock
import Dict
import Html exposing (Html)
import Html.Attributes
import Render.Theme exposing (RenderSettings)
import XMarkdown.Types exposing (MarkupMsg)


render : Int -> Accumulator -> Int -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
render count acc _ _ _ block =
    if Dict.get AST.TitleBlock.firstIdKey acc.keyValueDict /= Just block.meta.id then
        Html.text ""

    else
        let
            info =
                AST.TitleBlock.fromBlock block

            lines =
                List.concat
                    [ nonEmpty 2 info.title
                    , nonEmpty 1.5 (joinAuthors info.authors)
                    , nonEmpty 1.5 info.date
                    ]

            count_ =
                List.length lines

            line index ( size, text ) =
                Html.div
                    [ Html.Attributes.style "text-align" "center"
                    , Html.Attributes.style "font-size" (em size)
                    , Html.Attributes.style "margin-bottom"
                        (if index == count_ - 1 then
                            "3em"

                         else
                            em (lineGap / size)
                        )
                    , Html.Attributes.attribute "data-title-block" "true"
                    ]
                    [ Html.text text ]
        in
        Html.div
            [ Html.Attributes.id ("e-" ++ String.fromInt block.meta.lineNumber ++ "." ++ String.fromInt count)
            , Html.Attributes.attribute "data-line-number" (String.fromInt block.meta.lineNumber)
            , Html.Attributes.style "width" "100%"
            ]
            (List.indexedMap line lines)


{-| Space between consecutive lines, in body ems.
-}
lineGap : Float
lineGap =
    1.4625


em : Float -> String
em x =
    String.fromFloat x ++ "em"


nonEmpty : Float -> String -> List ( Float, String )
nonEmpty size text =
    if String.isEmpty text then
        []

    else
        [ ( size, text ) ]


{-| "A", "A and B", "A, B, and C", ...
-}
joinAuthors : List String -> String
joinAuthors authors =
    case List.reverse authors of
        [] ->
            ""

        [ only ] ->
            only

        [ second, first ] ->
            first ++ " and " ++ second

        last :: rest ->
            String.join ", " (List.reverse rest) ++ ", and " ++ last

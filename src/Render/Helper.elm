module Render.Helper exposing
    ( blockAttributes
    , blockLabel
    , htmlId
    , leftPadding
    , noSuchVerbatimBlock
    , noteFromPropertyKey
    , renderNothing
    , renderWithDefault
    , renderWithDefaultNarrow
    , selectedColor
    , showError
    , topPaddingForIndentedElements
    )

import AST.Acc exposing (Accumulator)
import AST.Language exposing (Expression, ExpressionBlock)
import Color
import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes
import Render.Expression
import Render.Theme exposing (RenderSettings)
import Render.Sync
import Render.Utility
import XMarkdown.Types exposing (MarkupMsg)


leftPadding k =
    Html.Attributes.style "padding-left" (String.fromInt k ++ "px")


topPaddingForIndentedElements =
    10


noteFromPropertyKey : String -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
noteFromPropertyKey key attrs block =
    case Dict.get key block.properties of
        Nothing ->
            Html.text ""

        Just note_ ->
            Html.p attrs [ Html.text note_ ]


blockLabel : Dict String String -> String
blockLabel properties =
    Dict.get "label" properties |> Maybe.withDefault ""


blockAttributes : RenderSettings -> ExpressionBlock -> List (Html.Attribute MarkupMsg) -> List (Html.Attribute MarkupMsg)
blockAttributes settings block attrs =
    [ Html.Attributes.id (String.fromInt block.meta.lineNumber)
    ]
        ++ attrs


selectedColor : String -> RenderSettings -> Html.Attribute MarkupMsg
selectedColor id settings =
    if id == settings.selectedId then
        Html.Attributes.style "background-color" "rgba(230, 230, 255, 1)"

    else
        Html.Attributes.style "background-color" "rgba(255, 255, 255, 1)"


htmlId : String -> Html.Attribute MarkupMsg
htmlId str =
    Html.Attributes.id str


showError : Maybe String -> Html MarkupMsg -> Html MarkupMsg
showError maybeError x =
    case maybeError of
        Nothing ->
            x

        Just error ->
            Html.div []
                [ x
                , Html.div [ Html.Attributes.style "color" "rgb(179, 0, 0)" ] [ Html.text error ]
                ]


noSuchVerbatimBlock : String -> String -> Html MarkupMsg
noSuchVerbatimBlock functionName content =
    Html.div []
        [ Html.p [ Html.Attributes.style "color" "rgb(180, 0, 0)" ] [ Html.text <| "No such block (V): " ++ functionName ]
        , Html.pre [] [ Html.text content ]
        ]


renderNothing : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
renderNothing _ _ _ _ _ =
    Html.text ""


renderWithDefault : String -> Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> List Expression -> List (Html MarkupMsg)
renderWithDefault default count acc settings attr exprs =
    if List.isEmpty exprs then
        [ Html.span [ Html.Attributes.style "color" "rgb(150, 0, 0)", Html.Attributes.style "font-size" (String.fromInt (Render.Theme.scaleFont settings 14) ++ "px") ] [ Html.text default ] ]

    else
        List.map (Render.Expression.render count acc settings attr) exprs


renderWithDefaultNarrow : String -> Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> List Expression -> List (Html MarkupMsg)
renderWithDefaultNarrow default count acc settings attr exprs =
    renderWithDefault default count acc settings attr exprs

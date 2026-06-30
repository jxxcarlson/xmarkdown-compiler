module Render.Helper exposing
    ( blockAttributes
    , blockLabel
    , htmlId
    , leftPadding
    , noSuchVerbatimBlock
    , noteFromPropertyKey
    , renderNothing
    , renderWithDefault
    , selectedColor
    , showError
    , topPaddingForIndentedElements
    )

import Dict exposing (Dict)
import Element exposing (Element)
import Element.Background as Background
import Element.Font as Font
import AST.Acc exposing (Accumulator)
import AST.Language exposing (Expression, ExpressionBlock)
import Html.Attributes
import Render.Expression
import Render.Settings exposing (RenderSettings)
import Render.Sync
import Render.Utility
import XMarkdown.Types exposing (MarkupMsg)



-- SETTINGS


leftPadding k =
    Element.paddingEach { top = 0, right = 0, bottom = 0, left = k }


topPaddingForIndentedElements =
    10



-- HELPERS
-- oteFromPropertyKey : String -> ExpressionBlock -> Element MarkupMsg


noteFromPropertyKey key attrs block =
    case Dict.get key block.properties of
        Nothing ->
            Element.none

        Just note_ ->
            Element.paragraph attrs [ Element.text note_ ]


{-|

    Used in function env (render generic LaTeX environments)

-}
blockLabel : Dict String String -> String
blockLabel properties =
    Dict.get "label" properties |> Maybe.withDefault ""


blockAttributes settings block attrs =
    [ Render.Utility.idAttributeFromInt block.meta.lineNumber
    ]
        ++ Render.Sync.attributes settings block
        ++ attrs


selectedColor id settings =
    if id == settings.selectedId then
        Background.color (Element.rgb 0.9 0.9 1.0)

    else
        Background.color settings.backgroundColor


htmlId : String -> Element.Attribute msg
htmlId str =
    Element.htmlAttribute (Html.Attributes.id str)


showError : Maybe String -> Element msg -> Element msg
showError maybeError x =
    case maybeError of
        Nothing ->
            x

        Just error ->
            Element.column []
                [ x
                , Element.el [ Font.color (Element.rgb 0.7 0 0) ] (Element.text error)
                ]



-- ERRORS.


noSuchVerbatimBlock : String -> String -> Element MarkupMsg
noSuchVerbatimBlock functionName content =
    Element.column [ Element.spacing 4 ]
        [ Element.paragraph [ Font.color (Element.rgb255 180 0 0) ] [ Element.text <| "No such block (V): " ++ functionName ]
        , Element.column [ Element.spacing 4 ] (List.map (\t -> Element.el [] (Element.text t)) (String.lines content))
        ]


renderNothing : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
renderNothing _ _ _ _ _ =
    Element.none


renderWithDefault : String -> Int -> AST.Acc.Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> List Expression -> List (Element MarkupMsg)
renderWithDefault default count acc settings attr exprs =
    if List.isEmpty exprs then
        [ Element.el [ Font.color settings.redColor, Font.size (Render.Settings.scaleFont settings 14) ] (Element.text default) ]

    else
        List.map (Render.Expression.render count acc settings attr) exprs

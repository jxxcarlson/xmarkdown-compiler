module Render.Expression exposing (render)

import AST.ASTTools as ASTTools
import AST.Acc exposing (Accumulator)
import AST.Language exposing (Expr(..), Expression)
import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes
import Html.Events
import Json.Decode
import Render.Settings exposing (RenderSettings)
import XMarkdown.Types exposing (MarkupMsg(..))


{-| Render an expression to Html
-}
render : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> Expression -> Html MarkupMsg
render generation acc settings attrs expr =
    case expr of
        Text string meta ->
            Html.span ([ htmlId meta.id ] ++ attrs) [ Html.text (string ++ " ") ]

        Fun name exprList meta ->
            if List.member name [ "chem", "math", "m", "code" ] then
                Html.span [ htmlId meta.id ]
                    [ Html.text ("(" ++ name ++ " expr)") ]

            else if List.member name [ "anchor", "mark" ] then
                Html.span [ htmlId meta.id ]
                    [ Html.text ("(" ++ name ++ " content)") ]

            else if List.member name [ "b", "strong", "bold" ] then
                Html.strong [ htmlId meta.id ]
                    (List.map (render generation acc settings attrs) exprList)

            else if List.member name [ "i", "em", "italic" ] then
                Html.em [ htmlId meta.id ]
                    (List.map (render generation acc settings attrs) exprList)

            else if List.member name [ "strike", "strikethrough" ] then
                Html.span [ Html.Attributes.style "text-decoration" "line-through", htmlId meta.id ]
                    (List.map (render generation acc settings attrs) exprList)

            else if name == "a" || name == "link" then
                Html.a [ Html.Attributes.href "#", htmlId meta.id ]
                    (List.map (render generation acc settings attrs) exprList)

            else
                Html.span [ htmlId meta.id ]
                    (List.map (render generation acc settings attrs) exprList)

        _ ->
            Html.span [] [ Html.text "(expression)" ]


{-| Helper for click events
-}
onClickStop : MarkupMsg -> Html.Attribute MarkupMsg
onClickStop msg =
    Html.Events.stopPropagationOn "click" (Json.Decode.succeed ( msg, True ))


{-| Helper for id attributes
-}
htmlId : String -> Html.Attribute MarkupMsg
htmlId str =
    Html.Attributes.id str

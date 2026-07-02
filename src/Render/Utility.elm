module Render.Utility exposing
    ( getVerbatimContent
    , idAttribute
    , idAttributeFromInt
    , internalLink
    , leftPadding
    , makeId
    , vspace
    )

import AST.ASTTools
import AST.Language
import Either
import Html
import Html.Attributes exposing (style)


leftPadding : Int -> Html.Attribute msg
leftPadding p =
    style "padding-left" (String.fromInt p)


getVerbatimContent : AST.Language.ExpressionBlock -> String
getVerbatimContent { body } =
    case body of
        Either.Left str ->
            str

        Either.Right _ ->
            ""


idAttributeFromInt : Int -> Html.Attribute msg
idAttributeFromInt k =
    htmlAttribute "id" (String.fromInt k)


idAttribute : String -> Html.Attribute msg
idAttribute s =
    htmlAttribute "id" s


vspace : Int -> Int -> List (Html.Attribute msg)
vspace top bottom =
    [ style "padding-top" (String.fromInt top), style "padding-bottoms" (String.fromInt top) ]


internalLink : String -> String
internalLink str =
    "#" ++ str |> makeSlug


makeId : List AST.Language.Expression -> Html.Attribute msg
makeId exprs =
    htmlAttribute "id"
        (AST.ASTTools.stringValueOfList exprs |> String.trim |> makeSlug)


makeSlug : String -> String
makeSlug str =
    str |> String.toLower |> String.replace " " ""


htmlAttribute : String -> String -> Html.Attribute msg
htmlAttribute key value =
    Html.Attributes.attribute key value

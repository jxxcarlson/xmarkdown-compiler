module Render.Utility exposing
    ( elementAttribute
    , getVerbatimContent
    , idAttribute
    , idAttributeFromInt
    , internalLink
    , leftPadding
    , makeId
    , unicodeFromHex
    , vspace
    )

import Either
import Element exposing (paddingEach)
import Generic.ASTTools
import Generic.Language
import Html.Attributes


unicodeFromHex hex =
    String.fromChar (Char.fromCode hex)


leftPadding p =
    Element.paddingEach { left = p, right = 0, top = 0, bottom = 0 }


getVerbatimContent : Generic.Language.ExpressionBlock -> String
getVerbatimContent { body } =
    case body of
        Either.Left str ->
            str

        Either.Right _ ->
            ""


idAttributeFromInt : Int -> Element.Attribute msg
idAttributeFromInt k =
    elementAttribute "id" (String.fromInt k)


idAttribute : String -> Element.Attribute msg
idAttribute s =
    elementAttribute "id" s


vspace : Int -> Int -> Element.Attribute msg
vspace top bottom =
    paddingEach { left = 0, right = 0, top = top, bottom = bottom }


internalLink : String -> String
internalLink str =
    "#" ++ str |> makeSlug


makeId : List Generic.Language.Expression -> Element.Attribute msg
makeId exprs =
    elementAttribute "id"
        (Generic.ASTTools.stringValueOfList exprs |> String.trim |> makeSlug)


makeSlug : String -> String
makeSlug str =
    str |> String.toLower |> String.replace " " ""


elementAttribute : String -> String -> Element.Attribute msg
elementAttribute key value =
    Element.htmlAttribute (Html.Attributes.attribute key value)

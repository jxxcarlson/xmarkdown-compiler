module Render.TOCTree exposing
    ( ViewParameters
    , view
    )

import AST.ASTTools
import AST.Forest exposing (Forest)
import AST.Language exposing (ExpressionBlock)
import Dict
import Either
import Html exposing (Html)
import Html.Attributes
import Html.Events
import Json.Decode
import Render.Theme
import XMarkdown.Types exposing (MarkupMsg(..), Theme)


type alias ViewParameters =
    { selectedId : String
    , counter : Int
    , attr : List (Html.Attribute MarkupMsg)
    , settings : Render.Theme.RenderSettings
    }


view : Theme -> ViewParameters -> Forest ExpressionBlock -> List (Html MarkupMsg)
view theme viewParameters documentAst =
    let
        tocAST : List ExpressionBlock
        tocAST =
            AST.ASTTools.tableOfContents documentAst
    in
    [ Html.ul
        [ Html.Attributes.style "padding-left" "0"
        , Html.Attributes.style "margin-left" "0"
        ]
        (List.map (renderTocItem theme viewParameters.counter viewParameters.settings.numberToLevel) tocAST)
    ]


{-| Render a single TOC item with the actual heading text
-}
renderTocItem : Theme -> Int -> Int -> ExpressionBlock -> Html MarkupMsg
renderTocItem theme editCount numberToLevel block =
    let
        headingText =
            case block.body of
                Either.Right exprs ->
                    List.map extractText exprs |> String.concat

                Either.Left _ ->
                    ""

        extractText : AST.Language.Expression -> String
        extractText expr =
            case expr of
                AST.Language.Text text _ ->
                    text

                _ ->
                    ""

        level : Int
        level =
            Dict.get "level" block.properties
                |> Maybe.andThen String.toInt
                |> Maybe.withDefault 1

        sectionNumber =
            if numberToLevel > 0 && level <= numberToLevel then
                Dict.get "label" block.properties |> Maybe.withDefault ""

            else
                ""

        displayText =
            if String.isEmpty sectionNumber then
                if String.isEmpty headingText then
                    "Untitled"

                else
                    headingText

            else
                sectionNumber ++ " " ++ headingText

        indent =
            16 + (level - 1) * 14

        liStyle =
            [ Html.Attributes.style "margin-left" (String.fromInt indent ++ "px")
            , Html.Attributes.style "margin-bottom" "8px"
            , Html.Attributes.style "list-style-type" "none"
            ]
    in
    let
        elementId =
            "e-" ++ String.fromInt block.meta.lineNumber ++ "." ++ String.fromInt editCount
    in
    Html.li liStyle
        [ Html.a
            [ Html.Attributes.href ("#" ++ elementId)
            , Html.Attributes.style "color" (Render.Theme.themedColor .link theme)
            , Html.Events.preventDefaultOn "click"
                (Json.Decode.succeed ( SelectId elementId, True ))
            ]
            [ Html.text displayText ]
        ]

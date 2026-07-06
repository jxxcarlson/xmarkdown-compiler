module Render.TOCTree exposing
    ( TOCNodeValue
    , ViewParameters
    , view
    )

import AST.ASTTools
import AST.Acc exposing (Accumulator)
import AST.Forest exposing (Forest)
import AST.Language exposing (ExpressionBlock)
import AST.Language
import Dict
import Either
import Html exposing (Html)
import Html.Attributes
import Html.Events
import Json.Decode
import Render.Theme
import XMarkdown.Types exposing (MarkupMsg(..), Theme(..))


type alias ViewParameters =
    { idsOfOpenNodes : List String
    , selectedId : String
    , counter : Int
    , attr : List (Html.Attribute MarkupMsg)
    , settings : Render.Theme.RenderSettings
    }


view : Theme -> ViewParameters -> Accumulator -> Forest ExpressionBlock -> List (Html MarkupMsg)
view theme viewParameters acc documentAst =
    let
        tocAST : List ExpressionBlock
        tocAST =
            AST.ASTTools.tableOfContents documentAst
    in
    [ Html.ul
        [ Html.Attributes.style "padding-left" "0"
        , Html.Attributes.style "margin-left" "0"
        ]
        (List.map (renderTocItem acc viewParameters.counter) tocAST)
    ]


{-| Render a single TOC item with the actual heading text
-}
renderTocItem : Accumulator -> Int -> ExpressionBlock -> Html MarkupMsg
renderTocItem acc editCount block =
    let
        headingText =
            case block.body of
                Either.Right exprs ->
                    List.map (extractText acc) exprs |> String.concat
                Either.Left _ ->
                    ""

        extractText : Accumulator -> AST.Language.Expression -> String
        extractText _ expr =
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
            Dict.get "label" block.properties |> Maybe.withDefault ""

        displayText =
            if String.isEmpty sectionNumber then
                if String.isEmpty headingText then "Untitled" else headingText
            else
                sectionNumber ++ " " ++ headingText

        indent =
            16 + (level - 1) * 14

        liStyle =
            [ Html.Attributes.style "margin-left" (String.fromInt indent ++ "px")
            , Html.Attributes.style "margin-bottom" "8px"
            ]
                ++ (if String.isEmpty sectionNumber then
                        []
                    else
                        [ Html.Attributes.style "list-style-type" "none" ]
                   )
    in
    let
        elementId =
            "e-" ++ String.fromInt block.meta.lineNumber ++ "." ++ String.fromInt editCount
    in
    Html.li liStyle
        [ Html.a
            [ Html.Attributes.href ("#" ++ elementId)
            , Html.Events.preventDefaultOn "click"
                (Json.Decode.succeed (SelectId elementId, True))
            ]
            [ Html.text displayText ]
        ]


type alias TOCNodeValue =
    { block : ExpressionBlock, visible : Bool }

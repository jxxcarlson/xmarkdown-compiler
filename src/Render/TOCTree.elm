module Render.TOCTree exposing
    ( TOCNodeValue
    , ViewParameters
    , view
    )

import Dict
import Either exposing (Either(..))
import Element exposing (Element)
import Element.Background
import Element.Events as Events
import Element.Font as Font
import AST.ASTTools
import AST.Acc exposing (Accumulator)
import AST.Forest exposing (Forest)
import AST.Language exposing (ExpressionBlock)
import Library.Forest
import Library.Tree
import Render.Expression
import Render.Settings
import Render.Theme
import Render.Utility
import RoseTree.Tree exposing (Tree)
import Scripta.Config as Config
import Scripta.Msg exposing (MarkupMsg(..))
import String.Extra


type alias ViewParameters =
    { idsOfOpenNodes : List String
    , selectedId : String
    , counter : Int
    , attr : List (Element.Attribute MarkupMsg)
    , settings : Render.Settings.RenderSettings
    }


view : Render.Theme.Theme -> ViewParameters -> Accumulator -> Forest ExpressionBlock -> List (Element MarkupMsg)
view theme viewParameters acc documentAst =
    let
        tocAST : List ExpressionBlock
        tocAST =
            AST.ASTTools.tableOfContents documentAst

        nodes : List TOCNodeValue
        nodes =
            List.map makeNodeValue tocAST

        forest : List (Tree TOCNodeValue)
        forest =
            Library.Forest.makeForest Library.Tree.lev nodes

        vee t =
            { length = t |> RoseTree.Tree.children >> List.length, view = viewTOCTree theme viewParameters acc 4 t }

        vee2 t =
            let
                data =
                    vee t

                format =
                    if data.length > 0 then
                        [ Font.italic
                        , Font.color (Render.Settings.getThemedElementColor .text theme)

                        --, Element.Background.color (Render.Settings.getThemedElementColor .background theme)
                        ]

                    else
                        []
            in
            Element.el format data.view
    in
    forest
        |> List.map vee2


style_ theme_ =
    case theme_ of
        Render.Theme.Dark ->
            [ Element.Background.color (Render.Settings.getThemedElementColor .background theme_)
            , Font.color (Render.Settings.getThemedElementColor .text theme_)
            ]

        Render.Theme.Light ->
            [ Element.Background.color (Render.Settings.getThemedElementColor .background theme_)
            , Font.color (Render.Settings.getThemedElementColor .text theme_)
            ]


viewTOCTree : Render.Theme.Theme -> ViewParameters -> Accumulator -> Int -> Tree TOCNodeValue -> Element MarkupMsg
viewTOCTree theme viewParameters acc depth tocTree =
    let
        val : TOCNodeValue
        val =
            RoseTree.Tree.value tocTree

        actualChildren : List (Tree TOCNodeValue)
        actualChildren =
            RoseTree.Tree.children tocTree

        hasChildren : Bool
        hasChildren =
            not (List.isEmpty actualChildren)

        children : List (Tree TOCNodeValue)
        children =
            if List.member val.block.meta.id viewParameters.idsOfOpenNodes then
                actualChildren

            else
                []
    in
    if depth < 0 || val.visible == False then
        Element.none

    else if List.isEmpty children then
        viewNodeWithChildren theme viewParameters acc val hasChildren

    else
        Element.column [ Element.spacing 8 ]
            (viewNodeWithChildren theme viewParameters acc val hasChildren
                :: List.map (viewTOCTree theme viewParameters acc (depth - 1))
                    children
            )


viewNodeWithChildren : Render.Theme.Theme -> ViewParameters -> Accumulator -> TOCNodeValue -> Bool -> Element MarkupMsg
viewNodeWithChildren theme viewParameters acc node hasChildren =
    viewTocItem_ theme viewParameters acc hasChildren node.block


type alias TOCNodeValue =
    { block : ExpressionBlock, visible : Bool }


makeNodeValue : ExpressionBlock -> TOCNodeValue
makeNodeValue block =
    let
        newBlock =
            -- The "xy" line below is needed because we also have the possibility of
            -- the TOC in the sidebar. We do not want click on a TOC item in the sidebar
            -- targeting the TOC item in the main text.
            AST.Language.updateMetaInBlock (\m -> { m | id = "xy" ++ m.id }) block
    in
    { block = newBlock, visible = True }


viewTocItem_ : Render.Theme.Theme -> ViewParameters -> Accumulator -> Bool -> ExpressionBlock -> Element MarkupMsg
viewTocItem_ theme viewParameters acc hasChildren ({ body, properties } as block) =
    case body of
        Left _ ->
            Element.none

        Right exprs ->
            let
                id =
                    Config.expressionIdPrefix ++ String.fromInt block.meta.lineNumber ++ ".0"

                nodeId =
                    block.meta.id

                sectionNumber =
                    let
                        nosectionNumber str =
                            Element.el [ Element.paddingEach { left = 8, right = 0, top = 0, bottom = 0 } ] (Element.text str)
                    in
                    --case Dict.get "number-to-level" properties |> Maybe.andThen String.toInt of
                    --    Nothing ->
                    --        nosectionNumber "**"
                    --
                    --    Just level ->
                    --        --if level <= maximumNumberedTocLevel then
                    --        if level <= 6 then
                    case Dict.get "label" properties of
                        Nothing ->
                            nosectionNumber ""

                        Just label ->
                            Element.el [] (Element.text (label ++ "."))

                --else
                --    nosectionNumber "!!"
                --exprs2 : Element MarkupMsg
                exprs2 =
                    case exprs |> List.head |> Maybe.andThen AST.Language.extractText of
                        Nothing ->
                            exprs

                        Just ( text, meta ) ->
                            [ AST.Language.composeTextElement (String.Extra.softWrapWith 22 "..." (String.trim text)) meta ]

                lvl : Int
                lvl =
                    Dict.get "level" properties |> Maybe.andThen String.toInt |> Maybe.withDefault 4

                spacer =
                    Element.el [ Element.width (Element.px (20 * lvl)) ] Element.none

                content =
                    Element.row ([ Element.width (Element.px 240), Element.spacing 8 ] ++ style_ theme) (sectionNumber :: List.map (Render.Expression.render viewParameters.counter acc viewParameters.settings viewParameters.attr) exprs2)

                -- Click handlers based on whether the item has children
                clickHandlers =
                    if hasChildren then
                        [ Events.onClick (ToggleTOCNodeID nodeId), Font.size (Render.Settings.scaleFont viewParameters.settings 14) ]

                    else
                        [ Events.onClick (SelectId <| id), Font.size (Render.Settings.scaleFont viewParameters.settings 14) ]
            in
            Element.row []
                [ spacer
                , Element.el (clickHandlers ++ style_ theme)
                    (Element.link [ Font.color (Element.rgb 1 0 0) ] { url = Render.Utility.internalLink id, label = content })
                ]

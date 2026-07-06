module Render.Tree exposing (renderTree)

{-| This module provides a refactored implementation of tree rendering using the new abstractions.

@docs renderTree

-}

import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock)
import Dict
import Html exposing (Html)
import Html.Attributes
import Html.Events
import Render.Attributes
import Render.Theme exposing (RenderSettings)
import Render.TreeSupport
import RoseTree.Tree exposing (Tree)
import XMarkdown.Types exposing (MarkupMsg, Theme(..))


{-| Render a tree of expression blocks (returns Html)
-}
renderTree :
    XMarkdown.Types.CompilerParameters
    -> Render.Theme.RenderSettings
    -> Accumulator
    -> RoseTree.Tree.Tree ExpressionBlock
    -> Html MarkupMsg
renderTree params settings accumulator tree =
    let
        root : ExpressionBlock
        root =
            RoseTree.Tree.value tree

        isBoxLike : ExpressionBlock -> Bool
        isBoxLike block =
            case AST.Language.getName block of
                Nothing ->
                    False

                Just name ->
                    name == "box"

        fontStyle =
            case Dict.get "style" root.properties of
                Just "italic" ->
                    "italic"
                _ ->
                    "normal"

        borderColor =
            case params.theme of
                Light ->
                    "rgba(179, 204, 230, 1)"

                Dark ->
                    "rgba(153, 153, 153, 0.5)"

        blockAttrs =
            [ Html.Attributes.style "width" (String.fromInt settings.width ++ "px")
            , Html.Attributes.style "font-size" (String.fromInt settings.fontSize ++ "px")
            , Html.Attributes.style "font-style" fontStyle
            ]
    in
    if isBoxLike root then
        Html.div blockAttrs
            [ Html.div
                [ Html.Attributes.style "padding-bottom" "18px"
                , Html.Attributes.style "border" ("4px solid " ++ borderColor)
                , Html.Attributes.style "margin-left" "auto"
                , Html.Attributes.style "margin-right" "auto"
                , Html.Attributes.style "width" (String.fromInt (settings.width - 60) ++ "px")
                ]
                [ renderTree_ params settings accumulator tree
                ]
            ]

    else
        Html.div
            [ Html.Attributes.style "width" "100%"
            , Html.Attributes.style "font-style" fontStyle
            , Html.Attributes.style "font-size" (String.fromInt settings.fontSize ++ "px")
            ]
            [ renderTree_ params settings accumulator tree ]


renderTree_ :
    XMarkdown.Types.CompilerParameters
    -> Render.Theme.RenderSettings
    -> Accumulator
    -> RoseTree.Tree.Tree ExpressionBlock
    -> Html MarkupMsg
renderTree_ params settings accumulator tree =
    let
        root =
            RoseTree.Tree.value tree
    in
    case RoseTree.Tree.children tree of
        [] ->
            -- Leaf node: just render the block
            renderLeafNode params settings accumulator root

        children ->
            -- Branch node: render based on block type
            renderBranchNode params settings accumulator root children


{-| Render a leaf node (a block with no children) - returns Html
-}
renderLeafNode :
    XMarkdown.Types.CompilerParameters
    -> RenderSettings
    -> Accumulator
    -> ExpressionBlock
    -> Html MarkupMsg
renderLeafNode params settings accumulator root =
    let
        attrs = Render.TreeSupport.renderAttributes settings root
    in
    Html.div attrs
        (Render.TreeSupport.renderBody params settings accumulator root)


{-| Render a branch node (a block with children) - returns Html
-}
renderBranchNode :
    XMarkdown.Types.CompilerParameters
    -> RenderSettings
    -> Accumulator
    -> ExpressionBlock
    -> List (Tree ExpressionBlock)
    -> Html MarkupMsg
renderBranchNode params settings accumulator root children =
    renderStandardBranch params settings accumulator root children


{-|

    Render a standard branch node:
     - render the body of the root
     - render the forest     using each child's attributes plus those inherited from the root.

     (( Something like that ))

-}
renderStandardBranch :
    XMarkdown.Types.CompilerParameters
    -> RenderSettings
    -> Accumulator
    -> ExpressionBlock
    -> List (Tree ExpressionBlock)
    -> Html MarkupMsg
renderStandardBranch params settings accumulator root children =
    Html.div
        (Render.TreeSupport.renderAttributes settings root ++
            [ Html.Attributes.style "display" "flex"
            , Html.Attributes.style "flex-direction" "column"
            , Html.Attributes.style "width" "100%"
            , Html.Attributes.style "gap" (String.fromFloat settings.interBlockSpacing ++ "px")
            ])
        (Render.TreeSupport.renderBody params settings accumulator root
            ++ List.map (renderTree_ params settings accumulator) children
        )

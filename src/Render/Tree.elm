module Render.Tree exposing (renderTree)

{-| This module provides a refactored implementation of tree rendering using the new abstractions.

@docs renderTree

-}

import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock)
import Dict
import Html exposing (Html)
import Html.Attributes
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

        fontStyle =
            case Dict.get "style" root.properties of
                Just "italic" ->
                    "italic"

                _ ->
                    "normal"
    in
    Html.div
        [ Html.Attributes.style "width" "100%"
        , Html.Attributes.style "font-style" fontStyle
        , Html.Attributes.style "font-size" (String.fromInt settings.fontSize ++ "px")
        ]
        [ renderTree_ params settings accumulator 0 tree ]


renderTree_ :
    XMarkdown.Types.CompilerParameters
    -> Render.Theme.RenderSettings
    -> Accumulator
    -> Int
    -> RoseTree.Tree.Tree ExpressionBlock
    -> Html MarkupMsg
renderTree_ params settings accumulator depth tree =
    let
        root =
            RoseTree.Tree.value tree
    in
    case RoseTree.Tree.children tree of
        [] ->
            -- Leaf node: just render the block
            renderLeafNode params settings accumulator depth root

        children ->
            -- Branch node: render based on block type
            renderBranchNode params settings accumulator depth root children


{-| Render a leaf node (a block with no children) - returns Html.
`depth` is the number of ancestors of the node in its tree (root = 0).
-}
renderLeafNode :
    XMarkdown.Types.CompilerParameters
    -> RenderSettings
    -> Accumulator
    -> Int
    -> ExpressionBlock
    -> Html MarkupMsg
renderLeafNode params settings accumulator depth root =
    let
        attrs =
            Render.TreeSupport.renderAttributes settings root
    in
    Html.div (attrs ++ indentAttributes depth)
        (Render.TreeSupport.renderBody params settings accumulator depth root)


{-| Relative indentation: a node at depth > 0 carries one constant unit of
left padding on its own container; deeper nesting accumulates through the
containment of child divs inside their parent's div, so a node at depth d
sits at d units absolute.
-}
indentAttributes : Int -> List (Html.Attribute MarkupMsg)
indentAttributes depth =
    if depth == 0 then
        []

    else
        [ Html.Attributes.style "padding-left" "12px"
        , Html.Attributes.style "box-sizing" "border-box"
        ]


{-| Render a branch node (a block with children) - returns Html
-}
renderBranchNode :
    XMarkdown.Types.CompilerParameters
    -> RenderSettings
    -> Accumulator
    -> Int
    -> ExpressionBlock
    -> List (Tree ExpressionBlock)
    -> Html MarkupMsg
renderBranchNode params settings accumulator depth root children =
    renderStandardBranch params settings accumulator depth root children


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
    -> Int
    -> ExpressionBlock
    -> List (Tree ExpressionBlock)
    -> Html MarkupMsg
renderStandardBranch params settings accumulator depth root children =
    Html.div
        (Render.TreeSupport.renderAttributes settings root
            ++ [ Html.Attributes.style "display" "flex"
               , Html.Attributes.style "flex-direction" "column"
               , Html.Attributes.style "width" "100%"
               , Html.Attributes.style "gap" (String.fromFloat settings.interBlockSpacing ++ "px")
               ]
            ++ indentAttributes depth
        )
        (Render.TreeSupport.renderBody params settings accumulator depth root
            ++ List.map (renderTree_ params settings accumulator (depth + 1)) children
        )

module Render.Tree exposing (renderTree)

{-| This module provides a refactored implementation of tree rendering using the new abstractions.

@docs renderTree

-}

import Dict
import Element exposing (Element)
import Element.Background
import Element.Border
import Element.Font
import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock)
import Render.Attributes
import Render.Settings exposing (RenderSettings)
import Render.Theme
import Render.TreeSupport
import RoseTree.Tree exposing (Tree)
import Scripta.Msg exposing (MarkupMsg)
import Scripta.Types


{-| Render a tree of expression blocks
-}
renderTree :
    Scripta.Types.CompilerParameters
    -> Render.Settings.RenderSettings
    -> Accumulator
    -> RoseTree.Tree.Tree ExpressionBlock
    -> Element MarkupMsg
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

        backgroundColor =
            Render.Settings.getThemedElementColor .offsetBackground params.theme

        style =
            case Dict.get "style" root.properties of
                Just "italic" ->
                    Element.Font.italic

                _ ->
                    Element.Font.unitalicized

        bgColorAttr : Element.Color
        bgColorAttr =
            Render.Settings.getThemedElementColor .offsetBackground params.theme

        -- Determine if the root bloc`k is a box-like block
        --blockAttrs : List (Element.Attribute MarkupMsg)
        borderColor =
            case params.theme of
                Render.Theme.Light ->
                    Element.rgba 0.7 0.8 0.9 1

                Render.Theme.Dark ->
                    Element.rgba 0.6 0.6 0.6 0.5

        width2 =
            Element.width <| Element.px (settings.width - 60)

        blockAttrs =
            style :: Element.Font.size settings.fontSize :: (Element.width <| Element.px settings.width) :: Element.Background.color bgColorAttr :: []
    in
    if isBoxLike root then
        Element.column blockAttrs
            [ Element.column
                [ Element.paddingEach { left = 0, right = 0, top = 0, bottom = 18 }
                , Element.Border.color borderColor
                , Element.Border.width 4
                , Element.centerX
                , width2
                ]
                [ renderTree_ params
                    { settings
                        | width = settings.width - 24
                        , backgroundColor = backgroundColor
                    }
                    accumulator
                    tree
                ]
            ]

    else
        Element.column [ style, Element.Font.size settings.fontSize ] [ renderTree_ params settings accumulator tree ]


renderTree_ :
    Scripta.Types.CompilerParameters
    -> Render.Settings.RenderSettings
    -> Accumulator
    -> RoseTree.Tree.Tree ExpressionBlock
    -> Element MarkupMsg
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


{-| Render a leaf node (a block with no children)
-}
renderLeafNode :
    Scripta.Types.CompilerParameters
    -> RenderSettings
    -> Accumulator
    -> ExpressionBlock
    -> Element MarkupMsg
renderLeafNode params settings accumulator root =
    Element.column (Render.TreeSupport.renderAttributes settings root ++ getBlockAttributes root ++ Render.Settings.unrollTheme params.theme)
        (Render.TreeSupport.renderBody params settings accumulator root)


{-| Render a branch node (a block with children)
-}
renderBranchNode :
    Scripta.Types.CompilerParameters
    -> RenderSettings
    -> Accumulator
    -> ExpressionBlock
    -> List (Tree ExpressionBlock)
    -> Element MarkupMsg
renderBranchNode params settings accumulator root children =
    renderStandardBranch params settings accumulator root children


{-|

    Render a standard branch node:
     - render the body of the root
     - render the forest     using each child's attributes plus those inherited from the root.

     (( Something like that ))

-}
renderStandardBranch :
    Scripta.Types.CompilerParameters
    -> RenderSettings
    -> Accumulator
    -> ExpressionBlock
    -> List (Tree ExpressionBlock)
    -> Element MarkupMsg
renderStandardBranch params settings accumulator root children =
    Element.column (Element.spacing (round settings.interBlockSpacing) :: getBlockAttributes root)
        (Render.TreeSupport.renderBody params settings accumulator root
            ++ List.map (renderTree_ params settings accumulator) children
        )


{-| Get attributes for a block using the consolidated Attributes module
-}
getBlockAttributes : ExpressionBlock -> List (Element.Attribute MarkupMsg)
getBlockAttributes block =
    Render.Attributes.getBlockAttributes block

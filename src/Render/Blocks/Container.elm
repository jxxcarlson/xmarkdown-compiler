module Render.Blocks.Container exposing (registerRenderers)

{-| This module provides renderers for container blocks.

@docs registerRenderers

-}

import Either exposing (Either(..))
import Element exposing (Element)
import Element.Font as Font
import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock)
import List.Extra
import Render.BlockRegistry exposing (BlockRegistry)
import Render.Blocks.Stack as Stack
import Render.Constants
import Render.Expression
import Render.Settings exposing (RenderSettings)
import Render.Sync
import Scripta.Msg exposing (MarkupMsg)


{-| Register all container block renderers to the registry
-}
registerRenderers : BlockRegistry -> BlockRegistry
registerRenderers registry =
    Render.BlockRegistry.registerBatch
        [ ( "itemList", itemList )
        , ( "numberedList", numberedList )
        ]
        registry


itemList : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
itemList count acc settings _ block =
    let
        listOfExprList : List AST.Language.Expression
        listOfExprList =
            case block.body of
                Left _ ->
                    []

                Right list ->
                    list

        renderItem : RenderSettings -> AST.Language.Expression -> Element MarkupMsg
        renderItem settings_ expr =
            let
                indentation =
                    case expr of
                        AST.Language.ExprList n _ _ ->
                            n

                        _ ->
                            0

                level_ =
                    indentation // 2
            in
            Element.row [ Element.paddingEach { left = 0, right = 0, top = 0, bottom = 4 }, Element.width (Element.px (settings.width - Render.Constants.defaultIndentWidth)) ]
                [ Element.el [ Element.alignTop, Element.paddingEach { left = 8 * (indentation + 1), right = 12, top = 0, bottom = 0 } ] (Element.text (itemLabel level_))
                , Element.paragraph (Render.Sync.attributes settings_ block)
                    (Render.Expression.render count acc settings [] expr :: [])
                ]
    in
    Element.column (Element.spacing 2 :: Render.Sync.attributes settings block)
        (List.map (renderItem settings) listOfExprList)


numberedList : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
numberedList _ acc settings _ block =
    let
        indentation_ expr_ =
            case expr_ of
                AST.Language.ExprList n _ _ ->
                    n

                _ ->
                    0

        level expr_ =
            1 + indentation_ expr_ // 2

        listOfExprList : List AST.Language.Expression
        listOfExprList =
            case block.body of
                Left _ ->
                    []

                Right list ->
                    list

        preRenderStep : AST.Language.Expression -> ( Stack.Stack, List Int ) -> ( Stack.Stack, List Int )
        preRenderStep expr ( stack_, intList ) =
            let
                newStack_ =
                    Stack.newStack (level expr) stack_
            in
            ( newStack_, (Stack.top newStack_ |> Maybe.withDefault 1) :: intList )

        makeLabels : List AST.Language.Expression -> List Int
        makeLabels exprs =
            List.foldl preRenderStep ( [], [] ) exprs
                |> Tuple.second
                |> List.reverse

        renderNumberedItem_ : Int -> AST.Language.Expression -> Element MarkupMsg
        renderNumberedItem_ k expr =
            Element.row
                [ Element.width (Element.px 400)
                , Element.paddingEach { left = 9 * (1 + indentation_ expr), right = 0, top = 0, bottom = 0 }
                ]
                [ renderNumberedLabel settings (level expr) k
                , Element.paragraph (Render.Sync.attributes settings block)
                    (Render.Expression.render 0 acc settings [] expr :: [])
                ]
    in
    Element.column (Element.spacing 2 :: Render.Sync.attributes settings block)
        (List.map2 renderNumberedItem_ (makeLabels listOfExprList) listOfExprList)


renderNumberedLabel settings level_ index_ =
    Element.el
        [ Font.size (Render.Settings.scaleFont settings 14)
        , Element.alignTop
        , Element.width (Element.px 18)

        --, Render.Utility.leftPadding (settings.leftIndentation + 12)
        , Font.color (Render.Settings.getThemedElementColor .text settings.theme)
        ]
        (Element.text <| numbering_ (level_ - 1) index_ ++ ". ")


itemLabel : Int -> String
itemLabel level_ =
    let
        label_ =
            case modBy 3 level_ of
                0 ->
                    String.fromChar '•'

                1 ->
                    String.fromChar '○'

                _ ->
                    "◊"
    in
    label_


numbering_ : Int -> Int -> String
numbering_ level_ index_ =
    let
        alphabet =
            [ "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z" ]

        romanNumerals =
            [ "i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x", "xi", "xii", "xiii", "xiv", "xv", "xvi", "xvii", "xviii", "xix", "xx", "xi", "xxii", "xxiii", "xxiv", "xxv", "vi" ]

        alpha k =
            List.Extra.getAt (modBy 26 (k - 1)) alphabet |> Maybe.withDefault "a"

        roman k =
            List.Extra.getAt (modBy 26 (k - 1)) romanNumerals |> Maybe.withDefault "i"

        label_ =
            case modBy 3 level_ of
                1 ->
                    alpha index_

                2 ->
                    roman index_

                _ ->
                    String.fromInt index_
    in
    label_

module Render.Attributes exposing (getBlockAttributes)

{-| This module consolidates attribute handling for various block types.

Instead of having attribute logic scattered across multiple files, this module
provides a unified approach to determining the attributes for any given block.

@docs getBlockAttributes

-}

import Element
import Generic.BlockUtilities
import Generic.Language exposing (ExpressionBlock)
import Render.BlockType as BlockType exposing (BlockType(..))
import Render.Utility


{-| Main function to get attributes for a block based on its type
-}
getBlockAttributes : ExpressionBlock -> List (Element.Attribute msg)
getBlockAttributes block =
    let
        blockName =
            Generic.BlockUtilities.getExpressionBlockName block
                |> Maybe.withDefault ""

        blockType =
            BlockType.fromString blockName

        standardAttrs =
            [ Render.Utility.idAttributeFromInt block.meta.lineNumber
            ]
    in
    standardAttrs ++ getTypeSpecificAttributes blockType


{-| Get attributes specific to a block type
-}
getTypeSpecificAttributes : BlockType -> List (Element.Attribute msg)
getTypeSpecificAttributes blockType =
    case blockType of
        TextBlock textType ->
            case textType of
                BlockType.Quotation ->
                    getQuotationAttributes

        _ ->
            []


{-| Standard left padding for indented content
-}
standardLeftPadding : Int
standardLeftPadding =
    12


{-| Get attributes for quotation blocks
-}
getQuotationAttributes : List (Element.Attribute msg)
getQuotationAttributes =
    [ Element.paddingEach { left = standardLeftPadding, right = 0, top = 0, bottom = 0 }
    ]

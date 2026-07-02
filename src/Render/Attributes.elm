module Render.Attributes exposing (getBlockAttributes)

{-| This module consolidates attribute handling for various block types.

Instead of having attribute logic scattered across multiple files, this module
provides a unified approach to determining the attributes for any given block.

@docs getBlockAttributes

-}

import AST.BlockUtilities
import AST.Language exposing (ExpressionBlock)
import Html
import Html.Attributes
import Render.BlockType as BlockType exposing (BlockType(..))
import Render.Utility


{-| Main function to get attributes for a block based on its type
-}
getBlockAttributes : ExpressionBlock -> List (Html.Attribute msg)
getBlockAttributes block =
    let
        blockName =
            AST.BlockUtilities.getExpressionBlockName block
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
getTypeSpecificAttributes : BlockType -> List (Html.Attribute msg)
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
getQuotationAttributes : List (Html.Attribute msg)
getQuotationAttributes =
    [ Html.Attributes.style "padding-left" (String.fromInt standardLeftPadding)
    ]

module XMarkdown.Block.BlockUtilities exposing
    ( dropLast
    , getExpressionBlockName
    , getPrimitiveBlockName
    , updateMeta
    )

import AST.Language exposing (BlockMeta, ExpressionBlock, Heading(..), PrimitiveBlock)


updateMeta : (BlockMeta -> BlockMeta) -> { a | meta : BlockMeta } -> { a | meta : BlockMeta }
updateMeta transformMeta block =
    let
        oldMeta =
            block.meta

        newMeta =
            transformMeta oldMeta
    in
    { block | meta = newMeta }


getPrimitiveBlockName : PrimitiveBlock -> Maybe String
getPrimitiveBlockName block =
    case block.heading of
        Paragraph ->
            Nothing

        Ordinary name ->
            Just name

        Verbatim name ->
            Just name


getExpressionBlockName : ExpressionBlock -> Maybe String
getExpressionBlockName block =
    case block.heading of
        Paragraph ->
            Nothing

        Ordinary name ->
            Just name

        Verbatim name ->
            Just name


dropLast : List a -> List a
dropLast list =
    let
        n =
            List.length list
    in
    List.take (n - 1) list

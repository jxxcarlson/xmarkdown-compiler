module XMarkdown.AST exposing (AST(..), forest)

{-| The parsed document, as handed to apps by `XMarkdown.API.parse`.

This module is internal: apps see `AST` through the alias in `XMarkdown.API`
and cannot reach the constructor, so the forest inside can change without
breaking them. Exporters inside the package (`HTML.Export`) unwrap it.

-}

import AST.Forest exposing (Forest)
import AST.Language exposing (ExpressionBlock)


type AST
    = AST (Forest ExpressionBlock)


forest : AST -> Forest ExpressionBlock
forest (AST f) =
    f

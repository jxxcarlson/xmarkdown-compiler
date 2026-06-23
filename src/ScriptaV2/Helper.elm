module ScriptaV2.Helper exposing
    ( getBlockNames, getImageUrls
    , title, viewToc, tableOfContents, existsBlockWithName, matchingIdsInAST
    )

{-| Helper functions for working with compiled XMarkdown documents.


## Getters

@docs getBlockNames, getImageUrls


## Render

@docs title, viewToc, tableOfContents, existsBlockWithName, matchingIdsInAST

-}

import Either
import Element exposing (Attribute, Element)
import Generic.ASTTools
import Generic.Acc exposing (Accumulator)
import Generic.Forest exposing (Forest)
import Generic.Language exposing (ExpressionBlock)
import Library.Tree
import List.Extra
import Maybe.Extra
import Render.Block
import Render.Settings exposing (DisplaySettings)
import Render.TOC
import RoseTree.Tree as Tree
import ScriptaV2.Msg exposing (MarkupMsg)
import ScriptaV2.Types
import Time


{-| -}
banner : List (Tree.Tree ExpressionBlock) -> Maybe ExpressionBlock
banner =
    Generic.ASTTools.banner


{-| -}
getName : ExpressionBlock -> Maybe String
getName =
    Generic.Language.getName


{-| -}
renderBody : Int -> Accumulator -> Render.Settings.RenderSettings -> List (Attribute MarkupMsg) -> ExpressionBlock -> List (Element MarkupMsg)
renderBody =
    Render.Block.renderBody


{-| -}
setName : String -> ExpressionBlock -> ExpressionBlock
setName =
    Generic.Language.setName


{-| -}
title : Forest ExpressionBlock -> String
title =
    Generic.ASTTools.title


{-| -}
viewToc : ScriptaV2.Types.CompilerParameters -> Int -> Accumulator -> List (Attribute MarkupMsg) -> Forest ExpressionBlock -> List (Element MarkupMsg)
viewToc params counter acc attr ast =
    Render.TOC.viewWithTitle params counter acc attr ast


{-| -}
getImageUrls : Forest ExpressionBlock -> List String
getImageUrls syntaxTree =
    getImageUrlsFromExpressions syntaxTree
        ++ getImageUrlsFromBlocks syntaxTree
        |> List.sort
        |> List.Extra.unique


getImageUrlsFromExpressions : Forest ExpressionBlock -> List String
getImageUrlsFromExpressions syntaxTree =
    syntaxTree
        |> List.map Library.Tree.flatten
        |> List.concat
        |> List.map (\block -> Either.toList block.body)
        |> List.concat
        |> List.concat
        |> Generic.ASTTools.filterExpressionsOnName "image"
        |> List.map (Generic.ASTTools.getText >> Maybe.map String.trim)
        |> List.map (Maybe.andThen extractUrl)
        |> Maybe.Extra.values


getImageUrlsFromBlocks : Forest ExpressionBlock -> List String
getImageUrlsFromBlocks syntaxTree =
    syntaxTree
        |> List.map Library.Tree.flatten
        |> List.concat
        |> Generic.ASTTools.filterBlocksOnName "image"
        |> List.map Generic.Language.getVerbatimContent
        |> Maybe.Extra.values


{-| -}
getBlockNames : Forest ExpressionBlock -> List String
getBlockNames syntaxTree =
    syntaxTree
        |> List.map Library.Tree.flatten
        |> List.concat
        |> List.map Generic.Language.getName
        |> Maybe.Extra.values


extractUrl : String -> Maybe String
extractUrl str =
    str |> String.split " " |> List.head



-- PARSER INTERFACE


body : { a | tree : Forest ExpressionBlock } -> Forest ExpressionBlock
body editRecord =
    editRecord.tree



-- MORE --


{-| -}
tableOfContents : Forest ExpressionBlock -> List ExpressionBlock
tableOfContents =
    Generic.ASTTools.tableOfContents


{-| -}
existsBlockWithName : List (Tree.Tree ExpressionBlock) -> String -> Bool
existsBlockWithName =
    Generic.ASTTools.existsBlockWithName


{-| -}
matchingIdsInAST : String -> Forest ExpressionBlock -> List String
matchingIdsInAST =
    Generic.ASTTools.matchingIdsInAST

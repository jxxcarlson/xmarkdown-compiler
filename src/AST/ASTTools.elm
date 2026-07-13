module AST.ASTTools exposing
    ( banner
    , tableOfContents
    , title
    )

import AST.Language exposing (Expr(..), Expression, ExpressionBlock, Heading(..))
import Library.Tree
import Maybe.Extra
import RoseTree.Tree as Tree exposing (Tree)


filterBlocksOnName : String -> List ExpressionBlock -> List ExpressionBlock
filterBlocksOnName name blocks =
    List.filter (matchBlockName name) blocks


filterBlocksOnName2 : String -> String -> List ExpressionBlock -> List ExpressionBlock
filterBlocksOnName2 name name2 blocks =
    List.filter (matchBlockName2 name name2) blocks



--filterForestOnBlockNames : String -> Forest ExpressionBlock -> Forest ExpressionBlock
--filterForestOnBlockNames name forest =
--    List.filter (\tree -> predicate (labelName tree)) forest


matchBlockName : String -> ExpressionBlock -> Bool
matchBlockName key block =
    Just key == AST.Language.getName block


matchBlockName2 : String -> String -> ExpressionBlock -> Bool
matchBlockName2 key key2 block =
    (Just key == AST.Language.getName block) || (Just key2 == AST.Language.getName block)


getBlockByName : String -> List (Tree.Tree ExpressionBlock) -> Maybe ExpressionBlock
getBlockByName name ast =
    ast
        |> List.map Library.Tree.flatten
        |> List.concat
        |> filterBlocksOnName name
        |> List.head


banner : List (Tree ExpressionBlock) -> Maybe ExpressionBlock
banner ast =
    ast |> getBlockByName "banner" |> Maybe.map (changeName "banner" "visibleBanner")


changeName : String -> String -> ExpressionBlock -> ExpressionBlock
changeName oldName newName block =
    if block.heading == Ordinary oldName then
        { block | heading = Ordinary newName }

    else
        block


getValue : String -> List (Tree.Tree ExpressionBlock) -> String
getValue key ast =
    case getBlockByName key ast of
        Nothing ->
            "(" ++ key ++ ")"

        Just block ->
            AST.Language.getExpressionContent block
                |> List.map getText
                |> Maybe.Extra.values
                |> String.join ""


title : List (Tree ExpressionBlock) -> String
title ast =
    getValue "title" ast


tableOfContents : List (Tree ExpressionBlock) -> List ExpressionBlock
tableOfContents ast =
    filterBlocksOnName2 "section" "chapter" (List.map Library.Tree.flatten ast |> List.concat)


getText : Expression -> Maybe String
getText expression =
    case expression of
        Text str _ ->
            Just str

        VFun _ str _ ->
            Just (String.replace "`" "" str)

        Fun _ expressions _ ->
            List.map getText expressions |> Maybe.Extra.values |> String.join " " |> Just

        ExprList _ _ _ ->
            Nothing

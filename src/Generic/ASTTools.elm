module Generic.ASTTools exposing
    ( banner
    , exprListToStringList
    , filterExpressionsOnName
    , filterExpressionsOnName_
    , filterExprs
    , filterForestOnLabelNames
    , filterOutExpressionsOnName
    , getText
    , isBlank
    , stringValueOfList
    , tableOfContents
    , title
    )

import Generic.Forest exposing (Forest)
import Generic.Language exposing (Expr(..), Expression, ExpressionBlock, Heading(..))
import Library.Tree
import Maybe.Extra
import RoseTree.Tree as Tree exposing (Tree)


filterExpressionsOnName : String -> List Expression -> List Expression
filterExpressionsOnName name exprs =
    List.filter (matchExprOnName name) exprs


filterOutExpressionsOnName : String -> List Expression -> List Expression
filterOutExpressionsOnName name exprs =
    List.filter (\expr -> not (matchExprOnName name expr)) exprs


filterExpressionsOnName_ : String -> List Expression -> List Expression
filterExpressionsOnName_ name exprs =
    List.filter (matchExprOnName_ name) exprs


filterExprs : (Expression -> Bool) -> List Expression -> List Expression
filterExprs predicate list =
    List.filter (\item -> predicate item) list


isBlank : Expression -> Bool
isBlank expr =
    case expr of
        Text content _ ->
            if String.trim content == "" then
                True

            else
                False

        _ ->
            False


filterBlocksOnName : String -> List ExpressionBlock -> List ExpressionBlock
filterBlocksOnName name blocks =
    List.filter (matchBlockName name) blocks


filterBlocksOnName2 : String -> String -> List ExpressionBlock -> List ExpressionBlock
filterBlocksOnName2 name name2 blocks =
    List.filter (matchBlockName2 name name2) blocks



--filterForestOnBlockNames : String -> Forest ExpressionBlock -> Forest ExpressionBlock
--filterForestOnBlockNames name forest =
--    List.filter (\tree -> predicate (labelName tree)) forest


filterForestOnLabelNames : (Maybe String -> Bool) -> Forest ExpressionBlock -> Forest ExpressionBlock
filterForestOnLabelNames predicate forest =
    List.filter (\tree -> predicate (labelName tree)) forest


labelName : Tree ExpressionBlock -> Maybe String
labelName tree =
    Tree.value tree |> Generic.Language.getName


matchBlockName : String -> ExpressionBlock -> Bool
matchBlockName key block =
    Just key == Generic.Language.getName block


matchBlockName2 : String -> String -> ExpressionBlock -> Bool
matchBlockName2 key key2 block =
    (Just key == Generic.Language.getName block) || (Just key2 == Generic.Language.getName block)


matchExprOnName : String -> Expression -> Bool
matchExprOnName name expr =
    Just name == Generic.Language.getFunctionName expr


matchExprOnName_ : String -> Expression -> Bool
matchExprOnName_ name expr =
    case Generic.Language.getFunctionName expr of
        Nothing ->
            False

        Just name2 ->
            name == name2


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
            Generic.Language.getExpressionContent block
                |> List.map getText
                |> Maybe.Extra.values
                |> String.join ""


title : List (Tree ExpressionBlock) -> String
title ast =
    getValue "title" ast


tableOfContents : List (Tree ExpressionBlock) -> List ExpressionBlock
tableOfContents ast =
    filterBlocksOnName2 "section" "chapter" (List.map Library.Tree.flatten ast |> List.concat)


exprListToStringList : List Expression -> List String
exprListToStringList exprList =
    List.map getText exprList
        |> Maybe.Extra.values
        |> List.map String.trim
        |> List.filter (\s -> s /= "")


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


stringValueOfList : List Expression -> String
stringValueOfList textList =
    String.join " " (List.map stringValue textList)


stringValue : Expression -> String
stringValue expr =
    case expr of
        Text str _ ->
            str

        Fun _ textList _ ->
            String.join " " (List.map stringValue textList)

        VFun _ str _ ->
            str

        ExprList _ _ _ ->
            "[ExprList]"

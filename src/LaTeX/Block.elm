module LaTeX.Block exposing (exportForest)

{-| XMarkdown blocks to LaTeX.
-}

import AST.Forest exposing (Forest)
import AST.Language exposing (Expr(..), Expression, ExpressionBlock, Heading(..))
import Dict
import Either exposing (Either(..))
import LaTeX.Escape
import LaTeX.Inline
import List.Extra
import RoseTree.Tree as Tree exposing (Tree)


exportForest : Forest ExpressionBlock -> String
exportForest forest =
    forest
        |> group
        |> List.map exportGroup
        |> List.filter (not << String.isEmpty)
        |> String.join "\n\n"


{-| Consecutive loose list items (separate `item` / `numbered` trees) become one
LaTeX list environment; every other tree stands alone.
-}
type Group
    = Single (Tree ExpressionBlock)
    | Items String (List (Tree ExpressionBlock))


group : Forest ExpressionBlock -> List Group
group forest =
    List.foldr
        (\tree acc ->
            case ( listEnvironment tree, acc ) of
                ( Just env, (Items env2 trees) :: rest ) ->
                    if env == env2 then
                        Items env (tree :: trees) :: rest

                    else
                        Items env [ tree ] :: acc

                ( Just env, _ ) ->
                    Items env [ tree ] :: acc

                ( Nothing, _ ) ->
                    Single tree :: acc
        )
        []
        forest


listEnvironment : Tree ExpressionBlock -> Maybe String
listEnvironment tree =
    case (Tree.value tree).heading of
        Ordinary "item" ->
            Just "itemize"

        Ordinary "numbered" ->
            Just "enumerate"

        _ ->
            Nothing


exportGroup : Group -> String
exportGroup g =
    case g of
        Single tree ->
            exportTree tree

        Items env trees ->
            environment env (trees |> List.map exportItem |> String.join "\n")


exportItem : Tree ExpressionBlock -> String
exportItem tree =
    let
        item =
            itemLine (inlineBody (Tree.value tree))
    in
    case Tree.children tree of
        [] ->
            item

        children ->
            item ++ "\n" ++ exportForest children


exportTree : Tree ExpressionBlock -> String
exportTree tree =
    case Tree.children tree of
        [] ->
            exportBlock (Tree.value tree)

        children ->
            exportBlock (Tree.value tree) ++ "\n\n" ++ exportForest children


exportBlock : ExpressionBlock -> String
exportBlock block =
    case block.heading of
        Paragraph ->
            inlineBody block

        Ordinary "titleBlock" ->
            -- Becomes \\title / \\author / \\date in the preamble (LaTeX.Export).
            ""

        Ordinary "section" ->
            section block

        Ordinary "quotation" ->
            environment "quote" (quotation block)

        Ordinary "table" ->
            table block

        Ordinary "equation" ->
            LaTeX.Inline.math "\\begin{equation}\n" "\n\\end{equation}" (mathSource block)

        Ordinary "aligned" ->
            LaTeX.Inline.math "\\begin{align*}\n" "\n\\end{align*}" (mathSource block)

        Ordinary "array" ->
            array block

        Ordinary "chem" ->
            "\\[\n\\ce{" ++ mathSource block ++ "}\n\\]"

        Verbatim "math" ->
            LaTeX.Inline.math "\\[\n" "\n\\]" (mathSource block)

        Verbatim "code" ->
            case block.body of
                Left str ->
                    environment "verbatim" str

                Right _ ->
                    environment "verbatim" ""

        Ordinary "itemList" ->
            compactList "itemize" block

        Ordinary "numberedList" ->
            compactList "enumerate" block

        Ordinary name ->
            unsupported name block

        Verbatim name ->
            unsupported name block


inlineBody : ExpressionBlock -> String
inlineBody block =
    case block.body of
        Right exprs ->
            LaTeX.Inline.exportExprs exprs

        Left str ->
            LaTeX.Escape.text str


section : ExpressionBlock -> String
section block =
    let
        command =
            case Dict.get "level" block.properties |> Maybe.andThen String.toInt of
                Just 2 ->
                    "subsection"

                Just 3 ->
                    "subsubsection"

                Just 4 ->
                    "paragraph"

                _ ->
                    "section"
    in
    "\\" ++ command ++ "{" ++ String.trim (noFloatsBody block) ++ "}"


{-| The math source of a math block. `$$` / `\[` blocks are Verbatim with the
closing `$$` still on the body. Ordinary blocks (`| equation` etc.) are read
from the source text, because their parsed body can contain token errors
(e.g. for `\\`).
-}
mathSource : ExpressionBlock -> String
mathSource block =
    case ( block.heading, block.body ) of
        ( Verbatim _, Left str ) ->
            str |> String.trim |> dropSuffix "$$" |> dropSuffix "\\]" |> String.trim

        _ ->
            block.meta.sourceText
                |> String.lines
                |> List.drop 1
                |> String.join "\n"
                |> String.trim


dropSuffix : String -> String -> String
dropSuffix suffix str =
    if String.endsWith suffix str then
        String.dropRight (String.length suffix) str

    else
        str


array : ExpressionBlock -> String
array block =
    let
        source =
            mathSource block

        columns =
            if List.isEmpty block.args then
                source
                    |> String.lines
                    |> List.head
                    |> Maybe.withDefault ""
                    |> String.indexes "&"
                    |> List.length
                    |> (\n -> String.repeat (n + 1) "c")

            else
                String.concat block.args
    in
    LaTeX.Inline.math ("\\[\n\\begin{array}{" ++ columns ++ "}\n") "\n\\end{array}\n\\]" source


table : ExpressionBlock -> String
table block =
    let
        rows =
            case block.body of
                Right [ Fun "table" rowExprs _ ] ->
                    List.filterMap row rowExprs

                _ ->
                    []

        row expr =
            case expr of
                Fun "row" cells _ ->
                    Just (List.map cell cells)

                _ ->
                    Nothing

        cell expr =
            case expr of
                Fun "cell" exprs _ ->
                    String.trim (LaTeX.Inline.exportExprsNoFloats exprs)

                other ->
                    String.trim (LaTeX.Inline.exportExprsNoFloats [ other ])

        alignments =
            Dict.get "alignments" block.properties
                |> Maybe.map (String.split ",")
                |> Maybe.withDefault []

        columnCount =
            rows |> List.map List.length |> List.maximum |> Maybe.withDefault 0

        alignment i =
            case List.Extra.getAt i alignments of
                Just a ->
                    if List.member a [ "l", "c", "r" ] then
                        a

                    else
                        "l"

                Nothing ->
                    "l"

        columnSpec =
            List.range 0 (columnCount - 1) |> List.map alignment |> String.concat

        line cells =
            -- After \\ (the previous row's end), TeX reads a leading [ or *
            -- as an argument of \\; an empty group stops it.
            case cells of
                first :: rest ->
                    String.join " & " (protectBracket first :: rest) ++ " \\\\"

                [] ->
                    " \\\\"

        bold c =
            "\\textbf{" ++ c ++ "}"
    in
    case rows of
        [] ->
            ""

        header :: body ->
            environment "center"
                ("\\begin{tabular}{"
                    ++ columnSpec
                    ++ "}\n"
                    ++ String.join "\n"
                        ([ "\\hline", line (List.map bold header), "\\hline" ]
                            ++ List.map line body
                            ++ [ "\\hline" ]
                        )
                    ++ "\n\\end{tabular}"
                )


{-| A compact list is one block whose body is one ExprList per item, carrying
the item's indentation. Items indented deeper than the item before them open
a nested environment of the same kind.
-}
compactList : String -> ExpressionBlock -> String
compactList env block =
    case block.body of
        Right exprs ->
            nestItems env (List.filterMap toItem exprs)

        Left str ->
            LaTeX.Escape.text str


toItem : Expression -> Maybe ( Int, String )
toItem expr =
    case expr of
        ExprList indent exprs _ ->
            Just ( indent, LaTeX.Inline.exportExprs exprs )

        _ ->
            Nothing


nestItems : String -> List ( Int, String ) -> String
nestItems env items =
    case items of
        [] ->
            ""

        ( base, _ ) :: _ ->
            environment env (String.join "\n" (itemsAtLevel env base items))


itemsAtLevel : String -> Int -> List ( Int, String ) -> List String
itemsAtLevel env base items =
    case items of
        [] ->
            []

        ( _, text ) :: rest ->
            let
                ( deeper, remaining ) =
                    List.Extra.span (\( indent, _ ) -> indent > base) rest

                nested =
                    if List.isEmpty deeper then
                        ""

                    else
                        "\n" ++ nestItems env deeper
            in
            (itemLine text ++ nested) :: itemsAtLevel env base remaining


{-| `\\item [x]` would make "x" the item's label; `\\item{}` stops that.
-}
itemLine : String -> String
itemLine text =
    if String.startsWith "[" text then
        "\\item{} " ++ text

    else
        "\\item " ++ text


protectBracket : String -> String
protectBracket text =
    if String.startsWith "[" text || String.startsWith "*" text then
        "{}" ++ text

    else
        text


noFloatsBody : ExpressionBlock -> String
noFloatsBody block =
    case block.body of
        Right exprs ->
            LaTeX.Inline.exportExprsNoFloats exprs

        Left str ->
            LaTeX.Escape.text str


{-| The parser gives a quotation one run per source line, with no newline
between them, and an empty `>` line as `Text ">"`. Runs that are not
adjacent in the source start a new output line; `>` becomes a paragraph
break.
-}
quotation : ExpressionBlock -> String
quotation block =
    case block.body of
        Right exprs ->
            let
                step expr ( acc, previous ) =
                    let
                        meta =
                            AST.Language.getMeta expr
                    in
                    case expr of
                        Text ">" _ ->
                            ( acc, Just ( meta.end, True ) )

                        _ ->
                            let
                                separator =
                                    case previous of
                                        Nothing ->
                                            ""

                                        Just ( _, True ) ->
                                            "\n\n"

                                        Just ( end, False ) ->
                                            if meta.begin > end + 1 then
                                                "\n"

                                            else
                                                ""
                            in
                            ( acc ++ separator ++ LaTeX.Inline.exportExprs [ expr ], Just ( meta.end, False ) )
            in
            List.foldl step ( "", Nothing ) exprs |> Tuple.first

        Left str ->
            LaTeX.Escape.text str


unsupported : String -> ExpressionBlock -> String
unsupported name block =
    "% unsupported: " ++ name ++ "\n" ++ inlineBody block


environment : String -> String -> String
environment name body =
    "\\begin{" ++ name ++ "}\n" ++ body ++ "\n\\end{" ++ name ++ "}"

module HTML.Block exposing (forest)

{-| XMarkdown blocks to HTML.

A section shows a number if and only if its `label` property is set, and its
id is its `tag` property; `HTML.Export` decides both.

-}

import AST.Forest exposing (Forest)
import AST.Language exposing (Expr(..), Expression, ExpressionBlock, Heading(..))
import Dict
import Either exposing (Either(..))
import HTML.Escape
import HTML.Inline exposing (MathMode(..))
import LaTeX.Block
import LaTeX.Image
import LaTeX.Inline
import List.Extra
import RoseTree.Tree as Tree exposing (Tree)


forest : Forest ExpressionBlock -> String
forest trees =
    trees
        |> group
        |> List.map renderGroup
        |> List.filter (not << String.isEmpty)
        |> String.join "\n"


{-| Consecutive loose list items (separate `item` / `numbered` trees) become one
list; every other tree stands alone. Same grouping as `LaTeX.Block`.
-}
type Group
    = Single (Tree ExpressionBlock)
    | Items ListKind (List (Tree ExpressionBlock))


type ListKind
    = Bullets
    | Numbers


group : Forest ExpressionBlock -> List Group
group trees =
    List.foldr
        (\tree acc ->
            case ( listKind tree, acc ) of
                ( Just kind, (Items kind2 items) :: rest ) ->
                    if kind == kind2 then
                        Items kind (tree :: items) :: rest

                    else
                        Items kind [ tree ] :: acc

                ( Just kind, _ ) ->
                    Items kind [ tree ] :: acc

                ( Nothing, _ ) ->
                    Single tree :: acc
        )
        []
        trees


listKind : Tree ExpressionBlock -> Maybe ListKind
listKind tree =
    case (Tree.value tree).heading of
        Ordinary "item" ->
            Just Bullets

        Ordinary "numbered" ->
            Just Numbers

        _ ->
            Nothing


renderGroup : Group -> String
renderGroup g =
    case g of
        Single tree ->
            renderTree tree

        Items kind trees ->
            list kind (trees |> List.map renderItem |> String.concat)


renderItem : Tree ExpressionBlock -> String
renderItem tree =
    let
        children =
            case Tree.children tree of
                [] ->
                    ""

                cs ->
                    forest cs
    in
    "<li>" ++ inlineBody (Tree.value tree) ++ children ++ "</li>"


renderTree : Tree ExpressionBlock -> String
renderTree tree =
    case Tree.children tree of
        [] ->
            renderBlock (Tree.value tree)

        children ->
            renderBlock (Tree.value tree) ++ "\n" ++ forest children


renderBlock : ExpressionBlock -> String
renderBlock block =
    case block.heading of
        Paragraph ->
            paragraph block

        Ordinary "titleBlock" ->
            -- Rendered as the page header by HTML.Export.
            ""

        Ordinary "setcounter" ->
            ""

        Ordinary "shiftandsetcounter" ->
            ""

        Verbatim "settings" ->
            ""

        Ordinary "hrule" ->
            -- Text after the rule in the same block follows as a paragraph.
            case String.trim (inlineBody block) of
                "" ->
                    "<hr class=\"xm-hrule\">"

                rest ->
                    "<hr class=\"xm-hrule\">\n<p class=\"xm-paragraph\">" ++ rest ++ "</p>"

        Ordinary "section" ->
            section block

        Ordinary "quotation" ->
            "<blockquote class=\"xm-quotation\">" ++ quotation block ++ "</blockquote>"

        Ordinary "verse" ->
            "<div class=\"xm-verse\">" ++ verse block ++ "</div>"

        Ordinary "table" ->
            table block

        Ordinary "equation" ->
            "<div class=\"xm-equation\">" ++ HTML.Inline.math DisplayMath (LaTeX.Block.mathSource block) ++ "</div>"

        Ordinary "aligned" ->
            "<div class=\"xm-equation\">"
                ++ HTML.Inline.math DisplayMath ("\\begin{aligned}\n" ++ LaTeX.Block.mathSource block ++ "\n\\end{aligned}")
                ++ "</div>"

        Ordinary "array" ->
            array block

        Ordinary "chem" ->
            "<div class=\"xm-math\" data-display=\"true\">"
                ++ HTML.Escape.text ("\\ce{" ++ LaTeX.Block.mathSource block ++ "}")
                ++ "</div>"

        Verbatim "math" ->
            HTML.Inline.math DisplayMath (LaTeX.Block.mathSource block)

        Verbatim "code" ->
            code block

        Ordinary "itemList" ->
            compactList Bullets block

        Ordinary "numberedList" ->
            compactList Numbers block

        Ordinary name ->
            "<div class=\"xm-block xm-" ++ HTML.Escape.attribute name ++ "\">" ++ inlineBody block ++ "</div>"

        Verbatim name ->
            "<pre class=\"xm-block xm-" ++ HTML.Escape.attribute name ++ "\">" ++ verbatimBody block ++ "</pre>"


inlineBody : ExpressionBlock -> String
inlineBody block =
    case block.body of
        Right exprs ->
            HTML.Inline.exprs exprs

        Left str ->
            HTML.Escape.text str


verbatimBody : ExpressionBlock -> String
verbatimBody block =
    case block.body of
        Left str ->
            HTML.Escape.text str

        Right exprs ->
            HTML.Escape.text (LaTeX.Inline.plainText exprs)


{-| A paragraph whose only content is an image is a figure.
-}
paragraph : ExpressionBlock -> String
paragraph block =
    case block.body of
        Right exprs ->
            case List.filter (not << isBlank) exprs of
                [ Fun name args _ ] ->
                    if name == "image" || name == "img" then
                        figure (LaTeX.Inline.plainText args)

                    else
                        "<p class=\"xm-paragraph\">" ++ HTML.Inline.exprs exprs ++ "</p>"

                _ ->
                    "<p class=\"xm-paragraph\">" ++ HTML.Inline.exprs exprs ++ "</p>"

        Left str ->
            "<p class=\"xm-paragraph\">" ++ HTML.Escape.text str ++ "</p>"


isBlank : Expression -> Bool
isBlank expr =
    case expr of
        Text str _ ->
            String.trim str == ""

        _ ->
            False


figure : String -> String
figure imageText =
    let
        caption =
            case (LaTeX.Image.fromText imageText).caption of
                "" ->
                    ""

                c ->
                    "<figcaption>" ++ HTML.Escape.text c ++ "</figcaption>"
    in
    "<figure class=\"xm-figure\">" ++ HTML.Inline.image imageText ++ caption ++ "</figure>"


section : ExpressionBlock -> String
section block =
    let
        level =
            Dict.get "level" block.properties |> Maybe.andThen String.toInt |> Maybe.withDefault 1

        tag =
            "h" ++ String.fromInt (min 6 (level + 1))

        id =
            case Dict.get "tag" block.properties of
                Just t ->
                    " id=\"" ++ HTML.Escape.attribute t ++ "\""

                Nothing ->
                    ""

        number =
            case Dict.get "label" block.properties of
                Just label ->
                    "<span class=\"xm-section-number\">" ++ HTML.Escape.text label ++ "</span> "

                Nothing ->
                    ""
    in
    "<"
        ++ tag
        ++ " class=\"xm-section\" data-level=\""
        ++ String.fromInt level
        ++ "\""
        ++ id
        ++ ">"
        ++ number
        ++ String.trim (inlineBody block)
        ++ "</"
        ++ tag
        ++ ">"


code : ExpressionBlock -> String
code block =
    let
        language =
            case block.args of
                lang :: _ ->
                    " class=\"language-" ++ HTML.Escape.attribute lang ++ "\""

                [] ->
                    ""
    in
    "<pre class=\"xm-code\"><code" ++ language ++ ">" ++ verbatimBody block ++ "</code></pre>"


array : ExpressionBlock -> String
array block =
    let
        source =
            LaTeX.Block.mathSource block

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
    HTML.Inline.math DisplayMath ("\\begin{array}{" ++ columns ++ "}\n" ++ source ++ "\n\\end{array}")


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
                    String.trim (HTML.Inline.exprs exprs)

                other ->
                    String.trim (HTML.Inline.exprs [ other ])

        alignments =
            Dict.get "alignments" block.properties
                |> Maybe.map (String.split ",")
                |> Maybe.withDefault []

        alignment i =
            case List.Extra.getAt i alignments of
                Just "c" ->
                    "center"

                Just "r" ->
                    "right"

                _ ->
                    "left"

        renderRow cellTag cells =
            "<tr>"
                ++ String.concat
                    (List.indexedMap
                        (\i c -> "<" ++ cellTag ++ " style=\"text-align:" ++ alignment i ++ "\">" ++ c ++ "</" ++ cellTag ++ ">")
                        cells
                    )
                ++ "</tr>"
    in
    case rows of
        [] ->
            ""

        header :: body ->
            "<table class=\"xm-table\"><thead>"
                ++ renderRow "th" header
                ++ "</thead><tbody>"
                ++ String.concat (List.map (renderRow "td") body)
                ++ "</tbody></table>"


{-| One div per line. Leading spaces become left padding of half an em each;
blank lines between stanzas are kept, and blank lines at the start and end
are dropped.
-}
verse : ExpressionBlock -> String
verse block =
    let
        toLine expr =
            case expr of
                ExprList indent exprs _ ->
                    case String.trim (HTML.Inline.exprs exprs) of
                        "" ->
                            Nothing

                        text ->
                            Just ( indent, text )

                _ ->
                    Just ( 0, HTML.Inline.exprs [ expr ] )

        lines =
            case block.body of
                Right exprs ->
                    List.map toLine exprs
                        |> List.Extra.dropWhile ((==) Nothing)
                        |> List.Extra.dropWhileRight ((==) Nothing)

                Left str ->
                    [ Just ( 0, HTML.Escape.text str ) ]

        render line =
            case line of
                Just ( indent, text ) ->
                    if indent > 0 then
                        "<div class=\"xm-verse-line\" style=\"padding-left:"
                            ++ String.fromFloat (toFloat indent / 2)
                            ++ "em\">"
                            ++ text
                            ++ "</div>"

                    else
                        "<div class=\"xm-verse-line\">" ++ text ++ "</div>"

                Nothing ->
                    "<div class=\"xm-verse-blank\"></div>"
    in
    lines |> List.map render |> String.concat


{-| A compact list is one block whose body is one ExprList per item, carrying
the item's indentation. Items indented deeper than the item before them open
a nested list of the same kind.
-}
compactList : ListKind -> ExpressionBlock -> String
compactList kind block =
    case block.body of
        Right exprs ->
            nestItems kind (List.filterMap toItem exprs)

        Left str ->
            HTML.Escape.text str


toItem : Expression -> Maybe ( Int, String )
toItem expr =
    case expr of
        ExprList indent exprs _ ->
            Just ( indent, String.trim (HTML.Inline.exprs exprs) )

        _ ->
            Nothing


nestItems : ListKind -> List ( Int, String ) -> String
nestItems kind items =
    case items of
        [] ->
            ""

        ( base, _ ) :: _ ->
            list kind (String.concat (itemsAtLevel kind base items))


itemsAtLevel : ListKind -> Int -> List ( Int, String ) -> List String
itemsAtLevel kind base items =
    case items of
        [] ->
            []

        ( _, text ) :: rest ->
            let
                ( deeper, remaining ) =
                    List.Extra.span (\( indent, _ ) -> indent > base) rest
            in
            ("<li>" ++ text ++ nestItems kind deeper ++ "</li>") :: itemsAtLevel kind base remaining


list : ListKind -> String -> String
list kind items =
    case kind of
        Bullets ->
            "<ul class=\"xm-list\">" ++ items ++ "</ul>"

        Numbers ->
            "<ol class=\"xm-list\">" ++ items ++ "</ol>"


{-| The parser gives a quotation one run per source line, and an empty `>`
line as `Text ">"`, which starts a new paragraph.
-}
quotation : ExpressionBlock -> String
quotation block =
    case block.body of
        Right exprs ->
            exprs
                |> List.foldr
                    (\expr ( current, done ) ->
                        case expr of
                            Text ">" _ ->
                                ( [], current :: done )

                            _ ->
                                ( expr :: current, done )
                    )
                    ( [], [] )
                |> (\( current, done ) -> current :: done)
                |> List.map (HTML.Inline.exprs >> String.trim)
                |> List.filter (not << String.isEmpty)
                |> List.map (\p -> "<p>" ++ p ++ "</p>")
                |> String.concat

        Left str ->
            "<p>" ++ HTML.Escape.text str ++ "</p>"

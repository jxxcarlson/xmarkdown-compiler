module HTML.Export exposing (TOC(..), SectionNumbers(..), toTextHtml)

{-| Export a parsed XMarkdown document as a complete web page.

The page displays in any browser; math is typeset by KaTeX, loaded from a
CDN. An "Export HTML" button does

    source
        |> XMarkdown.API.parse
        |> HTML.Export.toTextHtml WithTOC WithSectionNumbers

and saves the resulting string. Every element carries an `xm-*` class, so
the page can be restyled with CSS.

@docs TOC, SectionNumbers, toTextHtml

-}

import AST.ASTTools
import AST.Acc
import AST.Forest exposing (Forest)
import AST.Language exposing (ExpressionBlock, Heading(..))
import AST.TitleBlock
import Dict exposing (Dict)
import Either exposing (Either(..))
import HTML.Block
import HTML.Escape
import HTML.Inline
import HTML.Style
import LaTeX.Block
import Library.Tree
import RoseTree.Tree as Tree exposing (Tree)
import Set exposing (Set)
import Tools.String
import XMarkdown.AST exposing (AST)


{-| Whether the page has a table of contents, after the title.
-}
type TOC
    = WithTOC
    | WithoutTOC


{-| Whether section headings (and table-of-contents entries) are numbered:
1, 1.1, 2, …
-}
type SectionNumbers
    = WithSectionNumbers
    | WithoutSectionNumbers


{-| The complete page, from `<!doctype html>` to `</html>`.
-}
toTextHtml : TOC -> SectionNumbers -> AST -> String
toTextHtml toc numbers ast =
    let
        original =
            XMarkdown.AST.forest ast

        forest =
            prepare numbers original

        titleBlock =
            AST.TitleBlock.fromForest original
    in
    [ "<!doctype html>"
    , "<html lang=\"en\">"
    , "<head>"
    , "<meta charset=\"utf-8\">"
    , "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
    , "<title>" ++ HTML.Escape.text (pageTitle titleBlock forest) ++ "</title>"
    , HTML.Style.katexHead
    , "<style id=\"xm-default-style\">"
    , HTML.Style.defaultCss
    , "</style>"
    , "</head>"
    , "<body>"
    , "<article class=\"xm-document\">"
    , header titleBlock
    , tableOfContents toc forest
    , HTML.Block.forest forest
    , "</article>"
    , "</body>"
    , "</html>"
    ]
        |> List.filter (not << String.isEmpty)
        |> String.join "\n"
        |> (\html -> html ++ "\n")


{-| Fix up heading levels and hand-typed numbers (as the LaTeX exporter
does), give the sections unique ids, and number them if wanted.
-}
prepare : SectionNumbers -> Forest ExpressionBlock -> Forest ExpressionBlock
prepare numbers forest =
    let
        tagged =
            forest
                |> LaTeX.Block.normalizeSectionLevels
                |> LaTeX.Block.stripSectionNumbers
                |> AST.Acc.transformAccumulate
                |> Tuple.second
                |> mapForestWithState tagBlock Set.empty
                |> Tuple.second
    in
    case numbers of
        WithSectionNumbers ->
            tagged |> mapForestWithState labelBlock [] |> Tuple.second

        WithoutSectionNumbers ->
            List.map (Tree.mapValues (\block -> { block | properties = Dict.remove "label" block.properties })) tagged


{-| A section's id is the slug of its heading text; a slug already used gets
the first free suffix: the second "notes" is "notes-2" unless a heading
"Notes 2" took that, and so on.
-}
tagBlock : Set String -> ExpressionBlock -> ( Set String, ExpressionBlock )
tagBlock used block =
    if block.heading == Ordinary "section" then
        let
            slug =
                case Tools.String.makeSlug (headingText block) of
                    "" ->
                        "section"

                    s ->
                        s

            free n =
                let
                    candidate =
                        slug ++ "-" ++ String.fromInt n
                in
                if Set.member candidate used then
                    free (n + 1)

                else
                    candidate

            tag =
                if Set.member slug used then
                    free 2

                else
                    slug
        in
        ( Set.insert tag used, { block | properties = Dict.insert "tag" tag block.properties } )

    else
        ( used, block )


{-| Section numbers from the (normalised) levels, at any depth: `AST.Acc`
numbers only four levels. A skipped level counts as 0 (`# A` then `### B`
gives 1 and 1.0.1). The state is the current number, one entry per level.
-}
labelBlock : List Int -> ExpressionBlock -> ( List Int, ExpressionBlock )
labelBlock current block =
    if block.heading == Ordinary "section" then
        let
            n =
                level block

            prefix =
                List.take (n - 1) (current ++ List.repeat n 0)

            next =
                prefix ++ [ (List.drop (n - 1) current |> List.head |> Maybe.withDefault 0) + 1 ]

            label =
                next |> List.map String.fromInt |> String.join "."
        in
        ( next, { block | properties = Dict.insert "label" label block.properties } )

    else
        ( current, block )


mapForestWithState : (s -> a -> ( s, a )) -> s -> List (Tree a) -> ( s, List (Tree a) )
mapForestWithState f state trees =
    List.foldl
        (\tree ( s, done ) ->
            let
                ( s1, value ) =
                    f s (Tree.value tree)

                ( s2, children ) =
                    mapForestWithState f s1 (Tree.children tree)
            in
            ( s2, Tree.branch value children :: done )
        )
        ( state, [] )
        trees
        |> Tuple.mapSecond List.reverse


headingText : ExpressionBlock -> String
headingText block =
    case block.body of
        Right exprs ->
            HTML.Inline.plainText exprs

        Left str ->
            String.trim str


pageTitle : Maybe AST.TitleBlock.TitleBlock -> Forest ExpressionBlock -> String
pageTitle titleBlock forest =
    case Maybe.map .title titleBlock |> Maybe.withDefault "" of
        "" ->
            case List.head (AST.ASTTools.tableOfContents forest) of
                Just section ->
                    case headingText section of
                        "" ->
                            "Untitled"

                        text ->
                            text

                Nothing ->
                    "Untitled"

        title ->
            title


header : Maybe AST.TitleBlock.TitleBlock -> String
header titleBlock =
    case titleBlock of
        Nothing ->
            ""

        Just info ->
            let
                part tag class text =
                    if text == "" then
                        ""

                    else
                        "<" ++ tag ++ " class=\"" ++ class ++ "\">" ++ HTML.Escape.text text ++ "</" ++ tag ++ ">"
            in
            "<header class=\"xm-title-block\">"
                ++ part "h1" "xm-title" info.title
                ++ part "p" "xm-authors" (String.join ", " info.authors)
                ++ part "p" "xm-date" info.date
                ++ "</header>"


{-| Nested lists by section level.
-}
tableOfContents : TOC -> Forest ExpressionBlock -> String
tableOfContents toc forest =
    case toc of
        WithoutTOC ->
            ""

        WithTOC ->
            case AST.ASTTools.tableOfContents forest |> List.map (\b -> ( level b, entry b )) of
                [] ->
                    ""

                (( base, _ ) :: _) as entries ->
                    "<nav class=\"xm-toc\">" ++ tocList base entries ++ "</nav>"


tocList : Int -> List ( Int, String ) -> String
tocList base entries =
    "<ul>" ++ String.concat (tocItems base entries) ++ "</ul>"


tocItems : Int -> List ( Int, String ) -> List String
tocItems base entries =
    case entries of
        [] ->
            []

        ( _, link ) :: rest ->
            let
                deeper =
                    takeWhile (\( l, _ ) -> l > base) rest

                remaining =
                    List.drop (List.length deeper) rest

                nested =
                    case deeper of
                        [] ->
                            ""

                        ( l, _ ) :: _ ->
                            tocList l deeper
            in
            ("<li>" ++ link ++ nested ++ "</li>") :: tocItems base remaining


takeWhile : (a -> Bool) -> List a -> List a
takeWhile pred list =
    case list of
        x :: xs ->
            if pred x then
                x :: takeWhile pred xs

            else
                []

        [] ->
            []


level : ExpressionBlock -> Int
level block =
    Dict.get "level" block.properties |> Maybe.andThen String.toInt |> Maybe.withDefault 1


entry : ExpressionBlock -> String
entry block =
    let
        href =
            Dict.get "tag" block.properties |> Maybe.withDefault ""

        number =
            case Dict.get "label" block.properties of
                Just label ->
                    "<span class=\"xm-section-number\">" ++ HTML.Escape.text label ++ "</span> "

                Nothing ->
                    ""

        text =
            case block.body of
                Right exprs ->
                    String.trim (HTML.Inline.exprs exprs)

                Left str ->
                    HTML.Escape.text (String.trim str)
    in
    "<a href=\"#" ++ HTML.Escape.attribute href ++ "\">" ++ number ++ text ++ "</a>"

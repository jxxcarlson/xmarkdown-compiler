module LaTeX.Export exposing
    ( DocumentInfo
    , exportDocument, exportBody
    , imageUrls
    )

{-| Export XMarkdown source to LaTeX.

@docs DocumentInfo
@docs exportDocument, exportBody
@docs imageUrls

-}

import AST.Language exposing (Expr(..), Expression, ExpressionBlock)
import AST.TitleBlock
import Either exposing (Either(..))
import LaTeX.Block
import LaTeX.Escape
import LaTeX.Image
import LaTeX.Inline
import LaTeX.Preamble
import Library.Tree
import List.Extra
import XMarkdown.Compiler


{-| Title-block information. Fields left empty are taken from the document's
`%title` / `%author` / `%date` block, if it has one. When all fields end up
empty, the document has no \\maketitle.
-}
type alias DocumentInfo =
    { title : String
    , authors : List String
    , date : String
    }


{-| A complete .tex document, ready for pdflatex once the images listed by
`imageUrls` have been downloaded.
-}
exportDocument : DocumentInfo -> String -> String
exportDocument callerInfo source =
    let
        body =
            exportBody source

        info =
            withSourceInfo source callerInfo

        hasTitle =
            info.title /= "" || not (List.isEmpty info.authors) || info.date /= ""

        titleBlock =
            if hasTitle then
                [ "\\title{" ++ LaTeX.Escape.text info.title ++ "}"
                , "\\author{" ++ String.join " \\and " (List.map LaTeX.Escape.text info.authors) ++ "}"
                , "\\date{" ++ LaTeX.Escape.text info.date ++ "}"
                ]

            else
                []

        maketitle =
            if hasTitle then
                [ "\\maketitle", "" ]

            else
                []
    in
    String.join "\n"
        (LaTeX.Preamble.make body
            :: titleBlock
            ++ [ "", "\\begin{document}", "" ]
            ++ maketitle
            ++ [ body, "", "\\end{document}", "" ]
        )


{-| Fill the fields the caller left empty from the source's title block.
-}
withSourceInfo : String -> DocumentInfo -> DocumentInfo
withSourceInfo source info =
    case AST.TitleBlock.fromForest (XMarkdown.Compiler.parseFromString source) of
        Nothing ->
            info

        Just fromSource ->
            { title = orElse info.title fromSource.title
            , authors =
                if List.isEmpty info.authors then
                    fromSource.authors

                else
                    info.authors
            , date = orElse info.date fromSource.date
            }


orElse : String -> String -> String
orElse preferred fallback =
    if String.isEmpty preferred then
        fallback

    else
        preferred


{-| The LaTeX for the document body only, with no preamble, for pasting into
an existing LaTeX document.
-}
exportBody : String -> String
exportBody source =
    source
        |> XMarkdown.Compiler.parseFromString
        |> LaTeX.Block.normalizeSectionLevels
        |> LaTeX.Block.stripSectionNumbers
        |> LaTeX.Block.exportForest


{-| Every image in the document as (url, local path), in order and without
duplicates. The exported LaTeX refers to the local paths; download each url
to its path, relative to the .tex file.
-}
imageUrls : String -> List ( String, String )
imageUrls source =
    source
        |> XMarkdown.Compiler.parseFromString
        |> List.concatMap Library.Tree.flatten
        |> List.concatMap blockImages
        |> List.Extra.unique


blockImages : ExpressionBlock -> List ( String, String )
blockImages block =
    case block.body of
        Right exprs ->
            List.concatMap exprImages exprs

        Left _ ->
            []


exprImages : Expression -> List ( String, String )
exprImages expr =
    case expr of
        Fun name args _ ->
            if name == "image" || name == "img" then
                let
                    image =
                        LaTeX.Image.fromText (LaTeX.Inline.plainText args)
                in
                [ ( image.url, LaTeX.Image.localPath image.url ) ]

            else
                List.concatMap exprImages args

        ExprList _ exprs _ ->
            List.concatMap exprImages exprs

        _ ->
            []

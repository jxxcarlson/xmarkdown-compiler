module XMarkdown.Compiler exposing
    ( view, viewTOC
    , BlockMatch, compile, parseFromString, parseToForestWithAccumulator, searchBlocksContainingText, viewBodyOnly
    )

{-|

@docs CompilerOutput, compileFromString, view, viewTOC

-}

import AST.ASTTools
import AST.Acc exposing (Accumulator)
import AST.Forest exposing (Forest)
import AST.Language exposing (ExpressionBlock)
import Html exposing (Html)
import Html.Attributes
import Parser.Block.ForestTransform
import Parser.Block.Pipeline
import Parser.Block.PrimitiveBlock
import Parser.Inline.Expression
import Render.Block
import Render.TOCTree
import Render.Theme
import Render.Tree
import RoseTree.Tree
import XMarkdown.Config as Config
import XMarkdown.Types exposing (CompilerOutput, CompilerParameters, MarkupMsg)


{-| -}
view : Int -> CompilerOutput -> List (Html MarkupMsg)
view width_ compiled =
    [ Html.div [ Html.Attributes.style "width" (String.fromInt (width_ - 60) ++ "px") ]
        (header compiled)
    , body compiled
    ]


viewBodyOnly : Int -> CompilerOutput -> List (Html MarkupMsg)
viewBodyOnly width_ compiled =
    [ Html.div [ Html.Attributes.style "width" (String.fromInt (width_ - 60) ++ "px") ]
        [ body compiled ]
    ]


{-| -}
header : CompilerOutput -> List (Html MarkupMsg)
header compiled =
    case compiled.banner of
        Nothing ->
            Html.div [ Html.Attributes.style "padding-bottom" "18px" ] [ compiled.title ]
                :: Html.div [ Html.Attributes.style "spacing" "8", Html.Attributes.style "padding-bottom" "72px" ] compiled.toc
                :: []

        Just banner ->
            Html.div [] [ banner ]
                :: (Html.div [ Html.Attributes.style "padding-bottom" "18px" ] [ compiled.title ]
                        :: Html.div [ Html.Attributes.style "spacing" "8", Html.Attributes.style "padding-bottom" "36px" ] compiled.toc
                        :: []
                   )


{-| -}
body : CompilerOutput -> Html MarkupMsg
body compiled =
    Html.div
        [ Html.Attributes.style "display" "flex"
        , Html.Attributes.style "flex-direction" "column"
        , Html.Attributes.style "gap" (String.fromFloat compiled.interBlockSpacing ++ "px")
        ]
        compiled.body


{-| -}
viewTOC : CompilerOutput -> List (Html MarkupMsg)
viewTOC compiled =
    compiled.toc


{-| Compile XMarkdown source lines into renderable output (body, banner, TOC, title).
-}
compile : CompilerParameters -> List String -> CompilerOutput
compile params lines =
    render params (parseToForestWithAccumulator params lines)


{-| -}
parseFromString : String -> Forest ExpressionBlock
parseFromString str =
    parse Config.idPrefix 0 (String.lines str)


{-| Parse source lines into a forest of expression blocks: primitive blocks →
indentation-based tree → expression blocks (with inline expressions parsed).
-}
parse : String -> Int -> List String -> Forest ExpressionBlock
parse idPrefix outerCount lines =
    lines
        |> Parser.Block.PrimitiveBlock.parse idPrefix outerCount
        |> Parser.Block.ForestTransform.forestFromBlocks .indent
        |> AST.Forest.map (Parser.Block.Pipeline.toExpressionBlock Parser.Inline.Expression.parse)



-- M compiler


{-| A block match result from searching for text in the document
-}
type alias BlockMatch =
    { id : String
    , lineNumber : Int
    , numberOfLines : Int
    , sourceText : String
    }


parseToForestWithAccumulator : CompilerParameters -> List String -> ( Accumulator, Forest ExpressionBlock )
parseToForestWithAccumulator params lines =
    AST.Acc.transformAccumulate (parse Config.idPrefix params.editCount lines)


render : CompilerParameters -> ( Accumulator, Forest ExpressionBlock ) -> CompilerOutput
render params ( accumulator_, forest_ ) =
    let
        renderSettings : Render.Theme.RenderSettings
        renderSettings =
            Render.Theme.makeSettings params

        viewParameters =
            { selectedId = params.selectedId
            , counter = params.editCount
            , attr = []
            , settings = renderSettings
            }

        toc : List (Html MarkupMsg)
        toc =
            Render.TOCTree.view params.theme viewParameters forest_

        banner : Maybe (Html MarkupMsg)
        banner =
            AST.ASTTools.banner forest_
                |> Maybe.map (Render.Block.renderBody params.editCount accumulator_ renderSettings [])
                |> Maybe.andThen List.head
                |> Maybe.map (\elem -> Html.div [ Html.Attributes.style "height" "40px" ] [ elem ])

        title : Html MarkupMsg
        title =
            Html.p [ Html.Attributes.style "font-size" (String.fromInt renderSettings.titleSize ++ "px") ] [ Html.text <| AST.ASTTools.title forest_ ]
    in
    { body =
        renderForest params renderSettings accumulator_ forest_
    , banner = banner
    , toc = toc
    , title = title
    , interBlockSpacing = renderSettings.interBlockSpacing
    }


{-|

    renderForest count renderSettings accumulator

-}
renderForest :
    XMarkdown.Types.CompilerParameters
    -> Render.Theme.RenderSettings
    -> AST.Acc.Accumulator
    -> List (RoseTree.Tree.Tree ExpressionBlock)
    -> List (Html MarkupMsg)
renderForest params settings accumulator forest =
    List.map (Render.Tree.renderTree params settings accumulator) forest


{-| Search blocks in the document for text containing the search query.
Returns a list of matching blocks with their metadata.
-}
searchBlocksContainingText : CompilerParameters -> List String -> String -> List BlockMatch
searchBlocksContainingText params lines searchQuery =
    let
        allBlocks =
            forestToBlockList (parse Config.idPrefix params.editCount lines)

        searchLower =
            String.toLower searchQuery
    in
    allBlocks
        |> List.filter (\block -> String.contains searchLower (String.toLower block.meta.sourceText))
        |> List.map
            (\block ->
                { id = "e-" ++ String.fromInt block.meta.lineNumber ++ "." ++ String.fromInt params.editCount
                , lineNumber = block.meta.lineNumber
                , numberOfLines = block.meta.numberOfLines
                , sourceText = block.meta.sourceText
                }
            )


{-| Flatten a forest of blocks into a list by traversing depth-first
-}
forestToBlockList : Forest ExpressionBlock -> List ExpressionBlock
forestToBlockList forest =
    List.concatMap treeToBlockList forest


{-| Flatten a tree of blocks into a list by traversing depth-first
-}
treeToBlockList : RoseTree.Tree.Tree ExpressionBlock -> List ExpressionBlock
treeToBlockList tree =
    let
        root =
            RoseTree.Tree.value tree

        children =
            RoseTree.Tree.children tree
    in
    root :: List.concatMap treeToBlockList children

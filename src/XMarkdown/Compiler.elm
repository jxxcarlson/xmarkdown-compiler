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
import Element exposing (Element)
import Element.Font as Font
import Parser.Block.ForestTransform
import Parser.Block.Pipeline
import Parser.Block.PrimitiveBlock
import Parser.Inline.Expression
import Render.Block
import Render.Settings
import Render.TOCTree
import Render.Tree
import RoseTree.Tree
import XMarkdown.Config as Config
import XMarkdown.Types exposing (CompilerOutput, CompilerParameters, Filter(..), MarkupMsg)


{-| -}
view : Int -> CompilerOutput -> List (Element MarkupMsg)
view width_ compiled =
    [ Element.column [ Element.width (Element.px (width_ - 60)) ]
        (header compiled)
    , body compiled
    ]


viewBodyOnly : Int -> CompilerOutput -> List (Element MarkupMsg)
viewBodyOnly width_ compiled =
    [ Element.column [ Element.width (Element.px (width_ - 60)) ]
        [ body compiled ]
    ]


{-| -}
header : CompilerOutput -> List (Element MarkupMsg)
header compiled =
    case compiled.banner of
        Nothing ->
            Element.el [ bottomPadding 18 ] compiled.title
                :: Element.column [ Element.spacing 8, bottomPadding 72 ] compiled.toc
                :: []

        Just banner ->
            Element.el [] banner
                :: (Element.el [ bottomPadding 18 ] compiled.title
                        :: Element.column [ Element.spacing 8, bottomPadding 36 ] compiled.toc
                        :: []
                   )


{-| -}
body : CompilerOutput -> Element MarkupMsg
body compiled =
    Element.column [ Element.spacing (round compiled.interBlockSpacing), Element.alignTop ] compiled.body


{-| -}
viewTOC : CompilerOutput -> List (Element MarkupMsg)
viewTOC compiled =
    compiled.toc


bottomPadding k =
    Element.paddingEach { left = 0, right = 0, top = 0, bottom = k }


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


{-| -}
filterForest : Filter -> Forest ExpressionBlock -> Forest ExpressionBlock
filterForest filter forest =
    case filter of
        NoFilter ->
            forest

        SuppressDocumentBlocks ->
            forest
                |> AST.ASTTools.filterForestOnLabelNames (\name -> name /= Just "document")
                |> AST.ASTTools.filterForestOnLabelNames (\name -> name /= Just "title")


parseToForestWithAccumulator : CompilerParameters -> List String -> ( Accumulator, Forest ExpressionBlock )
parseToForestWithAccumulator params lines =
    let
        forest =
            filterForest params.filter (parse Config.idPrefix params.editCount lines)
    in
    AST.Acc.transformAccumulate AST.Acc.initialData forest


render : CompilerParameters -> ( Accumulator, Forest ExpressionBlock ) -> CompilerOutput
render params ( accumulator_, forest_ ) =
    let
        renderSettings : Render.Settings.RenderSettings
        renderSettings =
            Render.Settings.defaultRenderSettings params

        --( accumulator, forest ) =
        --    AST.Acc.transformAccumulate AST.Acc.initialData forest_
        viewParameters =
            { idsOfOpenNodes = params.idsOfOpenNodes
            , selectedId = params.selectedId
            , counter = params.editCount
            , attr = []
            , settings = renderSettings
            }

        toc : List (Element MarkupMsg)
        toc =
            -- this value is used in DemoTOC for the document TOC
            -- it is NOT used for the documentTOC in Lamdera
            --Render.TOCTree.view viewParameters accumulator forest_
            Render.TOCTree.view params.theme viewParameters accumulator_ forest_

        banner : Maybe (Element MarkupMsg)
        banner =
            AST.ASTTools.banner forest_
                |> Maybe.map (Render.Block.renderBody params.editCount accumulator_ renderSettings [ Font.color (Element.rgb 1 0 0) ])
                |> Maybe.map (Element.row [ Element.height (Element.px 40) ])

        title : Element MarkupMsg
        title =
            Element.paragraph [ Font.size renderSettings.titleSize ] [ Element.text <| AST.ASTTools.title forest_ ]
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
    -> Render.Settings.RenderSettings
    -> AST.Acc.Accumulator
    -> List (RoseTree.Tree.Tree ExpressionBlock)
    -> List (Element MarkupMsg)
renderForest params settings accumulator forest =
    List.map (Render.Tree.renderTree params settings accumulator) forest


{-| Search blocks in the document for text containing the search query.
Returns a list of matching blocks with their metadata.
-}
searchBlocksContainingText : CompilerParameters -> List String -> String -> List BlockMatch
searchBlocksContainingText params lines searchQuery =
    let
        forest =
            filterForest params.filter (parse Config.idPrefix params.editCount lines)

        allBlocks =
            forestToBlockList forest

        searchLower =
            String.toLower searchQuery
    in
    allBlocks
        |> List.filter (\block -> String.contains searchLower (String.toLower block.meta.sourceText))
        |> List.map
            (\block ->
                { id = "e-" ++ String.fromInt block.meta.lineNumber ++ ".0"
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

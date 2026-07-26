module Parser.Block.Pipeline exposing (toExpressionBlock)

import AST.Language exposing (Expr(..), Expression, ExpressionBlock, Heading(..), PrimitiveBlock)
import Dict
import Either exposing (Either(..))
import Parser.Block.GFMTable
import Tools.Utility


toExpressionBlock : (Int -> String -> List Expression) -> PrimitiveBlock -> ExpressionBlock
toExpressionBlock exprParser block =
    toExpressionBlock_ (exprParser block.meta.lineNumber) block
        |> AST.Language.boostBlock



---XXX---


toExpressionBlock_ : (String -> List Expression) -> PrimitiveBlock -> ExpressionBlock
toExpressionBlock_ parse primitiveBlock =
    if Parser.Block.GFMTable.isTable primitiveBlock then
        Parser.Block.GFMTable.toExpressionBlock parse primitiveBlock

    else
        { heading = primitiveBlock.heading
        , indent = primitiveBlock.indent
        , args = primitiveBlock.args
        , properties =
            primitiveBlock.properties |> Dict.insert "id" primitiveBlock.meta.id
        , firstLine = primitiveBlock.firstLine
        , body =
            case primitiveBlock.heading of
                Paragraph ->
                    Right (String.join "\n" primitiveBlock.body |> parse)

                Ordinary "itemList_" ->
                    let
                        items : List String
                        items =
                            (primitiveBlock.firstLine :: primitiveBlock.body)
                                |> fixItems

                        content_ : List (List Expression)
                        content_ =
                            List.map parse items
                    in
                    Right (List.map (\list -> ExprList 0 list AST.Language.emptyExprMeta) content_)

                -- Nested itemized lists: parse indentation to support proper nesting.
                -- Each item is parsed from its own (marker-stripped) substring, so its
                -- expression offsets start at 0; we shift each item's expressions by the
                -- offset of its content within the block's sourceText so that the
                -- block-level boostBlock pass then lands them at absolute source
                -- positions (needed for rendered→editor sync).
                Ordinary "itemList" ->
                    Right (parseListItems "- " parse primitiveBlock.meta.sourceText)

                -- Nested numbered lists: parse indentation to support proper nesting.
                -- Each item is parsed from its own (marker-stripped) substring, so its
                -- expression offsets start at 0; shift each item's expressions by the
                -- offset of its content within the block's sourceText, mirroring
                -- parseListItems above (needed for rendered→editor sync).
                Ordinary "numberedList" ->
                    Right (parseNumberedListItems parse primitiveBlock.meta.sourceText)

                Ordinary _ ->
                    let
                        -- Set by PrimitiveBlock.fixMarkdownTitleBlock when it strips
                        -- a leading marker ("# ", "!! "). Runs parsed from the
                        -- stripped text start at 0 relative to it, and boostBlock
                        -- only adds the block's own position, so the stripped
                        -- marker's length has to be added back here.
                        markerOffset =
                            Dict.get "markerOffset" primitiveBlock.properties
                                |> Maybe.andThen String.toInt
                                |> Maybe.withDefault 0
                    in
                    Right
                        (String.join "\n" primitiveBlock.body
                            |> parse
                            |> List.map (AST.Language.shiftExpressionPositions markerOffset)
                        )

                Verbatim _ ->
                    Left <| String.join "\n" primitiveBlock.body
        , meta = primitiveBlock.meta
        }


{-| Parse the items of a list block. Each item is parsed from its own
marker-stripped substring (so its expression offsets start at 0); we then shift
each item's expressions by the character offset of that item's content within
`sourceText`. The block-level `boostBlock` pass later adds the block's own
`position`, so the result is absolute source positions (needed for RL sync).
`marker` is the list marker including its trailing space, e.g. `"- "`.
-}
parseListItems : String -> (String -> List Expression) -> String -> List Expression
parseListItems marker parse sourceText =
    let
        folder : String -> ( Int, List Expression ) -> ( Int, List Expression )
        folder line ( offset, acc ) =
            let
                trimmed =
                    String.trimLeft line

                indent =
                    String.length line - String.length trimmed

                ( markerLen, content ) =
                    if String.startsWith marker trimmed then
                        ( String.length marker, String.dropLeft (String.length marker) trimmed )

                    else
                        ( 0, trimmed )

                delta =
                    offset + indent + markerLen

                exprs =
                    parse content |> List.map (AST.Language.shiftExpressionPositions delta)

                nextOffset =
                    offset + String.length line + 1
            in
            ( nextOffset, ExprList indent exprs AST.Language.emptyExprMeta :: acc )
    in
    String.split "\n" sourceText
        |> List.foldl folder ( 0, [] )
        |> Tuple.second
        |> List.reverse
        |> Debug.log "ITEMS"


{-| Numbered-list counterpart of `parseListItems`. The marker is variable
length ("`. `", "`1. `", "`12. `", ...) so, unlike the fixed `"- "` marker,
its length is measured per line rather than passed in.
-}
parseNumberedListItems : (String -> List Expression) -> String -> List Expression
parseNumberedListItems parse sourceText =
    let
        folder : String -> ( Int, List Expression ) -> ( Int, List Expression )
        folder line ( offset, acc ) =
            let
                trimmed =
                    String.trimLeft line

                indent =
                    String.length line - String.length trimmed

                content =
                    Tools.Utility.replaceLeadingNumberedMarker trimmed

                markerLen =
                    String.length trimmed - String.length content

                delta =
                    offset + indent + markerLen

                exprs =
                    parse content |> List.map (AST.Language.shiftExpressionPositions delta)

                nextOffset =
                    offset + String.length line + 1
            in
            ( nextOffset, ExprList indent exprs AST.Language.emptyExprMeta :: acc )
    in
    String.split "\n" sourceText
        |> List.foldl folder ( 0, [] )
        |> Tuple.second
        |> List.reverse


fixItems : List String -> List String
fixItems list =
    fixItemsAux [] list |> List.reverse


fixItemsAux : List String -> List String -> List String
fixItemsAux acc input =
    let
        folder : String -> List String -> List String
        folder str list =
            if (str |> String.trimLeft |> String.left 1) == "-" then
                (str |> String.trimLeft |> String.dropLeft 2) :: list

            else
                case list of
                    [] ->
                        []

                    first :: rest ->
                        (first ++ " " ++ str) :: rest
    in
    List.foldl folder acc input

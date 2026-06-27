module Generic.Pipeline exposing (toExpressionBlock)

import Dict
import Either exposing (Either(..))
import Generic.GFMTable
import Generic.Language exposing (Expr(..), Expression, ExpressionBlock, Heading(..), PrimitiveBlock)


toExpressionBlock : (Int -> String -> List Expression) -> PrimitiveBlock -> ExpressionBlock
toExpressionBlock exprParser block =
    toExpressionBlock_ (exprParser block.meta.lineNumber) block
        |> Generic.Language.boostBlock



---XXX---


toExpressionBlock_ : (String -> List Expression) -> PrimitiveBlock -> ExpressionBlock
toExpressionBlock_ parse primitiveBlock =
    if Generic.GFMTable.isTable primitiveBlock then
        Generic.GFMTable.toExpressionBlock parse primitiveBlock

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
                    Right (List.map (\list -> ExprList 0 list Generic.Language.emptyExprMeta) content_)

                -- Nested itemized lists: parse indentation to support proper nesting.
                -- Each item is parsed from its own (marker-stripped) substring, so its
                -- expression offsets start at 0; we shift each item's expressions by the
                -- offset of its content within the block's sourceText so that the
                -- block-level boostBlock pass then lands them at absolute source
                -- positions (needed for rendered→editor sync).
                Ordinary "itemList" ->
                    Right (parseListItems "- " parse primitiveBlock.meta.sourceText)

                -- Nested numbered lists: parse indentation to support proper nesting
                Ordinary "numberedList" ->
                    let
                        extractIndentAndContent : String -> ( Int, String )
                        extractIndentAndContent str =
                            ( numberOfLeadingSpaces str, String.trimLeft str |> String.replace ". " "" )

                        numberOfLeadingSpaces : String -> Int
                        numberOfLeadingSpaces str =
                            String.length str - String.length (String.trimLeft str)

                        items : List ( Int, String )
                        items =
                            String.split "\n" primitiveBlock.meta.sourceText
                                |> List.map extractIndentAndContent

                        content_ : List ( Int, List Expression )
                        content_ =
                            List.map (\( indent, str ) -> ( indent, parse str )) items
                    in
                    -- Store indentation in ExprList's Int parameter for rendering
                    Right (List.map (\( indent, exprList ) -> ExprList indent exprList Generic.Language.emptyExprMeta) content_)

                Ordinary _ ->
                    Right (String.join "\n" primitiveBlock.body |> parse)

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
                    parse content |> List.map (Generic.Language.shiftExpressionPositions delta)

                nextOffset =
                    offset + String.length line + 1
            in
            ( nextOffset, ExprList indent exprs Generic.Language.emptyExprMeta :: acc )
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

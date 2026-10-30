module AST.TitleBlock exposing (TitleBlock, firstIdKey, fromBlock, fromForest, initial, isTitleBlock)

{-| The title block at the top of a document:

    %title Consistency and Models
    %author ChatGPT
    %date October 1, 2026

`%author` may repeat, one author per line. Any other `%` line in the block
is a comment. A title block counts only when it is the document's first
block (blank lines before it are fine); one anywhere else produces no output.

-}

import AST.Forest exposing (Forest)
import AST.Language exposing (ExpressionBlock, Heading(..))
import RoseTree.Tree


type alias TitleBlock =
    { title : String
    , authors : List String
    , date : String
    }


isTitleBlock : ExpressionBlock -> Bool
isTitleBlock block =
    block.heading == Ordinary "titleBlock"


{-| The document's first block, if it is a title block.
-}
initial : Forest ExpressionBlock -> Maybe ExpressionBlock
initial forest =
    forest
        |> List.head
        |> Maybe.map RoseTree.Tree.value
        |> Maybe.andThen
            (\block ->
                if isTitleBlock block then
                    Just block

                else
                    Nothing
            )


{-| The fields of the document's title block, if it starts with one.
-}
fromForest : Forest ExpressionBlock -> Maybe TitleBlock
fromForest =
    initial >> Maybe.map fromBlock


{-| Read from the block's source lines: the parsed body is not used, since
these lines are not inline markup.
-}
fromBlock : ExpressionBlock -> TitleBlock
fromBlock block =
    block.meta.sourceText
        |> String.lines
        |> List.foldl addLine { title = "", authors = [], date = "" }


addLine : String -> TitleBlock -> TitleBlock
addLine line titleBlock =
    case keyAndValue line of
        Just ( "title", value ) ->
            { titleBlock | title = value }

        Just ( "author", value ) ->
            { titleBlock | authors = titleBlock.authors ++ [ value ] }

        Just ( "date", value ) ->
            { titleBlock | date = value }

        _ ->
            titleBlock


{-| "%title  Some Title " -> Just ("title", "Some Title"). A space right after
the % ("% title ...") makes the line a comment, not a key.
-}
keyAndValue : String -> Maybe ( String, String )
keyAndValue line =
    let
        trimmed =
            String.trim line

        rest =
            String.dropLeft 1 trimmed
    in
    if String.startsWith "%" trimmed && not (String.startsWith " " rest) then
        case String.words rest of
            key :: _ ->
                Just ( key, String.trim (String.dropLeft (String.length key) rest) )

            [] ->
                Nothing

    else
        Nothing


{-| Key in the accumulator's keyValueDict holding the id of the document's
first title block; the renderer draws only that one.
-}
firstIdKey : String
firstIdKey =
    "titleBlockId"

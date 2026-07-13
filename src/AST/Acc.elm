module AST.Acc exposing
    ( Accumulator
    , transformAccumulate
    )

{-|

    The function the AST.Acc module is to collect information from the AST that will
    be used when it is rendered. This information is built up in an Accumulator, a
    data structure used for

            - numbering sections, theorems, figures, etc.
            - creating a dictionary of key-value pairs


     The main function is transformAccumulate, which has the signature

           Forest ExpressionBlock -> ( Accumulator, Forest ExpressionBlock )

     Two helper functions are of special interest,

          updateAccumulator : ExpressionBlock -> Accumulator -> Accumulator

     and

          transformBlock : Accumulator -> ExpressionBlock -> ExpressionBlock

      The first function is used to update the accumulator with information from the AST. The second
      updates expression blocks with information already gathered in the accumulator.

-}

import AST.BlockUtilities
import AST.Language exposing (Expr(..), ExpressionBlock, Heading(..))
import AST.Settings
import AST.Vector as Vector exposing (Vector)
import Dict exposing (Dict)
import Either exposing (Either(..))
import RoseTree.Tree as Tree exposing (Tree)
import Tools.String
import XMarkdown.Config as Config


type alias Accumulator =
    { headingIndex : Vector
    , counter : Dict String Int
    , blockCounter : Int
    , itemVector : Vector -- Used for section numbering
    , deltaLevel : Int
    , numberedItemDict : Dict String { level : Int, index : Int }
    , numberedBlockNames : List String
    , inListState : InListState
    , keyValueDict : Dict String String
    }


type InListState
    = SInList
    | SNotInList


init : Accumulator
init =
    { headingIndex = Vector.init 4
    , deltaLevel = 0
    , inListState = SNotInList
    , counter = Dict.empty
    , blockCounter = 0
    , itemVector = Vector.init 4
    , numberedItemDict = Dict.empty
    , numberedBlockNames = AST.Settings.numberedBlockNames
    , keyValueDict = Dict.empty
    }


transformAccumulate : List (Tree ExpressionBlock) -> ( Accumulator, List (Tree ExpressionBlock) )
transformAccumulate forest =
    List.foldl (\tree ( acc_, ast_ ) -> transformAccumulateTree tree acc_ |> mapper ast_) ( init, [] ) forest
        |> (\( acc_, ast_ ) -> ( acc_, List.reverse ast_ ))


getCounter : String -> Dict String Int -> Int
getCounter name dict =
    Dict.get name dict |> Maybe.withDefault 0


getCounterAsString : String -> Dict String Int -> String
getCounterAsString name dict =
    Dict.get name dict |> Maybe.map String.fromInt |> Maybe.withDefault ""


incrementCounter : String -> Dict String Int -> Dict String Int
incrementCounter name dict =
    Dict.insert name (getCounter name dict + 1) dict


mapper ast_ ( acc_, tree_ ) =
    ( acc_, tree_ :: ast_ )


transformAccumulateTree : Tree ExpressionBlock -> Accumulator -> ( Accumulator, Tree ExpressionBlock )
transformAccumulateTree tree acc =
    mapAccumulate transformAccumulateBlock acc tree


mapAccumulate : (s -> a -> ( s, b )) -> s -> Tree a -> ( s, Tree b )
mapAccumulate f s tree =
    let
        ( s_, value_ ) =
            f s (Tree.value tree)

        ( s__, children_ ) =
            List.foldl
                (\child ( accState, accChildren ) ->
                    let
                        ( newState, newChild ) =
                            mapAccumulate f accState child
                    in
                    ( newState, newChild :: accChildren )
                )
                ( s_, [] )
                (Tree.children tree)
    in
    ( s__, Tree.branch value_ (reverse children_) )


reverse : List a -> List a
reverse list =
    List.foldl (\x xs -> x :: xs) [] list


{-|

    This function first updates the Accumulator with information from the ExpressionBlock
    (for example, the headingIndex, used to number sections), and then transforms the
    ExpressionBlock with information from the Accumulator (for example, the label property).

    The transformAccumulate block takes an Accumulator and an ExpressionBlock as
    arguments and returns a pair (Accumulator, ExpressionBlock) of the updated data.

-}
transformAccumulateBlock : Accumulator -> ExpressionBlock -> ( Accumulator, ExpressionBlock )
transformAccumulateBlock =
    \acc_ block_ ->
        let
            newAcc =
                updateAccumulator block_ acc_
        in
        ( newAcc, transformBlock newAcc block_ )


{-|

    Add labels to blocks, e.g. number sections and equations

-}
transformBlock : Accumulator -> ExpressionBlock -> ExpressionBlock
transformBlock acc block =
    case ( block.heading, block.args ) of
        ( Ordinary "section", _ ) ->
            { block
                | properties =
                    block.properties
                        |> Dict.insert "label" (Vector.toString acc.headingIndex)
                        |> Dict.insert "tag" (block.firstLine |> Tools.String.makeSlug)
            }

        ( Ordinary "image", _ ) ->
            { block | properties = Dict.insert "figure" (getCounterAsString "figure" acc.counter) block.properties }

        ( Verbatim "equation", _ ) ->
            { block | properties = Dict.insert "equation-number" (equationNumber acc) block.properties }

        ( Verbatim "aligned", _ ) ->
            { block | properties = Dict.insert "equation-number" (equationNumber acc) block.properties }

        ( heading, _ ) ->
            -- TODO: not at all sure that the below is correct
            case AST.Language.getNameFromHeading heading of
                Nothing ->
                    block

                Just name ->
                    -- Insert the numerical counter, e.g,, equation number, in the arg list of the block
                    if List.member name [ "section" ] then
                        { block
                            | properties = Dict.insert "label" (equationNumber acc) block.properties
                        }

                    else
                        -- Default insertion of "label" property (used for block numbering)
                        if List.member name AST.Settings.numberedBlockNames then
                            { block
                                | properties =
                                    Dict.insert "label"
                                        (vectorPrefix acc.headingIndex ++ String.fromInt acc.blockCounter)
                                        block.properties
                            }

                        else
                            block


{-| The current equation number, prefixed by the section number if there is one,
e.g., "3" or "2.3".
-}
equationNumber : Accumulator -> String
equationNumber acc =
    if Vector.toString acc.headingIndex == "" then
        getCounterAsString "equation" acc.counter

    else
        Vector.toString acc.headingIndex ++ "." ++ getCounterAsString "equation" acc.counter


vectorPrefix : Vector -> String
vectorPrefix headingIndex =
    let
        prefix =
            Vector.toString headingIndex
    in
    if prefix == "" then
        ""

    else
        Vector.toString headingIndex ++ "."


{-| Map name to name of counter
-}
reduceName : String -> String
reduceName str =
    if List.member str [ "equation", "aligned" ] then
        "equation"

    else if str == "code" then
        "listing"

    else if List.member str [ "quiver", "image", "table", "svg", "tikz" ] then
        "figure"

    else
        str


{-| The first component of the return value (Bool, Maybe Vector) is the
updated inList.
-}
nextInListState : Heading -> InListState -> InListState
nextInListState heading state =
    case ( state, heading ) of
        ( SNotInList, Ordinary "numbered" ) ->
            SInList

        ( SNotInList, _ ) ->
            SNotInList

        ( SInList, Ordinary "numbered" ) ->
            SInList

        ( SInList, _ ) ->
            SNotInList


{-|

    Update the accumulator with data from a block, e.g., update the
    headingIndex, a vector of integers that is used to number the sections

-}
updateAccumulator : ExpressionBlock -> Accumulator -> Accumulator
updateAccumulator ({ heading, args, properties } as block) accumulator =
    -- Update the accumulator for expression blocks with selected name
    case heading of
        -- provide numbering for sections
        -- reference : Dict String { id : String, numRef : String }
        Verbatim "settings" ->
            { accumulator | keyValueDict = Dict.union properties accumulator.keyValueDict }

        Ordinary "set-key" ->
            case args of
                key :: value :: _ ->
                    { accumulator | keyValueDict = Dict.insert key value accumulator.keyValueDict }

                _ ->
                    accumulator

        Ordinary "list" ->
            { accumulator | itemVector = Vector.init 4 }

        Ordinary "section" ->
            let
                level : String
                level =
                    Dict.get "level" properties |> Maybe.withDefault "1"
            in
            updateWithOrdinarySectionBlock accumulator level

        Ordinary "title" ->
            -- Only reset headingIndex if it wasn't set by shiftAndSetCounter (deltaLevel == 1)
            if accumulator.deltaLevel == 1 then
                -- Preserve the headingIndex set by shiftAndSetCounter
                accumulator

            else
                let
                    headingIndex =
                        case Dict.get "first-section" block.properties of
                            Nothing ->
                                { content = [ 0, 0, 0, 0 ], size = 4 }

                            Just firstSection_ ->
                                case String.toInt firstSection_ of
                                    Just n ->
                                        { content = [ max (n - 1) 0, 0, 0, 0 ], size = 4 }

                                    Nothing ->
                                        { content = [ 0, 0, 0, 0 ], size = 4 }
                in
                { accumulator | headingIndex = headingIndex }

        Ordinary "setcounter" ->
            let
                n =
                    List.head args |> Maybe.andThen String.toInt |> Maybe.withDefault 1
            in
            { accumulator | headingIndex = { content = [ n, 0, 0, 0 ], size = 4 } }

        Ordinary "shiftandsetcounter" ->
            let
                n =
                    List.head args |> Maybe.andThen String.toInt |> Maybe.withDefault 1
            in
            { accumulator | headingIndex = { content = [ n, 0, 0, 0 ], size = 4 }, deltaLevel = 1 }

        Ordinary _ ->
            updateWithOrdinaryBlock block accumulator

        Verbatim _ ->
            case block.body of
                Left _ ->
                    updateWithVerbatimBlock block accumulator

                Right _ ->
                    accumulator

        Paragraph ->
            { accumulator | inListState = nextInListState block.heading accumulator.inListState }


updateWithOrdinarySectionBlock : Accumulator -> String -> Accumulator
updateWithOrdinarySectionBlock accumulator level =
    let
        delta =
            case Dict.get "has-chapters" accumulator.keyValueDict of
                Nothing ->
                    0

                Just "yes" ->
                    1

                _ ->
                    0

        headingIndex =
            Vector.increment (String.toInt level |> Maybe.withDefault 1 |> (\x -> x - 1 + delta + accumulator.deltaLevel)) accumulator.headingIndex
    in
    -- TODO: take care of numberedItemIndex = 0 here and elsewhere
    { accumulator
        | headingIndex = headingIndex
        , blockCounter = 0
        , counter = Dict.insert "equation" 0 accumulator.counter --TODO: this is strange!!
    }


updateWithOrdinaryBlock : ExpressionBlock -> Accumulator -> Accumulator
updateWithOrdinaryBlock block accumulator =
    case AST.BlockUtilities.getExpressionBlockName block of
        Just "setcounter" ->
            case block.body of
                Left _ ->
                    accumulator

                Right exprs ->
                    let
                        ctr =
                            case exprs of
                                [ Text val _ ] ->
                                    String.toInt val |> Maybe.withDefault 1

                                _ ->
                                    1

                        headingIndex =
                            Vector.init accumulator.headingIndex.size |> Vector.set 0 (ctr - 1)
                    in
                    { accumulator | headingIndex = headingIndex }

        Just "numbered" ->
            let
                level =
                    block.indent // Config.indentationQuantum

                itemVector =
                    case accumulator.inListState of
                        SInList ->
                            Vector.increment level accumulator.itemVector

                        SNotInList ->
                            Vector.init 4 |> Vector.increment 0

                index =
                    Vector.get level itemVector

                numberedItemDict =
                    Dict.insert block.meta.id { level = level, index = index } accumulator.numberedItemDict
            in
            { accumulator
                | inListState = nextInListState block.heading accumulator.inListState
                , itemVector = itemVector
                , numberedItemDict = numberedItemDict
            }

        Just "item" ->
            { accumulator | inListState = nextInListState block.heading accumulator.inListState }

        Just name_ ->
            if List.member name_ [ "title", "contents", "banner", "a" ] then
                accumulator

            else if List.member name_ AST.Settings.numberedBlockNames then
                --- TODO: fix thereom labels
                let
                    level =
                        block.indent // Config.indentationQuantum

                    itemVector =
                        Vector.increment level accumulator.itemVector

                    numberedItemDict =
                        Dict.insert block.meta.id { level = level, index = Vector.get level itemVector } accumulator.numberedItemDict
                in
                { accumulator
                    | inListState = nextInListState block.heading accumulator.inListState
                    , blockCounter = accumulator.blockCounter + 1
                    , itemVector = itemVector
                    , numberedItemDict = numberedItemDict
                }

            else
                { accumulator | inListState = nextInListState block.heading accumulator.inListState }

        _ ->
            accumulator


{-| Update the accumulator with data from a verbatim block: track list state and
increment the appropriate counter, e.g., "equation" and "aligned"
(reduceName maps these both to "equation").
-}
updateWithVerbatimBlock : ExpressionBlock -> Accumulator -> Accumulator
updateWithVerbatimBlock block accumulator =
    case block.body of
        Right _ ->
            accumulator

        Left _ ->
            let
                name =
                    AST.BlockUtilities.getExpressionBlockName block |> Maybe.withDefault ""

                newCounter =
                    if List.member name accumulator.numberedBlockNames && List.member "numbered" block.args then
                        incrementCounter (reduceName name) accumulator.counter

                    else
                        accumulator.counter
            in
            { accumulator | inListState = nextInListState block.heading accumulator.inListState, counter = newCounter }

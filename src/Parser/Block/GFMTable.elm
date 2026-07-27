module Parser.Block.GFMTable exposing
    ( Alignment(..)
    , encodeAlignments
    , isSeparatorRow
    , isTable
    , padRow
    , parseAlignments
    , splitRow
    , toExpressionBlock
    )

{-| GitHub-flavored markdown tables. A table is one primitive block whose first
line is a pipe-row and whose second line is a separator. The rows in order are
`firstLine :: List.reverse body` (meta.sourceText omits the header line). This
module detects such a block and builds the `Fun "table"/"row"/"cell"` AST, with
each cell's text parsed by the supplied inline parser.
-}

import Dict
import Either exposing (Either(..))
import AST.Language exposing (Expr(..), Expression, ExpressionBlock, Heading(..), PrimitiveBlock, emptyExprMeta)


type Alignment
    = AlignLeft
    | AlignCenter
    | AlignRight


{-| Split a pipe-row into trimmed cell texts, dropping the outer pipes. -}
splitRow : String -> List String
splitRow str =
    let
        t =
            String.trim str

        a =
            if String.startsWith "|" t then
                String.dropLeft 1 t

            else
                t

        b =
            if String.endsWith "|" a then
                String.dropRight 1 a

            else
                a
    in
    String.split "|" b |> List.map String.trim


{-| Split a pipe-row into `(offset, cellText)` pairs, where `offset` is where the
trimmed cell text begins in the ORIGINAL row string. Cell text is parsed from its
own substring, so its expression offsets start at 0; shifting them by this offset
(plus the row's offset within the block) lands them at true source positions,
which is what rendered→editor sync needs.

The cell texts are identical to `splitRow`'s — this only adds their positions.

-}
splitRowWithOffsets : String -> List ( Int, String )
splitRowWithOffsets str =
    let
        leadingWs =
            String.length str - String.length (String.trimLeft str)

        t =
            String.trim str

        -- Drop the outer pipes exactly as splitRow does, tracking how many
        -- characters that removes from the front.
        ( afterLeading, frontOffset ) =
            if String.startsWith "|" t then
                ( String.dropLeft 1 t, leadingWs + 1 )

            else
                ( t, leadingWs )

        b =
            if String.endsWith "|" afterLeading then
                String.dropRight 1 afterLeading

            else
                afterLeading

        step : String -> ( Int, List ( Int, String ) ) -> ( Int, List ( Int, String ) )
        step segment ( cursor, acc ) =
            let
                -- Trimming shifts the cell's start right by its leading spaces.
                innerOffset =
                    String.length segment - String.length (String.trimLeft segment)
            in
            ( cursor + String.length segment + 1
            , ( frontOffset + cursor + innerOffset, String.trim segment ) :: acc
            )
    in
    String.split "|" b
        |> List.foldl step ( 0, [] )
        |> Tuple.second
        |> List.reverse


{-| A separator row: every cell is non-empty and made only of '-' and ':' with at
least one '-'.
-}
isSeparatorRow : String -> Bool
isSeparatorRow str =
    let
        cells =
            splitRow str
    in
    not (List.isEmpty cells) && List.all isSeparatorCell cells


isSeparatorCell : String -> Bool
isSeparatorCell c =
    let
        t =
            String.trim c
    in
    not (String.isEmpty t)
        && String.contains "-" t
        && String.all (\ch -> ch == '-' || ch == ':') t


parseAlignments : String -> List Alignment
parseAlignments separatorLine =
    splitRow separatorLine |> List.map alignmentOfCell


alignmentOfCell : String -> Alignment
alignmentOfCell c =
    let
        t =
            String.trim c

        left =
            String.startsWith ":" t

        right =
            String.endsWith ":" t
    in
    if left && right then
        AlignCenter

    else if right then
        AlignRight

    else
        AlignLeft


encodeAlignments : List Alignment -> String
encodeAlignments aligns =
    aligns |> List.map alignmentCode |> String.join ","


alignmentCode : Alignment -> String
alignmentCode a =
    case a of
        AlignLeft ->
            "l"

        AlignCenter ->
            "c"

        AlignRight ->
            "r"


padRow : Int -> List String -> List String
padRow n cells =
    if List.length cells >= n then
        List.take n cells

    else
        cells ++ List.repeat (n - List.length cells) ""


{-| `padRow` for cells that carry their source offset. Padding cells are empty,
so the offset given to them is never used to place any expression; it just keeps
the pair well-formed.
-}
padCells : Int -> Int -> List ( Int, String ) -> List ( Int, String )
padCells n endOffset cells =
    if List.length cells >= n then
        List.take n cells

    else
        cells ++ List.repeat (n - List.length cells) ( endOffset, "" )


{-| All source rows in order: header, separator, data…

The header is always `firstLine`. The body's orientation is not stable: a
normally-terminated (finalized) block stores body in source order (separator
first), while a block terminated by end-of-input is left in reversed
accumulation order (separator last). A valid table always has the separator
immediately after the header, so we pick whichever orientation places a
separator on the second line.
-}
rowsInOrder : PrimitiveBlock -> List String
rowsInOrder pb =
    let
        forward =
            pb.firstLine :: pb.body
    in
    case forward of
        _ :: second :: _ ->
            if isSeparatorRow second then
                forward

            else
                pb.firstLine :: List.reverse pb.body

        _ ->
            forward


{-| A block is a GFM table iff its first line is a pipe-row and its second line is
a separator.
-}
isTable : PrimitiveBlock -> Bool
isTable pb =
    case rowsInOrder pb of
        first :: separator :: _ ->
            String.startsWith "|" (String.trimLeft first) && isSeparatorRow separator

        _ ->
            False


{-| Build the table ExpressionBlock. `parse` is the inline parser (already bound to
the block's line number by the caller). Caller must have checked `isTable`.
-}
toExpressionBlock : (String -> List Expression) -> PrimitiveBlock -> ExpressionBlock
toExpressionBlock parse pb =
    let
        rows =
            rowsInOrder pb

        header =
            List.head rows |> Maybe.withDefault ""

        separator =
            List.drop 1 rows |> List.head |> Maybe.withDefault ""

        dataRows =
            List.drop 2 rows

        ncols =
            splitRow header |> List.length

        -- Where each row starts, relative to the block's own position. Rows are
        -- consumed in source order INCLUDING the separator, which is not
        -- rendered but does occupy source lines, so the data rows below it land
        -- at the right offsets. boostBlock later adds the block's position,
        -- making these absolute.
        rowOffsets : List ( Int, String )
        rowOffsets =
            rows
                |> List.foldl
                    (\row ( cursor, acc ) -> ( cursor + String.length row + 1, ( cursor, row ) :: acc ))
                    ( 0, [] )
                |> Tuple.second
                |> List.reverse

        toRowExpr : ( Int, String ) -> Expression
        toRowExpr ( rowOffset, rowSrc ) =
            let
                -- Pad with cells carrying the row's end offset: they have no
                -- source text, so they contribute no expressions to shift.
                cells =
                    splitRowWithOffsets rowSrc
                        |> List.map (\( o, text ) -> ( rowOffset + o, text ))
                        |> padCells ncols (rowOffset + String.length rowSrc)

                toCellExpr ( cellOffset, cellText ) =
                    Fun "cell"
                        (parse cellText |> List.map (AST.Language.shiftExpressionPositions cellOffset))
                        emptyExprMeta
            in
            Fun "row" (List.map toCellExpr cells) emptyExprMeta

        -- The separator row is dropped from the AST but kept in rowOffsets, so
        -- select the header and the data rows by position rather than by value.
        renderedRows =
            case rowOffsets of
                headerRow :: _ :: rest ->
                    headerRow :: rest

                other ->
                    other

        tableExpr =
            Fun "table" (List.map toRowExpr renderedRows) emptyExprMeta
    in
    { heading = Ordinary "table"
    , indent = pb.indent
    , args = pb.args
    , properties =
        pb.properties
            |> Dict.insert "id" pb.meta.id
            |> Dict.insert "alignments" (encodeAlignments (parseAlignments separator))
    , firstLine = pb.firstLine
    , body = Right [ tableExpr ]
    , meta = pb.meta
    }

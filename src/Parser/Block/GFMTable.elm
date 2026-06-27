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

        toRowExpr : String -> Expression
        toRowExpr rowSrc =
            let
                cells =
                    splitRow rowSrc |> padRow ncols
            in
            Fun "row" (List.map (\cellText -> Fun "cell" (parse cellText) emptyExprMeta) cells) emptyExprMeta

        tableExpr =
            Fun "table" (List.map toRowExpr (header :: dataRows)) emptyExprMeta
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

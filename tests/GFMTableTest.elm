module GFMTableTest exposing (suite)

import Expect
import Generic.GFMTable as G exposing (Alignment(..))
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Generic.GFMTable"
        [ test "splitRow drops outer pipes and trims" <|
            \_ ->
                G.splitRow "| Alice | 29 | Engineer |"
                    |> Expect.equal [ "Alice", "29", "Engineer" ]
        , test "splitRow on a separator" <|
            \_ ->
                G.splitRow "|---|---:|:---:|"
                    |> Expect.equal [ "---", "---:", ":---:" ]
        , test "isSeparatorRow true for a real separator" <|
            \_ ->
                G.isSeparatorRow "|---|----:|:--:|" |> Expect.equal True
        , test "isSeparatorRow false for a data row" <|
            \_ ->
                G.isSeparatorRow "| Alice | 29 |" |> Expect.equal False
        , test "parseAlignments reads the four cases" <|
            \_ ->
                G.parseAlignments "|---|:---|:---:|---:|"
                    |> Expect.equal [ AlignLeft, AlignLeft, AlignCenter, AlignRight ]
        , test "encodeAlignments to l/c/r" <|
            \_ ->
                G.encodeAlignments [ AlignLeft, AlignCenter, AlignRight ]
                    |> Expect.equal "l,c,r"
        , test "padRow pads short rows to width" <|
            \_ ->
                G.padRow 3 [ "a" ] |> Expect.equal [ "a", "", "" ]
        , test "padRow truncates long rows to width" <|
            \_ ->
                G.padRow 2 [ "a", "b", "c" ] |> Expect.equal [ "a", "b" ]
        ]

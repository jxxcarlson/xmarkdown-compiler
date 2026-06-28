module SyncTest exposing (suite)

import Expect
import XMarkdown.Msg exposing (MarkupMsg(..))
import XMarkdown.Sync as Sync
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "XMarkdown.Sync"
        [ test "SendMeta: begin/end are absolute document char offsets (end inclusive -> +1)" <|
            \_ ->
                -- e.g. the line-3 paragraph: doc chars 26..204 inclusive
                Sync.fromMsg 7 (SendMeta { begin = 26, end = 204, index = 0, id = "e-3.0" })
                    |> Expect.equal (Just { mode = "chars", start = 26, end = 205, tick = 7 })
        , test "SendLineNumber: 1-indexed first line; end = firstLine+numberOfLines -> last line = end-1" <|
            \_ ->
                -- a single-line block at source line 7: begin=7, end=8 -> lines 7..7
                Sync.fromMsg 3 (SendLineNumber { begin = 7, end = 8 })
                    |> Expect.equal (Just { mode = "lines", start = 7, end = 7, tick = 3 })
        , test "SendLineNumber: multi-line block (lines 12..14)" <|
            \_ ->
                Sync.fromMsg 1 (SendLineNumber { begin = 12, end = 15 })
                    |> Expect.equal (Just { mode = "lines", start = 12, end = 14, tick = 1 })
        , test "non-RL message -> Nothing" <|
            \_ ->
                Sync.fromMsg 1 (SelectId "x")
                    |> Expect.equal Nothing
        , test "encode produces compact ordered JSON" <|
            \_ ->
                Sync.encode { mode = "chars", start = 26, end = 205, tick = 7 }
                    |> Expect.equal "{\"mode\":\"chars\",\"start\":26,\"end\":205,\"tick\":7}"
        ]

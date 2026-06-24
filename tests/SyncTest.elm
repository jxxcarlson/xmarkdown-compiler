module SyncTest exposing (suite)

import Expect
import ScriptaV2.Msg exposing (MarkupMsg(..))
import ScriptaV2.Sync as Sync
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "ScriptaV2.Sync"
        [ test "SendMeta: 0-indexed id line -> CM line+1, keeps inclusive columns" <|
            \_ ->
                Sync.fromMsg 7 (SendMeta { begin = 6, end = 14, index = 4, id = "e-12.4" })
                    |> Expect.equal (Just { line = 13, colBegin = 6, colEnd = 14, lineCount = 0, tick = 7 })
        , test "SendLineNumber: 0-indexed begin -> CM line+1, lineCount = end-begin" <|
            \_ ->
                Sync.fromMsg 3 (SendLineNumber { begin = 4, end = 6 })
                    |> Expect.equal (Just { line = 5, colBegin = 0, colEnd = 0, lineCount = 2, tick = 3 })
        , test "SendMeta with unparseable id -> Nothing" <|
            \_ ->
                Sync.fromMsg 1 (SendMeta { begin = 0, end = 0, index = 0, id = "bogus" })
                    |> Expect.equal Nothing
        , test "non-RL message -> Nothing" <|
            \_ ->
                Sync.fromMsg 1 (SelectId "x")
                    |> Expect.equal Nothing
        , test "encode produces compact ordered JSON" <|
            \_ ->
                Sync.encode { line = 13, colBegin = 6, colEnd = 14, lineCount = 0, tick = 7 }
                    |> Expect.equal "{\"line\":13,\"colBegin\":6,\"colEnd\":14,\"lineCount\":0,\"tick\":7}"
        ]

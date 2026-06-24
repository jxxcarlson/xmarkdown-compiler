module EditorTest exposing (suite)

import Expect
import Json.Decode as D
import ScriptaV2.Editor
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "ScriptaV2.Editor"
        [ test "textChangeDecoder extracts detail.source" <|
            \_ ->
                """{"detail":{"source":"hello","position":3}}"""
                    |> D.decodeString ScriptaV2.Editor.textChangeDecoder
                    |> Expect.equal (Ok "hello")
        , test "renderedTextId is the agreed container id" <|
            \_ ->
                ScriptaV2.Editor.renderedTextId
                    |> Expect.equal "__RENDERED_TEXT__"
        ]

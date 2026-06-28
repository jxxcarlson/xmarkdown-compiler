module EditorTest exposing (suite)

import Expect
import Json.Decode as D
import XMarkdown.Editor
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "XMarkdown.Editor"
        [ test "textChangeDecoder extracts detail.source" <|
            \_ ->
                """{"detail":{"source":"hello","position":3}}"""
                    |> D.decodeString XMarkdown.Editor.textChangeDecoder
                    |> Expect.equal (Ok "hello")
        , test "renderedTextId is the agreed container id" <|
            \_ ->
                XMarkdown.Editor.renderedTextId
                    |> Expect.equal "__RENDERED_TEXT__"
        ]

module HTMLParseTest exposing (suite)

{-| `XMarkdown.API.parse` gives apps an opaque `AST` for `HTML.Export`.
-}

import Expect
import Test exposing (Test, describe, test)
import XMarkdown.API
import XMarkdown.AST
import XMarkdown.Compiler


suite : Test
suite =
    describe "XMarkdown.API.parse"
        [ test "parse gives one tree per top-level block" <|
            \_ ->
                XMarkdown.API.parse "# A\n\nHello."
                    |> XMarkdown.AST.forest
                    |> List.length
                    |> Expect.equal 2
        , test "parse matches parseFromString" <|
            \_ ->
                let
                    source =
                        "- a\n- b\n\n$$\nx^2\n$$"
                in
                XMarkdown.API.parse source
                    |> XMarkdown.AST.forest
                    |> Expect.equal (XMarkdown.Compiler.parseFromString source)
        ]

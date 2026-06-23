module ToForestAndAccumulatorTest exposing (suite)

import Element
import Expect
import Generic.Acc exposing (Accumulator)
import Generic.Forest exposing (Forest)
import Generic.Language exposing (ExpressionBlock)
import Generic.Vector
import ScriptaV2.APISimple
import ScriptaV2.Compiler
import ScriptaV2.Language exposing (Language(..))
import ScriptaV2.Types exposing (CompilerParameters, Filter(..), defaultCompilerParameters)
import Test exposing (..)


suite : Test
suite =
    describe "XMarkdown"
        [ describe "parseToForestWithAccumulator"
            [ test "simple paragraph returns non-empty forest" <|
                \_ ->
                    let
                        params =
                            defaultParams SMarkdownLang

                        lines =
                            [ "This is a test paragraph." ]

                        ( accumulator, forest ) =
                            ScriptaV2.Compiler.parseToForestWithAccumulator params lines
                    in
                    forest
                        |> List.length
                        |> Expect.greaterThan 0
            , test "markdown heading creates section" <|
                \_ ->
                    let
                        params =
                            defaultParams SMarkdownLang

                        lines =
                            [ "# Introduction", "", "Some text here." ]

                        ( accumulator, forest ) =
                            ScriptaV2.Compiler.parseToForestWithAccumulator params lines
                    in
                    Generic.Vector.level accumulator.headingIndex
                        |> Expect.greaterThan 0
            ]
        , describe "APISimple.compile round-trip"
            [ test "paragraph with bold produces non-empty elm-ui output" <|
                \_ ->
                    let
                        source =
                            "# Introduction\n\nThis is a **bold** word in a paragraph.\n\n- item one\n- item two\n"

                        output =
                            ScriptaV2.APISimple.compile defaultCompilerParameters source
                    in
                    output
                        |> List.length
                        |> Expect.greaterThan 0
            , test "verbatim code block is rendered" <|
                \_ ->
                    let
                        source =
                            "```\nlet x = 1\n```\n"

                        output =
                            ScriptaV2.APISimple.compile defaultCompilerParameters source
                    in
                    output
                        |> List.length
                        |> Expect.greaterThan 0
            , test "math block is rendered" <|
                \_ ->
                    let
                        source =
                            "$$\nE = mc^2\n$$\n"

                        output =
                            ScriptaV2.APISimple.compile defaultCompilerParameters source
                    in
                    output
                        |> List.length
                        |> Expect.greaterThan 0
            ]
        ]


defaultParams : Language -> CompilerParameters
defaultParams lang =
    { defaultCompilerParameters | lang = lang }

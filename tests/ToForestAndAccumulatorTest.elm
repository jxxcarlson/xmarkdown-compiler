module ToForestAndAccumulatorTest exposing (suite)

import AST.Vector
import Expect
import Scripta.API
import Scripta.Compiler
import Scripta.Types exposing (CompilerParameters, defaultCompilerParameters)
import Test exposing (..)


suite : Test
suite =
    describe "XMarkdown"
        [ describe "parseToForestWithAccumulator"
            [ test "simple paragraph returns non-empty forest" <|
                \_ ->
                    let
                        params =
                            defaultParams

                        lines =
                            [ "This is a test paragraph." ]

                        ( _, forest ) =
                            Scripta.Compiler.parseToForestWithAccumulator params lines
                    in
                    forest
                        |> List.length
                        |> Expect.greaterThan 0
            , test "markdown heading creates section" <|
                \_ ->
                    let
                        params =
                            defaultParams

                        lines =
                            [ "# Introduction", "", "Some text here." ]

                        ( accumulator, _ ) =
                            Scripta.Compiler.parseToForestWithAccumulator params lines
                    in
                    AST.Vector.level accumulator.headingIndex
                        |> Expect.greaterThan 0
            ]
        , describe "API.compileSimple round-trip"
            [ test "paragraph with bold produces non-empty elm-ui output" <|
                \_ ->
                    let
                        source =
                            "# Introduction\n\nThis is a **bold** word in a paragraph.\n\n- item one\n- item two\n"

                        output =
                            Scripta.API.compileSimple defaultCompilerParameters source
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
                            Scripta.API.compileSimple defaultCompilerParameters source
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
                            Scripta.API.compileSimple defaultCompilerParameters source
                    in
                    output
                        |> List.length
                        |> Expect.greaterThan 0
            ]
        ]


defaultParams : CompilerParameters
defaultParams =
    defaultCompilerParameters

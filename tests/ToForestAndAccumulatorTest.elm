module ToForestAndAccumulatorTest exposing (suite)

import Dict
import Expect
import Generic.Acc exposing (Accumulator)
import Generic.Forest exposing (Forest)
import Generic.Language exposing (ExpressionBlock)
import Generic.Vector
import Render.Theme
import ScriptaV2.Compiler
import ScriptaV2.Language exposing (Language(..))
import ScriptaV2.Types exposing (CompilerParameters, Filter(..), defaultCompilerParameters)
import Test exposing (..)


suite : Test
suite =
    describe "parseToForestWithAccumulator"
        [ describe "SMarkdown parsing"
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
        , describe "Scripta parsing"
            [ test "simple paragraph returns non-empty forest" <|
                \_ ->
                    let
                        params =
                            defaultParams ScriptaLang

                        lines =
                            [ "This is a test paragraph." ]

                        ( accumulator, forest ) =
                            ScriptaV2.Compiler.parseToForestWithAccumulator params lines
                    in
                    forest
                        |> List.length
                        |> Expect.greaterThan 0
            , test "section block creates accumulator with section count" <|
                \_ ->
                    let
                        params =
                            defaultParams ScriptaLang

                        lines =
                            [ "| section", "Introduction", "", "Some text here." ]

                        ( accumulator, forest ) =
                            ScriptaV2.Compiler.parseToForestWithAccumulator params lines
                    in
                    Generic.Vector.level accumulator.headingIndex
                        |> Expect.greaterThan 0
            ]
        ]


defaultParams : Language -> CompilerParameters
defaultParams lang =
    { defaultCompilerParameters | lang = lang }

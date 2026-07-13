module PXB exposing (program)

{-| Print the primitive blocks of an XMarkdown file.

    Usage: elm-cli run src/PXB.elm FILE

-}

import AST.Language exposing (Heading(..), PrimitiveBlock)
import Dict
import Parser.Block.PrimitiveBlock exposing (parse)
import Posix.IO as IO exposing (IO, Process)
import Posix.IO.File as File
import Posix.IO.Process as Proc


program : Process -> IO ()
program process =
    case process.argv of
        [ _, filename ] ->
            IO.do
                (File.contentsOf filename
                    |> IO.exitOnError identity
                )
            <|
                \content ->
                    let
                        parsed =
                            content |> String.lines |> parse "id" 0

                        blockString =
                            "\n----------------\nBLOCKS\n----------------\n\n"
                                ++ (List.map print parsed |> String.join "\n\n")
                    in
                    IO.do (Proc.print blockString) <|
                        \_ ->
                            IO.return ()

        _ ->
            Proc.logErr "Usage: elm-cli run src/PXB.elm FILE\n"


print : PrimitiveBlock -> String
print block =
    [ headingToString block.heading
        ++ " (line "
        ++ String.fromInt block.meta.lineNumber
        ++ ", indent "
        ++ String.fromInt block.indent
        ++ ")"
    , "  firstLine: " ++ block.firstLine
    , argsToString block.args
    , propertiesToString block.properties
    , block.body |> List.map (\line -> "  | " ++ line) |> String.join "\n"
    ]
        |> List.filter (\s -> s /= "")
        |> String.join "\n"


headingToString : Heading -> String
headingToString heading =
    case heading of
        Paragraph ->
            "PARAGRAPH"

        Ordinary name ->
            "ORDINARY " ++ name

        Verbatim name ->
            "VERBATIM " ++ name


argsToString : List String -> String
argsToString args =
    if List.isEmpty args then
        ""

    else
        "  args: " ++ String.join ", " args


propertiesToString : Dict.Dict String String -> String
propertiesToString properties =
    if Dict.isEmpty properties then
        ""

    else
        "  properties: "
            ++ (properties
                    |> Dict.toList
                    |> List.map (\( k, v ) -> k ++ ": " ++ v)
                    |> String.join ", "
               )

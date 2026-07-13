module BlockMathBracketTest exposing (suite)

{-| Block-level LaTeX-style display math:

    \[
    x^2 + y^2 = z^2
    \]

must parse to exactly the same block as

    $$
    x^2 + y^2 = z^2
    $$

The `\[` / `\]` delimiters are normalized to `$$` at parse time
(Parser.Block.PrimitiveBlock.normalizeMathDelimiters), while meta.sourceText
keeps the text the author actually typed, for editor sync.

-}

import AST.Language exposing (Heading(..))
import Dict exposing (Dict)
import Either exposing (Either)
import Expect
import RoseTree.Tree as Tree
import Test exposing (Test, describe, test)
import XMarkdown.Compiler


{-| Everything about a block except its meta (ids, sourceText, positions).
-}
type alias Essence =
    { heading : Heading
    , indent : Int
    , args : List String
    , properties : Dict String String
    , firstLine : String
    , body : Either String (List AST.Language.Expression)
    }


essence : String -> List Essence
essence src =
    XMarkdown.Compiler.parseFromString src
        |> List.map Tree.value
        |> List.map
            (\b ->
                { heading = b.heading
                , indent = b.indent
                , args = b.args
                , properties = b.properties
                , firstLine = b.firstLine
                , body = b.body
                }
            )


dollarSrc : String
dollarSrc =
    "$$\nx^2 + y^2 = z^2\n$$\n"


bracketSrc : String
bracketSrc =
    "\\[\nx^2 + y^2 = z^2\n\\]\n"


suite : Test
suite =
    describe "Block-level \\[...\\] display math"
        [ test "\\[...\\] parses to the same block as $$...$$" <|
            \_ ->
                essence bracketSrc
                    |> Expect.equal (essence dollarSrc)
        , test "the block is Verbatim math" <|
            \_ ->
                essence bracketSrc
                    |> List.map .heading
                    |> Expect.equal [ Verbatim "math" ]
        , test "meta.sourceText keeps the \\[...\\] the author typed (editor sync)" <|
            \_ ->
                XMarkdown.Compiler.parseFromString bracketSrc
                    |> List.map Tree.value
                    |> List.map (\b -> b.meta.sourceText)
                    |> Expect.equal [ "\\[\nx^2 + y^2 = z^2\n\\]" ]
        , test "mixed delimiters tolerated: \\[ ... $$" <|
            \_ ->
                essence "\\[\nx^2 + y^2 = z^2\n$$\n"
                    |> Expect.equal (essence dollarSrc)
        , test "mixed delimiters tolerated: $$ ... \\]" <|
            \_ ->
                essence "$$\nx^2 + y^2 = z^2\n\\]\n"
                    |> Expect.equal (essence dollarSrc)
        , test "missing closer tolerated, same as $$" <|
            \_ ->
                essence "\\[\nx^2 + y^2 = z^2\n\n"
                    |> Expect.equal (essence "$$\nx^2 + y^2 = z^2\n\n")
        , test "\\[ inside a code fence stays literal" <|
            \_ ->
                essence "```\n\\[\nx^2\n\\]\n```\n"
                    |> List.map .heading
                    |> Expect.equal [ Verbatim "code" ]
        , test "surrounding paragraphs are unaffected" <|
            \_ ->
                essence ("before\n\n" ++ bracketSrc ++ "\nafter\n")
                    |> List.map .heading
                    |> Expect.equal [ Paragraph, Verbatim "math", Paragraph ]
        , test "block ending at EOF (no trailing blank line) parses the same" <|
            \_ ->
                -- Regression: without a trailing blank line the block used to
                -- take an EOF path that skipped finalize, leaving the body
                -- reversed and the \] unnormalized (so KaTeX got a literal \]).
                essence "\\[\nx^2 + y^2 = z^2\n\\]"
                    |> Expect.equal (essence dollarSrc)
        ]

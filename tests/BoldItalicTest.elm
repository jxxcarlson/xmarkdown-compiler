module BoldItalicTest exposing (suite)

import Expect
import Generic.Language exposing (Expr(..), Expression)
import Test exposing (Test, describe, test)
import XMarkdown.Expression


{-| A compact, structural rendering of an inline expression tree, used to assert
the shape of a parse without pinning every source offset.
-}
tag : Expression -> String
tag expr =
    case expr of
        Text s _ ->
            "Text:" ++ s

        Fun n cs _ ->
            "Fun:" ++ n ++ "[" ++ String.join "," (List.map tag cs) ++ "]"

        VFun n s _ ->
            "VFun:" ++ n ++ ":" ++ s

        ExprList _ cs _ ->
            "ExprList[" ++ String.join "," (List.map tag cs) ++ "]"


dump : String -> List String
dump str =
    XMarkdown.Expression.parse 0 str |> List.map tag


suite : Test
suite =
    describe "XMarkdown bold / italic inline syntax"
        [ test "double-asterisk is bold" <|
            \_ ->
                dump "Hello **bold** world."
                    |> Expect.equal [ "Text:Hello ", "Fun:bold[Text:bold]", "Text: world." ]
        , test "single-asterisk is italic" <|
            \_ ->
                dump "Hello *italic* world."
                    |> Expect.equal [ "Text:Hello ", "Fun:italic[Text:italic]", "Text: world." ]
        , test "bold and italic in the same line" <|
            \_ ->
                dump "a **b** c *d* e"
                    |> Expect.equal
                        [ "Text:a ", "Fun:bold[Text:b]", "Text: c ", "Fun:italic[Text:d]", "Text: e" ]
        ]

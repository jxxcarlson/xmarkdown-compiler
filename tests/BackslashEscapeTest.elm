module BackslashEscapeTest exposing (suite)

{-| CommonMark backslash escapes: a backslash before an ASCII punctuation
character stands for that character, as in `\&`, `\_`, `\*`. `\(` still opens
inline math.
-}

import AST.Language exposing (Expr(..), Expression)
import Expect
import Parser.Inline.Expression
import Test exposing (Test, describe, test)


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
    Parser.Inline.Expression.parse 0 str |> List.map tag


suite : Test
suite =
    describe "backslash escapes"
        [ test "\\& in a link url" <|
            \_ ->
                dump "[image](https://www.google.com/s2/favicons?domain=https://t.co\\&sz=32)"
                    |> Expect.equal [ "Fun:link[Text:image https://www.google.com/s2/favicons?domain=https://t.co&sz=32]" ]
        , test "\\& in text" <|
            \_ ->
                dump "a\\&b c"
                    |> Expect.equal [ "Text:a&b c" ]
        , test "\\_ in text" <|
            \_ ->
                dump "snake\\_case"
                    |> Expect.equal [ "Text:snake_case" ]
        , test "\\* is not emphasis" <|
            \_ ->
                dump "a \\*not italic\\* c"
                    |> Expect.equal [ "Text:a *not italic* c" ]
        , test "\\\\ is a backslash" <|
            \_ ->
                dump "a\\\\b"
                    |> Expect.equal [ "Text:a\\b" ]
        , test "\\$ is not math" <|
            \_ ->
                dump "costs \\$5"
                    |> Expect.equal [ "Text:costs $5" ]
        , test "\\[ and \\] are not a link" <|
            \_ ->
                dump "\\[x\\](y)"
                    -- (y) is always a separate text node; it renders the same
                    |> Expect.equal [ "Text:[x]", "Text:(y)" ]
        , test "escape at the start of a line" <|
            \_ ->
                dump "\\# not a heading"
                    |> Expect.equal [ "Text:# not a heading" ]
        , test "\\( still opens inline math" <|
            \_ ->
                dump "a \\(x^2\\) b"
                    |> Expect.equal [ "Text:a ", "VFun:math:x^2", "Text: b" ]
        ]

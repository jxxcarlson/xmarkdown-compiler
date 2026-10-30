module UnclosedEmphasisTest exposing (suite)

{-| While the closing `*` or `**` has not been typed yet, the text so far is
shown italic or bold, followed by the unmatched marker in red.
-}

import AST.Language exposing (Expr(..), Expression)
import Expect
import HTML.Inline
import Html.Attributes
import Parser.Inline.Expression
import Render.Expression
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import XMarkdown.Types exposing (Theme(..))


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


meta : { begin : Int, end : Int, index : Int, id : String }
meta =
    { begin = 0, end = 0, index = 0, id = "e-0.0" }


suite : Test
suite =
    describe "unclosed * and **"
        [ test "*blah blah is italic text and a red *" <|
            \_ ->
                dump "*blah blah"
                    |> Expect.equal [ "Fun:italic[Text:blah blah]", "Fun:red[Text:* ]" ]
        , test "**blah blah is bold text and a red **" <|
            \_ ->
                dump "**blah blah"
                    |> Expect.equal [ "Fun:bold[Text:blah blah]", "Fun:red[Text:** ]" ]
        , test "text before an unclosed * is kept" <|
            \_ ->
                dump "x *blah blah ..."
                    |> Expect.equal [ "Text:x ", "Fun:italic[Text:blah blah ...]", "Fun:red[Text:* ]" ]
        , test "text before an unclosed ** is kept" <|
            \_ ->
                dump "x **blah blah ..."
                    |> Expect.equal [ "Text:x ", "Fun:bold[Text:blah blah ...]", "Fun:red[Text:** ]" ]
        , test "closed emphasis is unchanged" <|
            \_ ->
                dump "*a* and **b**"
                    |> Expect.equal [ "Fun:italic[Text:a]", "Text: and ", "Fun:bold[Text:b]" ]
        , test "red is rendered in red" <|
            \_ ->
                Render.Expression.render Light 0 [] (Fun "red" [ Text "*" meta ] meta)
                    |> Query.fromHtml
                    |> Query.has [ Selector.style "color" "rgb(179, 0, 0)", Selector.text "*" ]
        , test "red is red in an exported page" <|
            \_ ->
                HTML.Inline.exprs [ Fun "red" [ Text "*" meta ] meta ]
                    |> Expect.equal "<span class=\"xm-error\">*</span>"
        ]

module HTMLEscapeTest exposing (suite)

import Expect
import HTML.Escape
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "HTML.Escape"
        [ test "text escapes < > &" <|
            \_ ->
                HTML.Escape.text "a<b && c>d"
                    |> Expect.equal "a&lt;b &amp;&amp; c&gt;d"
        , test "text neutralises a script tag" <|
            \_ ->
                HTML.Escape.text "<script>alert(1)</script>"
                    |> Expect.equal "&lt;script&gt;alert(1)&lt;/script&gt;"
        , test "attribute escapes double and single quotes" <|
            \_ ->
                HTML.Escape.attribute "say \"hi\" & 'bye'"
                    |> Expect.equal "say &quot;hi&quot; &amp; &#39;bye&#39;"
        , test "an existing entity is escaped again (& first)" <|
            \_ ->
                HTML.Escape.text "&amp;"
                    |> Expect.equal "&amp;amp;"
        ]

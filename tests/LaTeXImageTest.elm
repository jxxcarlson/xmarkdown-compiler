module LaTeXImageTest exposing (suite)

import Expect
import LaTeX.Escape
import LaTeX.Image
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "LaTeX.Escape and LaTeX.Image"
        [ test "escapes every LaTeX special character" <|
            \_ ->
                LaTeX.Escape.text "\\ # $ % & _ { } ~ ^"
                    |> Expect.equal "\\textbackslash{} \\# \\$ \\% \\& \\_ \\{ \\} \\textasciitilde{} \\textasciicircum{}"
        , test "leaves ordinary text alone" <|
            \_ -> LaTeX.Escape.text "Hello, world." |> Expect.equal "Hello, world."
        , test "escapes % and # in URLs only" <|
            \_ ->
                LaTeX.Escape.url "https://x.com/a%20b#top_1"
                    |> Expect.equal "https://x.com/a\\%20b\\#top_1"
        , test "fromText: url first, caption, width property" <|
            \_ ->
                LaTeX.Image.fromText "https://x.com/a.jpg European Robin width:400"
                    |> Expect.equal { url = "https://x.com/a.jpg", caption = "European Robin", width = Just 400 }
        , test "fromText: colon words other than width/height stay in the caption" <|
            \_ ->
                LaTeX.Image.fromText "https://x.com/a.jpg Note: robin"
                    |> Expect.equal { url = "https://x.com/a.jpg", caption = "Note: robin", width = Nothing }
        , test "localPath: last segment, query and fragment dropped, unsafe chars replaced" <|
            \_ ->
                LaTeX.Image.localPath "https://x.com/a/b%20c.jpg?x=1#f"
                    |> Expect.all
                        [ String.startsWith "image/b-20c-" >> Expect.equal True
                        , String.endsWith ".jpg" >> Expect.equal True
                        , String.length >> Expect.equal (String.length "image/b-20c-123456.jpg")
                        ]
        , test "localPath: empty segment falls back to 'image'" <|
            \_ -> LaTeX.Image.localPath "https://x.com/" |> String.startsWith "image/image-" |> Expect.equal True
        , test "toLaTeX with caption: figure, width as fraction of 600px" <|
            \_ ->
                LaTeX.Image.toLaTeX { url = "https://x.com/a.jpg", caption = "A & B", width = Just 400 }
                    |> Expect.equal ("\\begin{figure}[h]\n\\centering\n\\includegraphics[width=0.67\\textwidth]{" ++ LaTeX.Image.localPath "https://x.com/a.jpg" ++ "}\n\\caption{A \\& B}\n\\end{figure}")
        , test "toLaTeX without caption or width: centered, 0.75 textwidth" <|
            \_ ->
                LaTeX.Image.toLaTeX { url = "https://x.com/a.jpg", caption = "", width = Nothing }
                    |> Expect.equal ("\\begin{center}\n\\includegraphics[width=0.75\\textwidth]{" ++ LaTeX.Image.localPath "https://x.com/a.jpg" ++ "}\n\\end{center}")
        , test "toLaTeX caps width at full textwidth" <|
            \_ ->
                LaTeX.Image.toLaTeX { url = "a.jpg", caption = "", width = Just 2000 }
                    |> String.contains "[width=1\\textwidth]"
                    |> Expect.equal True
        ]

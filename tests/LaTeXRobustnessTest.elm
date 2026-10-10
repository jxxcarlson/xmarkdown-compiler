module LaTeXRobustnessTest exposing (suite)

{-| Inputs from real documents that used to produce LaTeX that LaTeX rejects
(final review of the LaTeX export).
-}

import Expect
import LaTeX.Escape
import LaTeX.Export exposing (exportBody, imageUrls)
import LaTeX.Image
import Test exposing (Test, describe, test)


contains : String -> String -> Expect.Expectation
contains needle haystack =
    if String.contains needle haystack then
        Expect.pass

    else
        Expect.fail ("expected to find\n    " ++ needle ++ "\nin\n    " ++ haystack)


suite : Test
suite =
    describe "LaTeX export robustness"
        [ describe "ETeX fallback (C1)"
            [ test "a rejected formula with unbalanced braces is shown as text, not as math" <|
                \_ ->
                    exportBody "Bad $a^{b$ ok."
                        |> Expect.equal "Bad % ETeX error\n\\texttt{a\\textasciicircum{}\\{b} ok."
            , test "a rejected display formula with unbalanced braces is shown as text" <|
                \_ ->
                    exportBody "$$\n\\frac{1}{2\n$$"
                        |> Expect.equal "% ETeX error\n\\texttt{\\textbackslash{}frac\\{1\\}\\{2}"
            , test "a rejected formula that is still valid LaTeX is kept as math" <|
                \_ ->
                    exportBody "$$\na\"b\n$$"
                        |> Expect.equal "% ETeX error\n\\[\na\"b\n\\]"
            ]
        , describe "inline math (I1, I2)"
            [ test "empty inline math is dropped, not turned into $$" <|
                \_ ->
                    exportBody "Costs $$ and $x$ here."
                        |> String.contains "$$"
                        |> Expect.equal False
            , test "a bare % in inline math is escaped" <|
                \_ ->
                    exportBody "Mod $x % y$ and more."
                        |> contains "\\%"
            , test "an already escaped \\% in math is left alone" <|
                \_ ->
                    exportBody "Pct $50\\%$ done."
                        |> String.contains "\\\\%"
                        |> Expect.equal False
            ]
        , describe "image paths (I3)"
            [ test "same file name on different hosts gives different paths" <|
                \_ ->
                    LaTeX.Image.localPath "https://x.com/a/b%20c.jpg"
                        |> Expect.notEqual (LaTeX.Image.localPath "https://y.com/z/b%20c.jpg")
            , test "path keeps a readable stem and the extension" <|
                \_ ->
                    LaTeX.Image.localPath "https://x.com/a/b%20c.jpg?x=1"
                        |> Expect.all
                            [ String.startsWith "image/b-20c-" >> Expect.equal True
                            , String.endsWith ".jpg" >> Expect.equal True
                            ]
            , test "path is the same every time for the same URL" <|
                \_ ->
                    LaTeX.Image.localPath "https://x.com/a.png"
                        |> Expect.equal (LaTeX.Image.localPath "https://x.com/a.png")
            , test "an extensionless URL gets an extensionless path (graphicx searches extensions)" <|
                \_ ->
                    LaTeX.Image.localPath "https://picsum.photos/200"
                        |> String.dropLeft 6
                        |> String.contains "."
                        |> Expect.equal False
            , test "imageUrls lists both colliding names with distinct paths" <|
                \_ ->
                    imageUrls "![A](https://x.com/a/p.jpg)\n\n![B](https://y.com/z/p.jpg)"
                        |> List.map Tuple.second
                        |> (\paths -> List.length paths == 2 && List.head paths /= List.head (List.drop 1 paths))
                        |> Expect.equal True
            ]
        , describe "images where floats are not allowed (I4)"
            [ test "image in a table cell is a bare includegraphics" <|
                \_ ->
                    exportBody "| a | b |\n|---|---|\n| ![x](https://a.com/p.png) | y |"
                        |> Expect.all
                            [ String.contains "\\begin{figure}" >> Expect.equal False
                            , String.contains "\\begin{center}\n\\includegraphics" >> Expect.equal False
                            , contains "\\includegraphics[width="
                            ]
            , test "image in a heading is a bare includegraphics" <|
                \_ ->
                    exportBody "# Title ![x](https://a.com/p.png)"
                        |> String.contains "\\begin{figure}"
                        |> Expect.equal False
            ]
        , describe "brackets after line breaks (I5, I6)"
            [ test "a table row starting with [ is protected from \\\\[" <|
                \_ ->
                    exportBody "| x | y |\n|---|---|\n| [z] | w |"
                        |> contains "\\\\\n\\hline\n{}[z] & w"
            , test "a list item starting with [ keeps its bullet" <|
                \_ ->
                    exportBody "- [note] first\n- second"
                        |> contains "\\item{} [note] first\n\\item second"
            , test "a loose list item starting with [ keeps its bullet" <|
                \_ ->
                    exportBody "- [ ] todo\n\n- done"
                        |> contains "\\item{} [ ] todo"
            ]
        , describe "quotations (I7)"
            [ test "quotation lines are separated" <|
                \_ ->
                    exportBody "> line one\n> line two"
                        |> Expect.equal "\\begin{quote}\nline one\nline two\n\\end{quote}"
            , test "inline markup on one quotation line stays on that line" <|
                \_ ->
                    exportBody "> a **b**.\n> d"
                        |> Expect.equal "\\begin{quote}\na \\textbf{b}.\nd\n\\end{quote}"
            , test "an empty > line is a paragraph break, and the > does not leak" <|
                \_ ->
                    exportBody "> **bold**\n>\n> second para"
                        |> Expect.equal "\\begin{quote}\n\\textbf{bold}\n\nsecond para\n\\end{quote}"
            ]
        , describe "text inside math (etex 1.0.3)"
            [ test "words in \\text{...} are not turned into symbols" <|
                \_ ->
                    exportBody "\\[\n\\boxed{\\text{There exists a model satisfying all the rules simultaneously}.}\n\\]"
                        |> Expect.equal "\\[\n\\boxed{\\text{There exists a model satisfying all the rules simultaneously}.}\n\\]"
            , test "inline: math outside \\text is still converted, words inside are kept" <|
                \_ ->
                    exportBody "Here $x \\in A \\text{ for all x in B}$."
                        |> Expect.equal "Here $x \\in A \\text{ for all x in B}$."
            ]
        , describe "Unicode (I8)"
            [ test "non-ASCII text passes through unchanged (LuaLaTeX reads UTF-8)" <|
                \_ ->
                    LaTeX.Escape.text "α and Ω, ≈ → ✓ 中文"
                        |> Expect.equal "α and Ω, ≈ → ✓ 中文"
            ]
        ]

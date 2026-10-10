module LaTeXExportTest exposing (suite)

import Expect
import LaTeX.Export exposing (exportDocument, imageUrls)
import LaTeX.Image
import LaTeX.Preamble
import Test exposing (Test, describe, test)


noInfo : LaTeX.Export.DocumentInfo
noInfo =
    { title = "", authors = [], date = "" }


suite : Test
suite =
    describe "LaTeX.Export"
        [ test "plain document: minimal preamble, no maketitle" <|
            \_ ->
                exportDocument noInfo "Hello."
                    |> Expect.all
                        [ String.startsWith "\\documentclass[11pt]{article}\n\\usepackage{fontspec}\n" >> Expect.equal True
                        , String.endsWith "\\usepackage{stmaryrd}\n\\setlength{\\parindent}{0pt}\n\\setlength{\\parskip}{1em}\n\n\\begin{document}\n\nHello.\n\n\\end{document}\n" >> Expect.equal True
                        , String.contains "inputenc" >> Expect.equal False
                        ]
        , test "fonts: Latin Modern with fallback fonts for characters it lacks" <|
            \_ ->
                exportDocument noInfo "Hello."
                    |> Expect.all
                        [ String.contains "\\directlua{luaotfload.add_fallback(\"xmfallback\", {\\xmfallbacks})}" >> Expect.equal True
                        , String.contains "\\setmainfont{Latin Modern Roman}[RawFeature={fallback=xmfallback}]" >> Expect.equal True
                        , String.contains "\\IfFontExistsTF{FreeSerif.otf}" >> Expect.equal True
                        ]
        , test "title block and maketitle when info is given" <|
            \_ ->
                exportDocument { title = "Black Holes", authors = [ "A. Einstein", "K. Schwarzschild" ], date = "1916" } "Hi."
                    |> String.contains "\\title{Black Holes}\n\\author{A. Einstein \\and K. Schwarzschild}\n\\date{1916}\n\n\\begin{document}\n\n\\maketitle\n\nHi."
                    |> Expect.equal True
        , test "math pulls in amsmath and amssymb" <|
            \_ ->
                LaTeX.Preamble.make "$x$"
                    |> Expect.all
                        [ String.contains "\\usepackage{amsmath}" >> Expect.equal True
                        , String.contains "\\usepackage{amssymb}" >> Expect.equal True
                        ]
        , test "math pulls in mathtools (colon relations, extensible arrows)" <|
            \_ ->
                LaTeX.Preamble.make "$x$"
                    |> String.contains "\\usepackage{mathtools}"
                    |> Expect.equal True
        , test "bra-ket, bm, esint and arydshln are loaded only when used" <|
            \_ ->
                Expect.all
                    [ \_ -> LaTeX.Preamble.make "$\\bra{x}$" |> String.contains "\\usepackage{braket}" |> Expect.equal True
                    , \_ -> LaTeX.Preamble.make "$\\bm{x}$" |> String.contains "\\usepackage{bm}" |> Expect.equal True
                    , \_ -> LaTeX.Preamble.make "$\\oiint$" |> String.contains "\\usepackage{esint}" |> Expect.equal True
                    , \_ -> LaTeX.Preamble.make "$\\hdashline$" |> String.contains "\\usepackage{arydshln}" |> Expect.equal True
                    , \_ -> LaTeX.Preamble.make "$x$" |> String.contains "braket" |> Expect.equal False
                    ]
                    ()
        , test "KaTeX-only commands get a definition only when used" <|
            \_ ->
                Expect.all
                    [ \_ ->
                        LaTeX.Preamble.make "$\\argmax_x f$"
                            |> String.contains "\\providecommand{\\argmax}{\\operatorname*{arg\\,max}}"
                            |> Expect.equal True
                    , \_ ->
                        LaTeX.Preamble.make "$\\Alpha$"
                            |> String.contains "\\providecommand{\\Alpha}{\\mathrm{A}}"
                            |> Expect.equal True
                    , \_ -> LaTeX.Preamble.make "$x$" |> String.contains "providecommand" |> Expect.equal False
                    ]
                    ()
        , test "images pull in graphicx, links pull in hyperref, chem pulls in mhchem" <|
            \_ ->
                LaTeX.Preamble.make "\\includegraphics{a} \\href{u}{t} \\ce{H2O}"
                    |> Expect.all
                        [ String.contains "\\usepackage{graphicx}" >> Expect.equal True
                        , String.contains "\\usepackage{hyperref}" >> Expect.equal True
                        , String.contains "\\usepackage[version=4]{mhchem}" >> Expect.equal True
                        ]
        , test "stmaryrd is always loaded (for \\llbracket, \\rrbracket, ...)" <|
            \_ ->
                LaTeX.Preamble.make "Hello."
                    |> String.contains "\\usepackage{stmaryrd}"
                    |> Expect.equal True
        , test "paragraphs are unindented and separated by vertical space" <|
            \_ ->
                LaTeX.Preamble.make "Hello."
                    |> String.endsWith "\n\\setlength{\\parindent}{0pt}\n\\setlength{\\parskip}{1em}"
                    |> Expect.equal True
        , test "no optional packages for plain text" <|
            \_ ->
                LaTeX.Preamble.make "Hello."
                    |> String.contains "amsmath"
                    |> Expect.equal False
        , test "imageUrls: (url, localPath) pairs in order, without duplicates, including images in lists" <|
            \_ ->
                imageUrls "![A](https://x.com/a.jpg)\n\n- ![B](https://y.org/p/b%20c.png?s=1)\n\n![A again](https://x.com/a.jpg)"
                    |> Expect.equal
                        [ ( "https://x.com/a.jpg", LaTeX.Image.localPath "https://x.com/a.jpg" )
                        , ( "https://y.org/p/b%20c.png?s=1", LaTeX.Image.localPath "https://y.org/p/b%20c.png?s=1" )
                        ]
        , test "exported figure path matches imageUrls" <|
            \_ ->
                exportDocument noInfo "![A](https://y.org/p/b%20c.png?s=1)"
                    |> String.contains ("{" ++ LaTeX.Image.localPath "https://y.org/p/b%20c.png?s=1" ++ "}")
                    |> Expect.equal True
        ]

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
                    |> Expect.equal "\\documentclass[11pt]{article}\n\\usepackage[utf8]{inputenc}\n\\usepackage[T1]{fontenc}\n\\usepackage{stmaryrd}\n\\setlength{\\parindent}{0pt}\n\\setlength{\\parskip}{1em}\n\n\\begin{document}\n\nHello.\n\n\\end{document}\n"
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

module LaTeXSectionNumberTest exposing (suite)

{-| In the LaTeX export, a heading whose first word is a section number
made of digits and dots ("3.", "2.1", "1.2.3") loses that word: LaTeX
numbers sections itself.
-}

import Expect
import LaTeX.Export exposing (exportBody)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "section numbers in headings"
        [ test "# 3. Title" <|
            \_ -> exportBody "# 3. Blah blah" |> Expect.equal "\\section{Blah blah}"
        , test "## 2.1 Title" <|
            \_ -> exportBody "# A\n\n## 2.1 Blah blah" |> Expect.equal "\\section{A}\n\n\\subsection{Blah blah}"
        , test "### 1.2.3. Title" <|
            \_ -> exportBody "# A\n\n## B\n\n### 1.2.3. Blah" |> Expect.equal "\\section{A}\n\n\\subsection{B}\n\n\\subsubsection{Blah}"
        , test "inline markup after the number is kept" <|
            \_ -> exportBody "# 3. *Intro* and more" |> Expect.equal "\\section{\\emph{Intro} and more}"
        , test "a heading with no number is unchanged" <|
            \_ -> exportBody "# Introduction" |> Expect.equal "\\section{Introduction}"
        , test "a number without a dot is kept (2026)" <|
            \_ -> exportBody "# 2026 Plans" |> Expect.equal "\\section{2026 Plans}"
        , test "a word with letters is kept (3D)" <|
            \_ -> exportBody "# 3D Graphics" |> Expect.equal "\\section{3D Graphics}"
        , test "a word with letters, digits and dots is kept (v1.2)" <|
            \_ -> exportBody "# v1.2 Notes" |> Expect.equal "\\section{v1.2 Notes}"
        , test "only the first word is checked" <|
            \_ -> exportBody "# Intro to 3.1 things" |> Expect.equal "\\section{Intro to 3.1 things}"
        , test "a heading that is only a number becomes empty" <|
            \_ -> exportBody "# 4." |> Expect.equal "\\section{}"
        , test "numbers in paragraphs are untouched" <|
            \_ -> exportBody "See 3.2 above." |> Expect.equal "See 3.2 above."
        ]

module LaTeX.Preamble exposing (make)

{-| The document preamble. Optional packages are included only when the
exported body uses them.
-}


make : String -> String
make body =
    let
        uses str =
            String.contains str body

        usesMath =
            uses "$" || uses "\\[" || uses "\\begin{equation}" || uses "\\begin{align"

        optional condition packages =
            if condition then
                packages

            else
                []
    in
    String.join "\n"
        (List.concat
            [ [ "\\documentclass[11pt]{article}"
              , "\\usepackage[utf8]{inputenc}"
              , "\\usepackage[T1]{fontenc}"
              , "\\usepackage{stmaryrd}"
              ]
            , optional usesMath [ "\\usepackage{amsmath}", "\\usepackage{amssymb}" ]
            , optional (uses "\\ce{") [ "\\usepackage[version=4]{mhchem}" ]
            , optional (uses "\\includegraphics") [ "\\usepackage{graphicx}" ]

            -- hyperref should be loaded last
            , optional (uses "\\href") [ "\\usepackage{hyperref}" ]

            -- Unindented paragraphs separated by space, as in the HTML view
            , [ "\\setlength{\\parindent}{0pt}"
              , "\\setlength{\\parskip}{1em}"
              ]
            ]
        )

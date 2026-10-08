module LaTeX.Preamble exposing (make)

{-| The document preamble, for LuaLaTeX. Optional packages are included only
when the exported body uses them.

Text is set in Latin Modern (the OpenType Computer Modern) through fontspec.
Characters it lacks are taken from fallback fonts (luaotfload's `fallback`
feature): FreeSerif and DejaVu Sans, which ship with TeX Live, then CJK and
symbol fonts if this machine has them. A character no font has only produces
a "Missing character" warning in the log; it never stops the PDF.
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
            [ [ "\\documentclass[11pt]{article}" ]
            , fonts
            , [ "\\usepackage{stmaryrd}" ]
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


{-| Fallback fonts, in order. A font that isn't installed is skipped (a
missing font in luaotfload's fallback list is a fatal error).
-}
fallbackFonts : List String
fallbackFonts =
    [ "FreeSerif.otf" -- TeX Live: Greek, Cyrillic, many symbols
    , "DejaVuSans.ttf" -- TeX Live: arrows, math and technical symbols
    , "Hiragino Sans" -- macOS: Chinese, Japanese
    , "FandolSong-Regular.otf" -- TeX Live (full): Chinese
    , "Apple Symbols" -- macOS: more symbols
    ]


fonts : List String
fonts =
    [ "\\usepackage{fontspec}"
    , "\\def\\xmfallbacks{}"
    ]
        ++ List.map
            (\font ->
                "\\IfFontExistsTF{"
                    ++ font
                    ++ "}{\\edef\\xmfallbacks{\\xmfallbacks\\detokenize{\""
                    ++ luaotfloadName font
                    ++ ":mode=node;\",}}}{}"
            )
            fallbackFonts
        ++ [ "\\directlua{luaotfload.add_fallback(\"xmfallback\", {\\xmfallbacks})}"
           , "\\setmainfont{Latin Modern Roman}[RawFeature={fallback=xmfallback}]"
           , "\\setsansfont{Latin Modern Sans}[RawFeature={fallback=xmfallback}]"
           , "\\setmonofont{Latin Modern Mono}[RawFeature={fallback=xmfallback}]"
           ]


{-| Font files are looked up with "file:", installed fonts by name.
-}
luaotfloadName : String -> String
luaotfloadName font =
    if String.endsWith ".otf" font || String.endsWith ".ttf" font then
        "file:" ++ font

    else
        font

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
            , optional usesMath [ "\\usepackage{amsmath}", "\\usepackage{amssymb}", "\\usepackage{mathtools}" ]
            , optional (List.any uses [ "\\bra", "\\ket", "\\Bra", "\\Ket", "\\Set" ]) [ "\\usepackage{braket}" ]
            , optional (uses "\\bm") [ "\\usepackage{bm}" ]
            , optional (uses "\\oiint") [ "\\usepackage{esint}" ]
            , optional (uses "\\hdashline") [ "\\usepackage{arydshln}" ]
            , List.filterMap
                (\( name, definition ) ->
                    if uses ("\\" ++ name) then
                        Just definition

                    else
                        Nothing
                )
                katexOnly
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


{-| Commands KaTeX has (and ETeX knows) that LaTeX and the packages above
lack, as `\providecommand` definitions; each is emitted only when the body
uses the command. A few (`\oiiint`, `\xtofrom`, ...) are approximations.
-}
katexOnly : List ( String, String )
katexOnly =
    List.map (\( name, letter ) -> ( name, provide name ("\\mathrm{" ++ letter ++ "}") ))
        [ ( "Alpha", "A" ), ( "Beta", "B" ), ( "Chi", "X" ), ( "Epsilon", "E" ), ( "Eta", "H" ), ( "Iota", "I" ), ( "Kappa", "K" ), ( "Mu", "M" ), ( "Nu", "N" ), ( "Omicron", "O" ), ( "Rho", "P" ), ( "Tau", "T" ), ( "Zeta", "Z" ) ]
        ++ List.map (\( name, body ) -> ( name, provide name body ))
            [ ( "omicron", "o" )
            , ( "argmax", "\\operatorname*{arg\\,max}" )
            , ( "argmin", "\\operatorname*{arg\\,min}" )
            , ( "plim", "\\operatorname*{plim}" )
            , ( "cosec", "\\operatorname{cosec}" )
            , ( "cotg", "\\operatorname{cotg}" )
            , ( "ctg", "\\operatorname{ctg}" )
            , ( "cth", "\\operatorname{cth}" )
            , ( "dArr", "\\Downarrow" )
            , ( "uArr", "\\Uparrow" )
            , ( "varvdots", "\\vdots" )
            , ( "oiiint", "\\iiint" )

            -- colon relations, in terms of mathtools' names
            , ( "colonequals", "\\coloneqq" )
            , ( "colonminus", "\\coloneq" )
            , ( "coloncolon", "\\dblcolon" )
            , ( "coloncolonequals", "\\Coloneqq" )
            , ( "coloncolonminus", "\\Coloneq" )
            , ( "coloncolonapprox", "\\Colonapprox" )
            , ( "coloncolonsim", "\\Colonsim" )
            , ( "equalscolon", "\\eqqcolon" )
            , ( "equalscoloncolon", "\\Eqqcolon" )
            , ( "minuscolon", "\\eqcolon" )
            , ( "minuscoloncolon", "\\Eqcolon" )
            , ( "approxcoloncolon", "\\mathrel{\\approx\\dblcolon}" )
            , ( "simcoloncolon", "\\mathrel{\\sim\\dblcolon}" )
            ]
        ++ List.map (\( name, symbol ) -> ( name, provide1 name ("\\overset{" ++ symbol ++ "}{#1}") ))
            [ ( "Overrightarrow", "\\Longrightarrow" )
            , ( "overleftharpoon", "\\leftharpoonup" )
            , ( "overrightharpoon", "\\rightharpoonup" )
            ]
        ++ [ ( "utilde", provide1 "utilde" "\\underset{\\sim}{#1}" ) ]
        ++ List.map (\( name, symbol ) -> ( name, "\\providecommand{\\" ++ name ++ "}[2][]{\\mathrel{\\overset{#2}{\\underset{#1}{" ++ symbol ++ "}}}}" ))
            -- extensible arrows: \xname[below]{above}, at a fixed length
            [ ( "xlongequal", "=\\joinrel=\\joinrel=" )
            , ( "xtwoheadrightarrow", "\\twoheadrightarrow" )
            , ( "xtwoheadleftarrow", "\\twoheadleftarrow" )
            , ( "xrightleftarrows", "\\rightleftarrows" )
            , ( "xtofrom", "\\rightleftarrows" )
            , ( "xrightequilibrium", "\\rightleftharpoons" )
            , ( "xleftequilibrium", "\\leftrightharpoons" )
            ]


provide : String -> String -> String
provide name body =
    "\\providecommand{\\" ++ name ++ "}{" ++ body ++ "}"


provide1 : String -> String -> String
provide1 name body =
    "\\providecommand{\\" ++ name ++ "}[1]{" ++ body ++ "}"


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

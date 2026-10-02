module LaTeX.Escape exposing (text, url)

{-| Escaping for text placed in a LaTeX document.
-}

import Dict exposing (Dict)


{-| Escape the characters LaTeX treats specially in running text.
-}
text : String -> String
text str =
    str
        |> String.toList
        |> List.map escapeChar
        |> String.concat


escapeChar : Char -> String
escapeChar c =
    case c of
        '\\' ->
            "\\textbackslash{}"

        '#' ->
            "\\#"

        '$' ->
            "\\$"

        '%' ->
            "\\%"

        '&' ->
            "\\&"

        '_' ->
            "\\_"

        '{' ->
            "\\{"

        '}' ->
            "\\}"

        '~' ->
            "\\textasciitilde{}"

        '^' ->
            "\\textasciicircum{}"

        _ ->
            case Dict.get c greek of
                Just latex ->
                    latex

                Nothing ->
                    String.fromChar c


{-| pdflatex's utf8 input can't typeset Greek letters in text mode. Capitals
that look Latin become Latin letters; the rest become math-mode symbols.
-}
greek : Dict Char String
greek =
    let
        symbol name =
            "\\ensuremath{\\" ++ name ++ "}"
    in
    Dict.fromList
        ([ ( 'α', "alpha" ), ( 'β', "beta" ), ( 'γ', "gamma" ), ( 'δ', "delta" ), ( 'ε', "epsilon" ), ( 'ζ', "zeta" ), ( 'η', "eta" ), ( 'θ', "theta" ), ( 'ι', "iota" ), ( 'κ', "kappa" ), ( 'λ', "lambda" ), ( 'μ', "mu" ), ( 'ν', "nu" ), ( 'ξ', "xi" ), ( 'π', "pi" ), ( 'ρ', "rho" ), ( 'ς', "varsigma" ), ( 'σ', "sigma" ), ( 'τ', "tau" ), ( 'υ', "upsilon" ), ( 'φ', "phi" ), ( 'χ', "chi" ), ( 'ψ', "psi" ), ( 'ω', "omega" ), ( 'Γ', "Gamma" ), ( 'Δ', "Delta" ), ( 'Θ', "Theta" ), ( 'Λ', "Lambda" ), ( 'Ξ', "Xi" ), ( 'Π', "Pi" ), ( 'Σ', "Sigma" ), ( 'Υ', "Upsilon" ), ( 'Φ', "Phi" ), ( 'Ψ', "Psi" ), ( 'Ω', "Omega" ) ]
            |> List.map (Tuple.mapSecond symbol)
        )
        |> Dict.union
            (Dict.fromList
                [ ( 'Α', "A" ), ( 'Β', "B" ), ( 'Ε', "E" ), ( 'Ζ', "Z" ), ( 'Η', "H" ), ( 'Ι', "I" ), ( 'Κ', "K" ), ( 'Μ', "M" ), ( 'Ν', "N" ), ( 'Ο', "O" ), ( 'ο', "o" ), ( 'Ρ', "P" ), ( 'Τ', "T" ), ( 'Χ', "X" ) ]
            )


{-| Escape a URL for the first argument of hyperref's \\href.
Only % and # need it there.
-}
url : String -> String
url str =
    str
        |> String.replace "%" "\\%"
        |> String.replace "#" "\\#"

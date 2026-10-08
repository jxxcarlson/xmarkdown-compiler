module LaTeX.Escape exposing (text, url)

{-| Escaping for text placed in a LaTeX document.
-}

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

        -- Everything else, including non-ASCII, is passed through: LuaLaTeX
        -- reads UTF-8 and the preamble's fallback fonts cover what Latin
        -- Modern lacks (LaTeX.Preamble).
        _ ->
            String.fromChar c


{-| Escape a URL for the first argument of hyperref's \\href.
Only % and # need it there.
-}
url : String -> String
url str =
    str
        |> String.replace "%" "\\%"
        |> String.replace "#" "\\#"

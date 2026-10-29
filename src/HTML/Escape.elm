module HTML.Escape exposing (attribute, text)

{-| Escaping for text placed in an HTML document.
-}


{-| Element content: `& < > "`. `&` goes first so the entities it introduces
are not escaped again.
-}
text : String -> String
text str =
    str
        |> String.replace "&" "&amp;"
        |> String.replace "<" "&lt;"
        |> String.replace ">" "&gt;"
        |> String.replace "\"" "&quot;"


{-| An attribute value in double quotes; `'` too, so it is also safe in
single quotes.
-}
attribute : String -> String
attribute str =
    text str |> String.replace "'" "&#39;"

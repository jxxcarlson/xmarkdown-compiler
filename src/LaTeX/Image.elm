module LaTeX.Image exposing (Image, bare, fromText, localPath, toLaTeX)

{-| Images: the text of an XMarkdown image element ("url caption width:400")
to a LaTeX figure. Remote URLs can't be loaded by \\includegraphics, so the
figure points at a local file derived from the URL (see `localPath`); the app
downloads the files using `LaTeX.Export.imageUrls`.
-}

import LaTeX.Escape


type alias Image =
    { url : String, caption : String, width : Maybe Int }


{-| The URL is the first word; `width:N` / `height:N` words are properties;
the remaining words are the caption.
-}
fromText : String -> Image
fromText str =
    case String.words str of
        [] ->
            { url = "", caption = "", width = Nothing }

        url :: rest ->
            let
                isProperty word =
                    String.startsWith "width:" word || String.startsWith "height:" word

                ( properties, captionWords ) =
                    List.partition isProperty rest

                width =
                    properties
                        |> List.filterMap
                            (\p ->
                                if String.startsWith "width:" p then
                                    String.toInt (String.dropLeft 6 p)

                                else
                                    Nothing
                            )
                        |> List.head
            in
            { url = url, caption = String.join " " captionWords, width = width }


{-| `https://x.com/a/b%20c.jpg?x=1` -> `image/b-20c-1f3a9c.jpg`: a readable stem
from the URL's last path segment, a short hash of the whole URL (so two
images with the same file name on different hosts don't collide), and the
extension if the name has one. A URL with no extension gets a path with no
extension; \\includegraphics then tries .pdf, .png, .jpg, ... in turn, so the
downloader should save the file with the extension matching its type.
-}
localPath : String -> String
localPath url =
    let
        before sep s =
            String.split sep s |> List.head |> Maybe.withDefault s

        safe c =
            if Char.isAlphaNum c || c == '.' || c == '_' || c == '-' then
                c

            else
                '-'

        name =
            url
                |> before "?"
                |> before "#"
                |> String.split "/"
                |> List.reverse
                |> List.head
                |> Maybe.withDefault ""
                |> String.map safe

        ( stem, extension ) =
            case String.indexes "." name |> List.reverse |> List.head of
                Just i ->
                    let
                        ext =
                            String.dropLeft (i + 1) name
                    in
                    if i > 0 && ext /= "" && String.length ext <= 5 && String.all Char.isAlphaNum ext then
                        ( String.left i name, "." ++ ext )

                    else
                        ( name, "" )

                Nothing ->
                    ( name, "" )
    in
    "image/"
        ++ (if stem == "" then
                "image"

            else
                stem
           )
        ++ "-"
        ++ hash url
        ++ extension


{-| Six hex digits of a djb2 hash, enough to tell a document's images apart.
-}
hash : String -> String
hash str =
    let
        h =
            String.foldl (\c acc -> modBy 4294967296 (acc * 33 + Char.toCode c)) 5381 str

        hexDigit n =
            String.slice n (n + 1) "0123456789abcdef"

        toHex n width =
            if width == 0 then
                ""

            else
                toHex (n // 16) (width - 1) ++ hexDigit (modBy 16 n)
    in
    toHex (modBy 16777216 h) 6


{-| Just the \\includegraphics, for places where a figure or center
environment is not allowed (table cells, section titles).
-}
bare : Image -> String
bare image =
    "\\includegraphics[width=" ++ widthSpec image.width ++ "]{" ++ localPath image.url ++ "}"


toLaTeX : Image -> String
toLaTeX image =
    let
        graphic =
            bare image
    in
    if image.caption == "" then
        "\\begin{center}\n" ++ graphic ++ "\n\\end{center}"

    else
        "\\begin{figure}[h]\n\\centering\n"
            ++ graphic
            ++ "\n\\caption{"
            ++ LaTeX.Escape.text image.caption
            ++ "}\n\\end{figure}"


{-| Pixel width as a fraction of \\textwidth, taking 600px as the full width.
-}
widthSpec : Maybe Int -> String
widthSpec width =
    case width of
        Nothing ->
            "0.75\\textwidth"

        Just px ->
            let
                fraction =
                    min 1 (toFloat px / 600)
            in
            String.fromFloat (toFloat (round (fraction * 100)) / 100) ++ "\\textwidth"

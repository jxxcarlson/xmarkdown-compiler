module HTML.Inline exposing (MathMode(..), exprs, image, math, plainText)

{-| Inline XMarkdown expressions to HTML.
-}

import AST.Language exposing (Expr(..), Expression)
import Dict
import ETeX.Transform
import HTML.Escape
import LaTeX.Image
import LaTeX.Inline


type MathMode
    = InlineMath
    | DisplayMath


exprs : List Expression -> String
exprs list =
    list |> List.map expr |> String.concat


expr : Expression -> String
expr e =
    case e of
        Text str _ ->
            HTML.Escape.text str

        Fun name args _ ->
            fun name args

        VFun name content _ ->
            vfun name content

        ExprList _ list _ ->
            exprs list


fun : String -> List Expression -> String
fun name args =
    if List.member name [ "bold", "b", "strong" ] then
        "<strong>" ++ exprs args ++ "</strong>"

    else if List.member name [ "italic", "i", "em" ] then
        "<em>" ++ exprs args ++ "</em>"

    else if name == "link" || name == "a" then
        link (LaTeX.Inline.plainText args)

    else if name == "image" || name == "img" then
        image (LaTeX.Inline.plainText args)

    else
        unsupported name (exprs args)


vfun : String -> String -> String
vfun name content =
    if (name == "math" || name == "m") && String.trim content == "" then
        ""

    else if name == "math" || name == "m" then
        math InlineMath content

    else if name == "chem" then
        mathElement InlineMath ("\\ce{" ++ String.trim content ++ "}")

    else if name == "code" then
        "<code>" ++ HTML.Escape.text content ++ "</code>"

    else
        unsupported name (HTML.Escape.text content)


{-| The parser gives a link as one Text: "label words url".
-}
link : String -> String
link str =
    case List.reverse (String.words str) of
        [] ->
            ""

        url :: labelWords ->
            "<a href=\""
                ++ HTML.Escape.attribute (safeUrl "#" url)
                ++ "\">"
                ++ HTML.Escape.text (String.join " " (List.reverse labelWords))
                ++ "</a>"


{-| The text of an image element ("url caption width:400") to an `<img>`.
-}
image : String -> String
image str =
    let
        img =
            LaTeX.Image.fromText str

        width =
            case img.width of
                Just w ->
                    " width=\"" ++ String.fromInt w ++ "\""

                Nothing ->
                    ""
    in
    "<img class=\"xm-image\" src=\""
        ++ HTML.Escape.attribute (safeUrl "" img.url)
        ++ "\" alt=\""
        ++ HTML.Escape.attribute img.caption
        ++ "\""
        ++ width
        ++ ">"


{-| The url if its scheme is http, https or mailto, or it has none (a
relative url or `#anchor`); otherwise `replacement`. The live renderer gets
this from elm/virtual-dom; an exported page must do it itself.
-}
safeUrl : String -> String -> String
safeUrl replacement url =
    let
        beforeColon =
            String.split ":" url |> List.head |> Maybe.withDefault ""

        hasScheme =
            String.contains ":" url
                && not (String.contains "/" beforeColon || String.contains "?" beforeColon || String.contains "#" beforeColon)
    in
    if not hasScheme || List.member (String.toLower (String.trim beforeColon)) [ "http", "https", "mailto" ] then
        url

    else
        replacement


{-| All the text in the expressions, including text inside markup and the
source of math and code, with runs of spaces collapsed: for page titles and
heading slugs.
-}
plainText : List Expression -> String
plainText list =
    list |> List.map plainTextOf |> String.concat |> String.words |> String.join " "


plainTextOf : Expression -> String
plainTextOf e =
    case e of
        Text str _ ->
            str

        Fun _ args _ ->
            String.concat (List.map plainTextOf args)

        VFun _ content _ ->
            content

        ExprList _ list _ ->
            " " ++ String.concat (List.map plainTextOf list)


{-| ETeX -> LaTeX in an element for the page's KaTeX script. If the ETeX
parser rejects the input, the source is passed on as is, and KaTeX shows it
(in red, if it is not valid LaTeX either).
-}
math : MathMode -> String -> String
math mode source =
    let
        trimmed =
            String.trim source

        latex =
            ETeX.Transform.transformETeX Dict.empty trimmed
    in
    if String.startsWith "[ETeX error]" latex then
        mathElement mode trimmed

    else
        mathElement mode latex


mathElement : MathMode -> String -> String
mathElement mode latex =
    case mode of
        InlineMath ->
            "<span class=\"xm-math\" data-display=\"false\">" ++ HTML.Escape.text latex ++ "</span>"

        DisplayMath ->
            "<div class=\"xm-math\" data-display=\"true\">" ++ HTML.Escape.text latex ++ "</div>"


unsupported : String -> String -> String
unsupported name body =
    "<span class=\"xm-unsupported\" data-name=\"" ++ HTML.Escape.attribute name ++ "\">" ++ body ++ "</span>"

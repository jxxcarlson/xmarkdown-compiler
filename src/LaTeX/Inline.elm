module LaTeX.Inline exposing (exportExprs, exportExprsNoFloats, math, plainText)

{-| Inline XMarkdown expressions to LaTeX.
-}

import AST.Language exposing (Expr(..), Expression)
import Dict
import ETeX.Transform
import LaTeX.Escape
import LaTeX.Image


{-| Images become figures (floats) here; in table cells and section titles,
where floats are not allowed, use `exportExprsNoFloats`.
-}
type Mode
    = Flow
    | NoFloats


exportExprs : List Expression -> String
exportExprs =
    exportWith Flow


{-| Like `exportExprs`, but images are a bare \\includegraphics.
-}
exportExprsNoFloats : List Expression -> String
exportExprsNoFloats =
    exportWith NoFloats


exportWith : Mode -> List Expression -> String
exportWith mode exprs =
    exprs |> List.map (exportExpr mode) |> String.concat


exportExpr : Mode -> Expression -> String
exportExpr mode expr =
    case expr of
        Text str _ ->
            LaTeX.Escape.text str

        Fun name args _ ->
            fun mode name args

        VFun name content _ ->
            vfun name content

        ExprList _ exprs _ ->
            exportWith mode exprs


fun : Mode -> String -> List Expression -> String
fun mode name args =
    if List.member name [ "bold", "b", "strong" ] then
        "\\textbf{" ++ exportWith mode args ++ "}"

    else if List.member name [ "italic", "i", "em" ] then
        "\\emph{" ++ exportWith mode args ++ "}"

    else if name == "link" || name == "a" then
        link (plainText args)

    else if name == "image" || name == "img" then
        case mode of
            Flow ->
                LaTeX.Image.toLaTeX (LaTeX.Image.fromText (plainText args))

            NoFloats ->
                LaTeX.Image.bare (LaTeX.Image.fromText (plainText args))

    else
        unsupported name (exportWith mode args)


vfun : String -> String -> String
vfun name content =
    if (name == "math" || name == "m") && String.trim content == "" then
        -- `$$` inline, or a one-line `$$x$$`, parses as empty math; emitting
        -- `$$` would open display math.
        ""

    else if name == "math" || name == "m" then
        math "$" "$" content

    else if name == "chem" then
        "\\ce{" ++ escapePercent content ++ "}"

    else if name == "code" then
        "\\texttt{" ++ LaTeX.Escape.text content ++ "}"

    else
        unsupported name (LaTeX.Escape.text content)


{-| The parser gives a link as one Text: "label words url".
-}
link : String -> String
link str =
    case List.reverse (String.words str) of
        [] ->
            ""

        url :: labelWords ->
            "\\href{"
                ++ LaTeX.Escape.url url
                ++ "}{"
                ++ LaTeX.Escape.text (String.join " " (List.reverse labelWords))
                ++ "}"


{-| ETeX -> LaTeX, wrapped in `open` and `close`. If the ETeX parser rejects
the input, one bad formula must not stop the document from compiling: keep
the source as math only if it is plausibly valid LaTeX (balanced braces, no
`$`), otherwise show it as typewriter text. Either way it is marked with a
`% ETeX error` comment.
-}
math : String -> String -> String -> String
math open close source =
    let
        trimmed =
            String.trim source

        latex =
            ETeX.Transform.transformETeX Dict.empty trimmed
    in
    if String.startsWith "[ETeX error]" latex then
        if bracesBalance trimmed && not (String.contains "$" trimmed) then
            "% ETeX error\n" ++ open ++ escapePercent trimmed ++ close

        else
            "% ETeX error\n\\texttt{" ++ LaTeX.Escape.text trimmed ++ "}"

    else
        open ++ escapePercent latex ++ close


{-| Braces nest properly, ignoring escaped ones (`\\{`, `\\}`).
-}
bracesBalance : String -> Bool
bracesBalance str =
    let
        step c ( depth, escaped, ok ) =
            if escaped then
                ( depth, False, ok )

            else if c == '\\' then
                ( depth, True, ok )

            else if c == '{' then
                ( depth + 1, False, ok )

            else if c == '}' then
                ( depth - 1, False, ok && depth > 0 )

            else
                ( depth, False, ok )

        ( finalDepth, _, balanced ) =
            String.foldl step ( 0, False, True ) str
    in
    balanced && finalDepth == 0


{-| A bare `%` would comment out the rest of the output line (often the rest
of the paragraph); `\\%` is left alone.
-}
escapePercent : String -> String
escapePercent str =
    let
        step c ( acc, escaped ) =
            if escaped then
                ( String.fromChar c :: acc, False )

            else if c == '\\' then
                ( "\\" :: acc, True )

            else if c == '%' then
                ( "\\%" :: acc, False )

            else
                ( String.fromChar c :: acc, False )
    in
    String.foldl step ( [], False ) str
        |> Tuple.first
        |> List.reverse
        |> String.concat


plainText : List Expression -> String
plainText exprs =
    exprs
        |> List.map
            (\expr ->
                case expr of
                    Text str _ ->
                        str

                    _ ->
                        ""
            )
        |> String.concat
        |> String.trim


unsupported : String -> String -> String
unsupported name body =
    "% unsupported: " ++ name ++ "\n" ++ body

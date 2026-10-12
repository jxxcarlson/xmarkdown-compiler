module Normalize exposing (headings)

{-| File > Normalize: remove hand-written section numbers from headings, so
`# 1. Intro` becomes `# Intro` and `## 2.1 Results` becomes `## Results`.

A number must contain a dot (`1.`, `2.1`, `2.1.`), so a heading like
`# 2024 Results` is left alone. Lines inside code fences are not touched.
-}

import Regex exposing (Regex)


headings : String -> String
headings source =
    source
        |> String.lines
        |> List.foldl step ( False, [] )
        |> Tuple.second
        |> List.reverse
        |> String.join "\n"


{-| The Bool is whether we are inside a code fence.
-}
step : String -> ( Bool, List String ) -> ( Bool, List String )
step line ( inFence, acc ) =
    if isFence line then
        ( not inFence, line :: acc )

    else if inFence then
        ( inFence, line :: acc )

    else
        ( inFence, Regex.replace numberedHeading (\m -> String.concat (List.map (Maybe.withDefault "") m.submatches)) line :: acc )


isFence : String -> Bool
isFence line =
    let
        trimmed =
            String.trimLeft line
    in
    String.startsWith "```" trimmed || String.startsWith "~~~" trimmed


{-| `#`s and the space after them, then a number such as `1.` or `2.1`, then
the spaces after the number. Only the first group is kept.
-}
numberedHeading : Regex
numberedHeading =
    Regex.fromString "^(#{1,6} +)(?:\\d+\\.)+\\d*(?: +|$)"
        |> Maybe.withDefault Regex.never

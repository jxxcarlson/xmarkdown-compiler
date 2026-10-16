module Normalize exposing (normalize)

{-| File > Normalize: tidy up the source text.

  - Hand-written section numbers are removed from headings, so `# 1. Intro`
    becomes `# Intro` and `## 2.1 Results` becomes `## Results`. A number
    must contain a dot (`1.`, `2.1`, `2.1.`), so a heading like
    `# 2024 Results` is left alone. The dot may be escaped, as in
    `# 3\. Intro`.
  - Display math written with `\[ ... \]` gets a blank line before and after
    it.

Lines inside code fences are not touched, and neither are lines inside display
math.

-}

import Regex exposing (Regex)


type alias State =
    { inFence : Bool
    , inMath : Bool

    -- the previous line closed display math
    , mathJustEnded : Bool
    , lines : List String -- reversed
    }


normalize : String -> String
normalize source =
    source
        |> String.lines
        |> List.foldl step { inFence = False, inMath = False, mathJustEnded = False, lines = [] }
        |> .lines
        |> List.reverse
        |> String.join "\n"


step : String -> State -> State
step line state =
    let
        trimmed =
            String.trim line

        -- a blank line after display math, unless this line is already blank
        st =
            if state.mathJustEnded && trimmed /= "" then
                { state | mathJustEnded = False, lines = "" :: state.lines }

            else
                { state | mathJustEnded = False }
    in
    if st.inFence then
        { st | inFence = not (isFence trimmed), lines = line :: st.lines }

    else if st.inMath then
        { st | inMath = not (closesMath trimmed), mathJustEnded = closesMath trimmed, lines = line :: st.lines }

    else if isFence trimmed then
        { st | inFence = True, lines = line :: st.lines }

    else if String.startsWith "\\[" trimmed then
        let
            closed =
                closesMath (String.dropLeft 2 trimmed)
        in
        { st
            | inMath = not closed
            , mathJustEnded = closed
            , lines = line :: blankBefore st.lines
        }

    else
        { st | lines = stripNumber line :: st.lines }


{-| A blank line before display math, unless it starts the document or
follows a blank line.
-}
blankBefore : List String -> List String
blankBefore lines =
    case lines of
        previous :: _ ->
            if String.trim previous == "" then
                lines

            else
                "" :: lines

        [] ->
            lines


closesMath : String -> Bool
closesMath trimmed =
    String.endsWith "\\]" trimmed


isFence : String -> Bool
isFence trimmed =
    String.startsWith "```" trimmed || String.startsWith "~~~" trimmed


stripNumber : String -> String
stripNumber line =
    Regex.replace numberedHeading (\m -> String.concat (List.map (Maybe.withDefault "") m.submatches)) line


{-| `#`s and the space after them, then a number such as `1.`, `2.1` or
`3\.` (an escaped dot), then the spaces after the number. Only the first
group is kept.
-}
numberedHeading : Regex
numberedHeading =
    Regex.fromString "^(#{1,6} +)(?:\\d+\\\\?\\.)+\\d*(?: +|$)"
        |> Maybe.withDefault Regex.never

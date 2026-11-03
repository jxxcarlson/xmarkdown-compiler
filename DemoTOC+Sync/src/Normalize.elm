module Normalize exposing (normalize, preprocess)

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


{-| This is fix text produced by openAI

  - Display math written with doubled backslashes, as in

        \\[ \max_\pi \mathbb{E}_\pi[r], \\]

    becomes

        \[
        \max_\pi \mathbb{E}_\pi[r],
        \]

    The opening `\\[` must start a line and the closing `\\]` must end one
    (they may be on the same line or on different lines), so a LaTeX line
    break with spacing such as `a \\[2pt] b` is left alone.

  - Inside display math (`\[ ... \]`, `$$ ... $$`, and the `\\[ ... \\]`
    form above), the Markdown escape `\_` becomes `_`, so `\max\_\pi` is a
    subscript rather than a literal underscore.

  - Lines holding only spaces become empty lines. The parser does not treat
    a whitespace-only line as blank, so without this a display-math block
    after such a line is glued onto the preceding paragraph.

Lines inside code fences are not touched.

-}
preprocess : String -> String
preprocess source =
    source
        |> String.lines
        |> List.foldl preprocessStep { inFence = False, mathCloser = Nothing, lines = [] }
        |> .lines
        |> List.reverse
        |> String.join "\n"


type alias PreprocessState =
    { inFence : Bool

    -- inside display math: the delimiter that closes it
    , mathCloser : Maybe String
    , lines : List String -- reversed
    }


preprocessStep : String -> PreprocessState -> PreprocessState
preprocessStep line state =
    let
        trimmed =
            String.trim line

        indent =
            String.left (String.length line - String.length (String.trimLeft line)) line

        -- emit lines (given in order) with the original indentation;
        -- empty content lines are dropped
        emit : List String -> List String -> List String
        emit new acc =
            List.foldl
                (\l a ->
                    if String.trim l == "" then
                        a

                    else
                        (indent ++ unescapeMath (String.trim l)) :: a
                )
                acc
                new

        push l =
            { state | lines = l :: state.lines }
    in
    if state.inFence then
        { state | inFence = not (isFence trimmed), lines = line :: state.lines }

    else
        case state.mathCloser of
            Just closer ->
                if not (String.endsWith closer trimmed) then
                    push (unescapeMath line)

                else if closer == openAIClose then
                    { state
                        | mathCloser = Nothing
                        , lines = emit [ String.dropRight 3 trimmed, "\\]" ] state.lines
                    }

                else
                    { state | mathCloser = Nothing, lines = unescapeMath line :: state.lines }

            Nothing ->
                if trimmed == "" then
                    push ""

                else if isFence trimmed then
                    { state | inFence = True, lines = line :: state.lines }

                else if String.startsWith openAIOpen trimmed then
                    let
                        rest =
                            String.dropLeft 3 trimmed
                    in
                    if String.endsWith openAIClose rest then
                        { state | lines = emit [ "\\[", String.dropRight 3 rest, "\\]" ] state.lines }

                    else
                        { state | mathCloser = Just openAIClose, lines = emit [ "\\[", rest ] state.lines }

                else if String.startsWith "\\[" trimmed then
                    openMath "\\]" (String.dropLeft 2 trimmed) line state

                else if String.startsWith "$$" trimmed then
                    openMath "$$" (String.dropLeft 2 trimmed) line state

                else
                    push line


{-| A line opening display math that is already in the right form; `rest` is
what follows the opening delimiter.
-}
openMath : String -> String -> String -> PreprocessState -> PreprocessState
openMath closer rest line state =
    { state
        | mathCloser =
            if String.endsWith closer rest then
                Nothing

            else
                Just closer
        , lines = unescapeMath line :: state.lines
    }


openAIOpen : String
openAIOpen =
    "\\\\["


openAIClose : String
openAIClose =
    "\\\\]"


unescapeMath : String -> String
unescapeMath =
    String.replace "\\_" "_"


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

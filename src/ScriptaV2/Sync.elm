module ScriptaV2.Sync exposing (SyncHighlight, fromMsg, encode, highlightAttribute)

{-| Maps rendered-text clicks (as MarkupMsg) into a source-span highlight the
CodeMirror editor can apply (RL sync: rendered → editor).

@docs SyncHighlight, fromMsg, encode, highlightAttribute

-}

import Html
import Html.Attributes
import Json.Encode as E
import ScriptaV2.Config as Config
import ScriptaV2.Msg exposing (MarkupMsg(..))


{-| A source span to highlight in the editor.

  - `line` is 1-indexed (CodeMirror lines).
  - `colBegin`/`colEnd` are within-line columns, `colEnd` inclusive. Both 0 for
    a whole-line / block highlight.
  - `lineCount` is 0 for a single-line phrase, > 0 for a block line range.
  - `tick` is a monotonic counter so repeat clicks on the same span re-trigger
    the editor (the attribute value changes, so Elm re-pushes it).

-}
type alias SyncHighlight =
    { line : Int
    , colBegin : Int
    , colEnd : Int
    , lineCount : Int
    , tick : Int
    }


{-| Map a MarkupMsg to a highlight. `Nothing` for messages that are not RL
clicks, or when the id cannot be parsed (better no highlight than a wrong one).
-}
fromMsg : Int -> MarkupMsg -> Maybe SyncHighlight
fromMsg tick msg =
    case msg of
        SendMeta m ->
            lineFromId m.id
                |> Maybe.map
                    (\line0 ->
                        { line = line0 + 1
                        , colBegin = m.begin
                        , colEnd = m.end
                        , lineCount = 0
                        , tick = tick
                        }
                    )

        SendLineNumber r ->
            Just
                { line = r.begin + 1
                , colBegin = 0
                , colEnd = 0
                , lineCount = r.end - r.begin
                , tick = tick
                }

        _ ->
            Nothing


{-| Parse the 0-indexed source line from an expression id of the form
`"e-<line>.<tok>"`. Returns Nothing on any shape mismatch.
-}
lineFromId : String -> Maybe Int
lineFromId id =
    if String.startsWith Config.expressionIdPrefix id then
        id
            |> String.dropLeft (String.length Config.expressionIdPrefix)
            |> String.split "."
            |> List.head
            |> Maybe.andThen String.toInt

    else
        Nothing


{-| Compact JSON for the `highlight` custom-element attribute. Key order is
fixed so it is easy to assert in tests.
-}
encode : SyncHighlight -> String
encode h =
    E.encode 0
        (E.object
            [ ( "line", E.int h.line )
            , ( "colBegin", E.int h.colBegin )
            , ( "colEnd", E.int h.colEnd )
            , ( "lineCount", E.int h.lineCount )
            , ( "tick", E.int h.tick )
            ]
        )


{-| The `highlight` attribute to splat onto the editor node, or `[]` when there
is nothing to highlight.
-}
highlightAttribute : Maybe SyncHighlight -> List (Html.Attribute msg)
highlightAttribute mh =
    case mh of
        Just h ->
            [ Html.Attributes.attribute "highlight" (encode h) ]

        Nothing ->
            []

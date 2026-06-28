module XMarkdown.Sync exposing (SyncHighlight, fromMsg, encode, highlightAttribute)

{-| RL sync (rendered → editor): clicking rendered text highlights and scrolls
to the corresponding source span in the CodeMirror editor.


# The algorithm, end to end

1.  **Capture (in the compiler's renderer).** Every rendered element already
    carries a click handler:

      - inline expressions emit `SendMeta { begin, end, index, id }` (and the
        handler uses `stopPropagation`, so a click on a phrase reports the
        phrase, not its enclosing block);
      - blocks emit `SendLineNumber { begin, end }`.

    These arrive in the host app's `update` as a `MarkupMsg`.

2.  **Map (this module).** [`fromMsg`](#fromMsg) turns that `MarkupMsg` into a
    [`SyncHighlight`](#SyncHighlight) — a small, editor-ready description of the
    span to mark. The host stores it (bumping a `tick`) and renders it onto the
    editor element via [`highlightAttribute`](#highlightAttribute), which sets a
    JSON `highlight` attribute ([`encode`](#encode)).

3.  **Apply (in editor.js).** The custom element observes the `highlight`
    attribute, decodes it, computes a CodeMirror `from`/`to`, paints a
    `.cm-sync-highlight` decoration there, and scrolls it into view.


# Coordinate systems — the crux (this is what makes it correct)

The two click messages report positions in **two different coordinate systems**,
and CodeMirror works in a third. Getting RL sync right is entirely about mapping
them correctly:

  - **Inline (`SendMeta`)**: `begin`/`end` are **absolute document character
    offsets** into the whole source string — NOT within-line columns — and
    `end` is **inclusive** (the index of the last character of the span).
    Example: in a document whose line 3 is the paragraph "The Schwarzschild
    radius …", that paragraph's expression is `begin = 26, end = 204`, where 26
    is the character offset at which line 3 begins.

  - **Block (`SendLineNumber`)**: `begin`/`end` are **1-indexed source line
    numbers**. `begin` is the block's first line; `end = begin + numberOfLines`,
    so the last (inclusive) line of the block is `end - 1`.

  - **CodeMirror**: a position is an **absolute document character offset**
    (`doc.line(n)` is **1-indexed**).

Therefore:

  - inline → a character range: `from = begin`, `to = end + 1` (inclusive → half
    open). CodeMirror offsets already ARE document offsets, so no line/column
    arithmetic is involved. → `mode = "chars"`.
  - block → a 1-indexed inclusive line range `start = begin`, `end = end - 1`,
    which editor.js resolves with `doc.line(start).from` … `doc.line(end).to`.
    → `mode = "lines"`.

The classic mistake (and the bug this code was written to fix) is to treat the
inline `begin`/`end` as within-line columns and add them to a line start — that
silently "works" only on a single-line document (where a document offset equals
a column) and displaces the highlight everywhere else.

The document offsets are consistent between the compiler and the editor because
both operate on the same source text (the editor's document is the very string
the compiler parsed).


@docs SyncHighlight, fromMsg, encode, highlightAttribute

-}

import Html
import Html.Attributes
import Json.Encode as E
import XMarkdown.Msg exposing (MarkupMsg(..))


{-| A source span to highlight in the editor.

  - `mode = "chars"`: `start`/`end` are document character offsets (`end`
    exclusive). Used for inline (phrase) clicks.
  - `mode = "lines"`: `start`/`end` are 1-indexed source lines, both inclusive.
    Used for block clicks.
  - `tick` is a monotonic counter so repeat clicks on the same span re-trigger
    the editor (the attribute value changes, so Elm re-pushes it).

-}
type alias SyncHighlight =
    { mode : String
    , start : Int
    , end : Int
    , tick : Int
    }


{-| Map a MarkupMsg to a highlight. `Nothing` for messages that are not RL clicks.
-}
fromMsg : Int -> MarkupMsg -> Maybe SyncHighlight
fromMsg tick msg =
    case msg of
        SendMeta m ->
            -- begin/end are absolute document char offsets; end is inclusive.
            Just { mode = "chars", start = m.begin, end = m.end + 1, tick = tick }

        SendLineNumber r ->
            -- begin is the 1-indexed first line; end = firstLine + numberOfLines,
            -- so the last inclusive line is end - 1.
            Just { mode = "lines", start = r.begin, end = r.end - 1, tick = tick }

        _ ->
            Nothing


{-| Compact JSON for the `highlight` custom-element attribute. Key order is
fixed so it is easy to assert in tests.
-}
encode : SyncHighlight -> String
encode h =
    E.encode 0
        (E.object
            [ ( "mode", E.string h.mode )
            , ( "start", E.int h.start )
            , ( "end", E.int h.end )
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

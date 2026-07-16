module XMarkdown.Editor exposing (Config, view, textChangeDecoder, renderedTextId)

{-| Reusable wiring for the `<codemirror-editor>` custom element (defined in JS,
e.g. DemoTOC+Sync/assets/editor.js).

@docs Config, view, textChangeDecoder, renderedTextId

-}

import Html exposing (Html)
import Html.Attributes
import Html.Events
import Json.Decode as D
import XMarkdown.Sync
import XMarkdown.Types exposing (SyncHighlight)


{-| Configuration for [`view`](#view).

  - `source` is applied to the `load` attribute. Pass a value that changes
    ONLY on intentional external resets (e.g. an initial document). Binding it
    to live-edited text re-pushes the attribute on every keystroke and jumps
    the cursor.
  - `onInput` is fired for each user edit, carrying the full document text.
  - `attrs` are extra attributes the caller adds (e.g. a sizing class).

-}
type alias Config msg =
    { source : String
    , onInput : String -> msg
    , highlight : Maybe SyncHighlight
    , attrs : List (Html.Attribute msg)
    }


{-| Render the editor custom element. -}
view : Config msg -> Html msg
view config =
    Html.node "codemirror-editor"
        (Html.Attributes.attribute "load" config.source
            :: Html.Events.on "text-change" (D.map config.onInput textChangeDecoder)
            :: (XMarkdown.Sync.highlightAttribute config.highlight ++ config.attrs)
        )
        []


{-| Decode the `text-change` CustomEvent, extracting the full source text from
`event.detail.source`.
-}
textChangeDecoder : D.Decoder String
textChangeDecoder =
    D.at [ "detail", "source" ] D.string


{-| The DOM id agreed for the rendered-text container. Phase 2 RL-sync JS binds
its click/selection handlers to this id.
-}
renderedTextId : String
renderedTextId =
    "__RENDERED_TEXT__"

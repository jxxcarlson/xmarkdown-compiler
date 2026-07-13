module Render.Helper exposing (showError)

import Html exposing (Html)
import Html.Attributes
import Render.Theme
import XMarkdown.Types exposing (MarkupMsg, Theme)


showError : Theme -> Maybe String -> Html MarkupMsg -> Html MarkupMsg
showError theme maybeError x =
    case maybeError of
        Nothing ->
            x

        Just error ->
            Html.div []
                [ x
                , Html.div [ Html.Attributes.style "color" (Render.Theme.themedColor .text theme) ] [ Html.text error ]
                ]

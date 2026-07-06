module Render.Helper exposing
    ( showError
    , topPaddingForIndentedElements
    )

import Html exposing (Html)
import Html.Attributes
import XMarkdown.Types exposing (MarkupMsg)


topPaddingForIndentedElements =
    10


showError : Maybe String -> Html MarkupMsg -> Html MarkupMsg
showError maybeError x =
    case maybeError of
        Nothing ->
            x

        Just error ->
            Html.div []
                [ x
                , Html.div [ Html.Attributes.style "color" "rgb(179, 0, 0)" ] [ Html.text error ]
                ]

module Render.Helper exposing (codeFont, showError)

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


{-| Font for code. Naming a real font avoids the browser's bare `monospace`
default, which is drawn smaller than the surrounding text. Code is set at
0.9em (see Render.VerbatimBlock and Render.Expression).
-}
codeFont : Html.Attribute msg
codeFont =
    Html.Attributes.style "font-family" "ui-monospace, SFMono-Regular, Menlo, Consolas, \"Liberation Mono\", monospace"

module Render.ThemeHelpers exposing (..)

import Render.Theme
import XMarkdown.Types exposing (Theme(..))


themeAsStringFromSettings : Render.Theme.RenderSettings -> String
themeAsStringFromSettings settings =
    case settings.theme of
        Light ->
            "light"

        Dark ->
            "dark"

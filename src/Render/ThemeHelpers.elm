module Render.ThemeHelpers exposing (..)

import Render.Settings
import XMarkdown.Types exposing (Theme(..))


themeAsStringFromSettings : Render.Settings.RenderSettings -> String
themeAsStringFromSettings settings =
    case settings.theme of
        Light ->
            "light"

        Dark ->
            "dark"

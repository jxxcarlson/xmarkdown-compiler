module Render.Color exposing (blue, boxBackground, redText)

{-| This module provides color constants for use in the rendering system.

@docs blue, boxBackground, redText

-}

import Element as E
import Render.Settings
import Render.Theme


{-| Blue color for text
-}
blue : E.Color
blue =
    E.rgb 0 0 0.8


{-| Background color for box elements - light warm gray
-}
boxBackground : Render.Theme.Theme -> E.Color
boxBackground theme =
    Render.Settings.getThemedElementColor .offsetBackground theme


{-| Color for red text
-}
redText : E.Color
redText =
    E.rgb 0.8 0 0

module Render.Color exposing (boxBackground)

{-| This module provides color constants for use in the rendering system.

@docs boxBackground

-}

import Element as E
import Render.Settings
import Render.Theme


{-| Background color for box elements - light warm gray
-}
boxBackground : Render.Theme.Theme -> E.Color
boxBackground theme =
    Render.Settings.getThemedElementColor .offsetBackground theme

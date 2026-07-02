module Render.Theme exposing
    ( ActualTheme
    , getColor
    , lightTheme, darkTheme
    , colorFromTheme
    )

{-| Theme support for Scripta rendering.

This module provides light and dark themes for rendering Scripta documents,
with support for both raw Color values and elm-ui Element.Color.


# Types

@docs Theme, ActualTheme


# Theme Selection

@docs getColor, getElementColor


# Predefined Themes

@docs lightTheme, darkTheme

-}

import Color
import Render.NewColor exposing (..)
import XMarkdown.Types exposing (Theme(..))


{-| A theme's color palette, containing colors for various UI elements.
-}
type alias ActualTheme =
    { background : Color
    , text : Color
    , codeBackground : Color
    , codeText : Color
    , offsetBackground : Color
    , offsetText : Color
    , link : Color
    , highlight : Color
    }


{-| Get a Color value from the selected theme.

    myTextColor =
        getColor Light .text

-}
getColor : Theme -> (ActualTheme -> Color) -> Color
getColor theme colorSelector =
    let
        actualTheme =
            case theme of
                Light ->
                    lightTheme

                Dark ->
                    darkTheme
    in
    colorSelector actualTheme


{-| Get Color value from the selected theme.
-}
colorFromTheme : Theme -> (ActualTheme -> Color) -> Color.Color
colorFromTheme theme colorSelector =
    let
        actualTheme =
            case theme of
                Light ->
                    lightTheme

                Dark ->
                    darkTheme
    in
    colorSelector actualTheme


{-| The predefined light theme with professional, readable colors.
-}
lightTheme : ActualTheme
lightTheme =
    { background = whiteAlpha100
    , text = gray950
    , codeBackground = Color.rgba 0.9 0.9 0.94 1
    , codeText = gray900
    , offsetBackground = whiteAlpha100
    , offsetText = gray800
    , link = indigo600
    , highlight = transparentIndigo500
    }


{-| The predefined dark theme with reduced eye strain for low-light environments.
-}
darkTheme : ActualTheme
darkTheme =
    { background = gray900
    , text = gray100
    , codeBackground = Color.rgba 0.35 0.37 0.42 1
    , codeText = gray100
    , offsetBackground = gray700
    , offsetText = gray200
    , link = indigo600
    , highlight = transparentIndigo500
    }

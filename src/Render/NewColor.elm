module Render.NewColor exposing
    ( Color
    , blue300
    , indigo200, indigo500, indigo600
    , gray100, gray200, gray300, gray400, gray600, gray700, gray800, gray900, gray920, gray950
    , blue700, blueDark, blueLight, indigo900, indigo950, midnightIndigo, transparentIndigo500, whiteAlpha100
    )

{-| A native macOS-inspired color system with professional, subtle tones.


# Types

@docs Color


# Base Colors

@docs black, white


# Color Scales

Each color comes in 9 harmonized shades (100-900).
Shades are balanced across different hues, meaning blue500 and green500 have similar brightness.

@docs blue300, blue500
@docs indigo200, indigo500, indigo600
@docs gray100, gray200, gray300, gray400, gray600, gray700, gray800, gray900, gray920, gray950


# Alpha Variants

Colors with varying transparency levels, useful for overlays and subtle effects.

@docs whiteAlpha100Alpha200
@docs blackAlpha100Alpha200


# Helpers


# Debug

@docs viewColorPalette


# Usage Guidelines

  - 100-200: Light backgrounds, subtle fills
  - 300-400: Secondary backgrounds, separators
  - 500: Primary brand colors, system colors
  - 600-700: Text, active states
  - 800-900: High contrast text, headers

Common semantic uses:

  - blue: Primary actions, links (matches macOS accent color)
  - green: Success states, confirmations
  - amber: Warnings, important notifications
  - red: Error states, destructive actions
  - teal: Information, help content
  - gray: Text, borders, backgrounds, UI chrome

-}

import Color exposing (Color, rgba)


{-| So that the user oif this package doesn't need to import the `Color` package
-}
type alias Color =
    Color.Color



-- Base colors (500 variants)
-- White alpha variants


whiteAlpha100 : Color
whiteAlpha100 =
    rgba 1.0 1.0 1.0 0.04



-- Black alpha variants
-- Blue variants (macOS system blue inspired)


blue300 : Color
blue300 =
    rgba 0.54 0.71 0.94 1


blue500 : Color
blue500 =
    rgba 0.0 0.48 1.0 1


blue700 : Color
blue700 =
    rgba 0.0 0.2 1.0 1


blueDark : Color
blueDark =
    rgba 0.0 0.0 0.3 1


blueLight : Color
blueLight =
    rgba 0.95 0.95 1.0 1


blueTextLight =
    rgba 0.114 0.306 0.847 1



-- #1D4ED8


blueTextDark =
    rgba 0.376 0.647 0.98 1



-- #60A5FA
-- macOS accent blue
-- Green variants (macOS system green inspired)
-- macOS system green
-- Amber variants (macOS warning color inspired)
-- This is #FFC900
-- Red variants (unchanged)
-- Indigo variants (professional accent color)


indigo200 : Color
indigo200 =
    rgba 0.82 0.84 0.93 1


indigo500 : Color
indigo500 =
    rgba 0.35 0.38 0.67 1


indigo900 : Color
indigo900 =
    rgba 0.19 0.18 0.51 1


transparentIndigo500 : Color
transparentIndigo500 =
    rgba 0.35 0.38 0.67 0.3



-- Professional indigo


indigo600 : Color
indigo600 =
    rgba 0.29 0.31 0.58 1


indigo950 : Color
indigo950 =
    rgba 0.12 0.11 0.29 1


midnightIndigo : Color
midnightIndigo =
    rgba 0.06 0.04 0.18 1



-- Teal variants (information/help color)
-- Professional teal
-- Gray variants


gray100 : Color
gray100 =
    rgba 0.96 0.96 0.96 1


gray200 : Color
gray200 =
    rgba 0.89 0.89 0.89 1


gray300 : Color
gray300 =
    rgba 0.82 0.82 0.82 1


gray400 : Color
gray400 =
    rgba 0.65 0.65 0.65 1


gray600 : Color
gray600 =
    rgba 0.4 0.42 0.44 1


gray700 : Color
gray700 =
    rgba 0.33 0.35 0.37 1


gray800 : Color
gray800 =
    rgba 0.26 0.28 0.3 1


gray900 : Color
gray900 =
    rgba 0.19 0.21 0.23 1


gray920 : Color
gray920 =
    rgba 0.15 0.17 0.19 1


gray950 : Color
gray950 =
    rgba 0.09 0.11 0.13 1

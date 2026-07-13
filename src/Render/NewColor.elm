module Render.NewColor exposing
    ( Color
    , blue300
    , indigo200, indigo500
    , gray200, gray300, gray400, gray700, gray800, gray900, gray950
    , blue700, blueDark
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
@docs indigo200, indigo500
@docs gray200, gray300, gray400, gray700, gray800, gray900, gray950


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
-- Black alpha variants
-- Blue variants (macOS system blue inspired)


blue300 : Color
blue300 =
    rgba 0.54 0.71 0.94 1


blue700 : Color
blue700 =
    rgba 0.0 0.2 1.0 1


blueDark : Color
blueDark =
    rgba 0.0 0.0 0.3 1



-- #1D4ED8
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



-- Professional indigo
-- Teal variants (information/help color)
-- Professional teal
-- Gray variants


gray200 : Color
gray200 =
    rgba 0.89 0.89 0.89 1


gray300 : Color
gray300 =
    rgba 0.82 0.82 0.82 1


gray400 : Color
gray400 =
    rgba 0.65 0.65 0.65 1


gray700 : Color
gray700 =
    rgba 0.33 0.35 0.37 1


gray800 : Color
gray800 =
    rgba 0.26 0.28 0.3 1


gray900 : Color
gray900 =
    rgba 0.19 0.21 0.23 1


gray950 : Color
gray950 =
    rgba 0.09 0.11 0.13 1

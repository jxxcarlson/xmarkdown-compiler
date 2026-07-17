module Render.Theme exposing
    ( RenderSettings
    , ThemedStyles
    , darkTheme
    , lightTheme
    , makeSettings
    , scaleFont
    , themedColor
    )

{-| Light and dark theming for the XMarkdown renderer.

The compiler turns `CompilerParameters` into a [`RenderSettings`](#RenderSettings)
record with [`makeSettings`](#makeSettings), and the `Render.*` modules read
their sizes and colors from it. Applications that embed the editor (see the
`DemoTOC+Sync` example) additionally read the raw [`ThemedStyles`](#ThemedStyles)
palettes — [`lightTheme`](#lightTheme) / [`darkTheme`](#darkTheme) — and the
[`themedColor`](#themedColor) helper to keep their own chrome in step with the
document's current theme.


# Render settings

The fully-resolved bundle of sizes and colors handed to every renderer.

@docs RenderSettings, makeSettings, scaleFont


# Theme palettes

`ThemedStyles` is a raw color palette; `lightTheme` and `darkTheme` are the two
built-in instances, and `themedColor` looks up one field for a given theme,
returning a CSS color string.

@docs ThemedStyles, lightTheme, darkTheme, themedColor

-}

import Color
import Render.NewColor exposing (..)
import XMarkdown.Types exposing (CompilerParameters, Theme(..))


{-| Everything a renderer needs to lay out and color a document: sizes
(`width`, `fontSize`, `titleSize`, spacing, margins), the resolved theme
colors (`textColor`, `backgroundColor`, `linkColor`, …), and the current
selection/`theme`. Build one with [`makeSettings`](#makeSettings).
-}
type alias RenderSettings =
    { interBlockSpacing : Float
    , selectedId : String -- the element with this id will be highlighted
    , display : Display
    , selectedSlug : Maybe String -- is this necessary?
    , showErrorMessages : Bool
    , showTOC : Bool -- is this necessary?
    , titleSize : Int
    , fontSize : Int
    , width : Int
    , listSpacing : Int
    , backgroundColor : Color
    , redColor : Color
    , textColor : Color
    , codeColor : Color
    , linkColor : Color
    , highlight : Color
    , codeBackground : Color
    , theme : Theme
    , margins : Int
    , leftIndentation : Int
    , numberToLevel : Int
    }


{-| A raw color palette for one theme. Each field is an
[`avh4/elm-color`](https://package.elm-lang.org/packages/avh4/elm-color/latest/)
`Color`. See [`lightTheme`](#lightTheme) and [`darkTheme`](#darkTheme) for the
built-in instances, and [`themedColor`](#themedColor) to read a field as a CSS
string.
-}
type alias ThemedStyles =
    { background : Color
    , text : Color
    , codeBackground : Color
    , codeText : Color
    , offsetBackground : Color
    , offsetText : Color
    , link : Color
    , highlight : Color
    , border : Color
    , indentGuide : Color
    }


getThemedColor : (ThemedStyles -> Color) -> Theme -> Color
getThemedColor keyAccess theme =
    keyAccess
        (case theme of
            Dark ->
                darkTheme

            Light ->
                lightTheme
        )


{-| Look up one palette field for a theme and render it as a CSS color string
(`rgb(...)` or `rgba(...)`). Pass a `ThemedStyles` field accessor:

    themedColor .background model.theme --> "rgb(230, 230, 230)"

-}
themedColor : (ThemedStyles -> Color) -> Theme -> String
themedColor keyAccess theme =
    let
        color =
            keyAccess
                (case theme of
                    Dark ->
                        darkTheme

                    Light ->
                        lightTheme
                )
    in
    colorToRgbString color


colorToRgbString : Color -> String
colorToRgbString color =
    let
        { red, green, blue, alpha } =
            Color.toRgba color
    in
    if alpha < 1.0 then
        "rgba(" ++ String.fromInt (round (red * 255)) ++ ", " ++ String.fromInt (round (green * 255)) ++ ", " ++ String.fromInt (round (blue * 255)) ++ ", " ++ String.fromFloat alpha ++ ")"

    else
        "rgb(" ++ String.fromInt (round (red * 255)) ++ ", " ++ String.fromInt (round (green * 255)) ++ ", " ++ String.fromInt (round (blue * 255)) ++ ")"


{-| A light theme with a white background and dark text.
-}
lightTheme : ThemedStyles
lightTheme =
    { background = Color.rgba 0.9 0.9 0.9 1.0
    , text = gray950
    , codeBackground = Color.rgba 0.9 0.9 0.94 1
    , codeText = blueDark
    , offsetBackground = Color.rgb 1 1 1 --indigo300 |> Render.NewColor.setOpacity 0.25
    , offsetText = gray950
    , link = blue700 --blue500
    , highlight = indigo200
    , border = gray300
    , indentGuide = Color.rgba 0 0 0 0.15
    }


{-| A dark theme with a near-black background and light text.
-}
darkTheme : ThemedStyles
darkTheme =
    { background = gray900
    , text = gray200
    , codeBackground = gray800
    , codeText = Color.lightBlue
    , offsetBackground = gray900
    , offsetText = gray400
    , link = blue300
    , highlight = indigo500
    , border = gray700
    , indentGuide = Color.rgba 1 1 1 0.15
    }


{-| -}
type Display
    = DefaultDisplay


{-| The body size that the hardcoded element sizes were authored against
(elm-ui's default font size). Element sizes scale as
`fontSize * designSize / referenceFontSize`, so `fontSize == referenceFontSize`
reproduces the original appearance.
-}
referenceFontSize : Float
referenceFontSize =
    20


{-| Scale a design-time font size by the document's `fontSize`, preserving the
proportion the design size had to the reference body size. Use this in place of
a hardcoded `Font.size n` so all text scales with `settings.fontSize`.
-}
scaleFont : RenderSettings -> Int -> Int
scaleFont settings designSize =
    round (toFloat settings.fontSize * toFloat designSize / referenceFontSize)


{-| Resolve a `CompilerParameters` into a [`RenderSettings`](#RenderSettings):
scale the font/title sizes, parse the highlight color (falling back to the
theme), and pull the theme's colors for the chosen `theme`.
-}
makeSettings : CompilerParameters -> RenderSettings
makeSettings params =
    let
        titleSize =
            round (toFloat params.fontSize * 32 / referenceFontSize)

        -- Use parameterized highlight color, falling back to theme if parsing fails
        highlightColor =
            stringToColor params.highlightColor
                |> Maybe.withDefault (getThemedColor .highlight params.theme)
    in
    { width = round (params.scale * toFloat params.windowWidth)
    , titleSize = titleSize
    , fontSize = params.fontSize
    , interBlockSpacing = params.interBlockSpacing
    , listSpacing = 14
    , display = DefaultDisplay
    , showTOC = True
    , showErrorMessages = False
    , selectedId = params.selectedId
    , selectedSlug = params.selectedSlug
    , backgroundColor = getThemedColor .background params.theme
    , textColor = getThemedColor .text params.theme
    , codeColor = getThemedColor .codeText params.theme
    , linkColor = getThemedColor .link params.theme
    , highlight = highlightColor
    , codeBackground = getThemedColor .codeBackground params.theme
    , margins = 24
    , leftIndentation = 18
    , redColor = Color.rgb 0.7 0 0
    , theme = params.theme
    , numberToLevel = params.numberToLevel
    }


{-| Parse CSS rgba color string to Color.
Supports formats like "rgba(200, 200, 255, 0.4)" and "rgb(200, 200, 255)"
-}
stringToColor : String -> Maybe Color
stringToColor colorStr =
    if String.startsWith "rgba(" colorStr then
        colorStr
            |> String.dropLeft 5
            |> String.dropRight 1
            |> String.split ","
            |> List.map String.trim
            |> (\parts ->
                    case parts of
                        [ r, g, b, a ] ->
                            Maybe.map4 Color.rgba
                                (String.toFloat r |> Maybe.map (\x -> x / 255))
                                (String.toFloat g |> Maybe.map (\x -> x / 255))
                                (String.toFloat b |> Maybe.map (\x -> x / 255))
                                (String.toFloat a)

                        _ ->
                            Nothing
               )

    else if String.startsWith "rgb(" colorStr then
        colorStr
            |> String.dropLeft 4
            |> String.dropRight 1
            |> String.split ","
            |> List.map String.trim
            |> (\parts ->
                    case parts of
                        [ r, g, b ] ->
                            Maybe.map3 Color.rgb
                                (String.toFloat r |> Maybe.map (\x -> x / 255))
                                (String.toFloat g |> Maybe.map (\x -> x / 255))
                                (String.toFloat b |> Maybe.map (\x -> x / 255))

                        _ ->
                            Nothing
               )

    else
        Nothing

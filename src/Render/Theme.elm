module Render.Theme exposing
    ( ActualTheme
    , getColor
    , lightTheme, darkTheme
    , Display, RenderSettings, ThemedStyles, colorFromTheme, getThemedColorAsCssString, makeSettings, scaleFont
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
import Dict exposing (Dict)
import Render.NewColor exposing (..)
import XMarkdown.Types exposing (CompilerParameters, Theme(..))


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
getColor : Theme -> (ThemedStyles -> Color) -> Color
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
colorFromTheme : Theme -> (ThemedStyles -> Color) -> Color.Color
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



-------------
-- default selectedId width


{-| A record of information needed to render a document.
For instance, the`width`field defines the width of the
page in which the document is e
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
    , backgroundColor : Color
    , textColor : Color
    , codeColor : Color
    , linkColor : Color
    , highlight : Color
    , codeBackground : Color
    , margins : Int
    , leftIndentation : Int
    , windowWidthScale : Float
    , maxHeadingFontSize : Float
    , redColor : Color
    , theme : Theme
    , paddingTop : Int
    , paddingBottom : Int
    , numberToLevel : Int
    , properties : Dict String String
    }


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


getThemedColorAsCssString : (ThemedStyles -> Color) -> Theme -> String
getThemedColorAsCssString keyAccess theme =
    keyAccess
        (case theme of
            Dark ->
                darkTheme

            Light ->
                lightTheme
        )
        |> Color.toCssString


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
    }


darkTheme : ThemedStyles
darkTheme =
    { background = gray900
    , text = Color.rgba 0.835 0.847 0.882 1 -- gray100
    , codeBackground = gray800
    , codeText = Color.lightBlue --blueLight
    , offsetBackground = gray900
    , offsetText = Color.rgba 0.835 0.847 0.882 1 -- gray200 |> Render.NewColor.setOpacity 0.25
    , link = blue300
    , highlight = indigo500
    , border = gray700
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


{-| -}
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
    , windowWidthScale = 0.3
    , maxHeadingFontSize = (titleSize |> toFloat) * 0.72
    , redColor = Color.rgb 0.7 0 0
    , theme = params.theme
    , paddingTop = 0
    , paddingBottom = 0
    , numberToLevel = params.numberToLevel
    , properties = Dict.singleton "number-to-level" (String.fromInt params.numberToLevel)
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

module Render.Settings exposing
    ( RenderSettings
    , Display, ThemedStyles, darkTheme, defaultRenderSettings, getThemedElementColor, lightTheme, scaleFont, toElementColor, unrollTheme
    )

{-| The Settings record holds information needed to render a
parsed document. For example, the renderer needs to
know the width of the window in which the document
is to be displayed. This is given by the `.width` field.

@docs RenderSettings, default

-}

import Color
import Dict exposing (Dict)
import Element
import Element.Background as BackgroundColor
import Element.Font as Font
import Render.NewColor exposing (..)
import XMarkdown.Types exposing (CompilerParameters, Theme(..))



-- default selectedId width


{-| A record of information needed to render a document.
For instance, the`width`field defines the width of the
page in which the document is e
-}
type alias RenderSettings =
    { interBlockSpacing : Float
    , selectedId : String -- the element with this id will be highlighted
    , display : Display
    , longEquationLimit : Float
    , selectedSlug : Maybe String -- is this necessary?
    , showErrorMessages : Bool
    , showTOC : Bool -- is this necessary?
    , titleSize : Int
    , fontSize : Int
    , width : Int
    , backgroundColor : Element.Color
    , textColor : Element.Color
    , codeColor : Element.Color
    , linkColor : Element.Color
    , highlight : Element.Color
    , codeBackground : Element.Color
    , titlePrefix : String
    , isStandaloneDocument : Bool
    , leftIndent : Int
    , leftIndentation : Int
    , leftRightIndentation : Int
    , wideLeftIndentation : Int
    , windowWidthScale : Float
    , maxHeadingFontSize : Float
    , redColor : Element.Color
    , topMarginForChildren : Int
    , data : Dict String String
    , theme : Theme
    , paddingTop : Int
    , paddingBottom : Int
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


getThemedElementColor : (ThemedStyles -> Color) -> Theme -> Element.Color
getThemedElementColor keyAccess theme =
    toElementColor (getThemedColor keyAccess theme)


{-| Unrolls the theme into a list of Element styles.
-}
unrollTheme : Theme -> List (Element.Attr decorative msg)
unrollTheme theme =
    [ BackgroundColor.color (getThemedElementColor .background theme)
    , Font.color (getThemedElementColor .text theme)
    ]


toElementColor : Color -> Element.Color
toElementColor color =
    let
        c =
            Color.toRgba color
    in
    Element.rgba c.red c.green c.blue c.alpha


{-| A light theme with a white background and dark text.
-}
lightTheme : ThemedStyles
lightTheme =
    { background = Color.rgba 1 1 1 1
    , text = gray950
    , codeBackground = Color.rgba 0.90 0.90 0.94 1
    , codeText = gray900
    , offsetBackground = Color.rgb 1 1 1 --indigo300 |> Render.NewColor.setOpacity 0.25
    , offsetText = gray950
    , link = blue500
    , highlight = indigo200
    , border = gray300
    }


darkTheme : ThemedStyles
darkTheme =
    { background = gray900
    , text = Color.rgba 0.835 0.847 0.882 1 -- gray100
    , codeBackground = Color.rgba 0.35 0.37 0.42 1
    , codeText = gray100
    , offsetBackground = gray900
    , offsetText = Color.rgba 0.835 0.847 0.882 1 -- gray200 |> Render.NewColor.setOpacity 0.25

    --, offsetText = teal600 |> Render.NewColor.setOpacity 0.25
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
defaultRenderSettings : CompilerParameters -> RenderSettings
defaultRenderSettings params =
    makeSettings params


{-| -}
makeSettings : CompilerParameters -> RenderSettings
makeSettings params =
    let
        titleSize =
            round (toFloat params.fontSize * 32 / referenceFontSize)

        -- Use parameterized highlight color, falling back to theme if parsing fails
        highlightColor =
            stringToColor params.highlightColor
                |> Maybe.withDefault (getThemedElementColor .highlight params.theme)
    in
    { width = round (params.scale * toFloat params.windowWidth)
    , titleSize = titleSize
    , fontSize = params.fontSize
    , interBlockSpacing = params.interBlockSpacing
    , display = DefaultDisplay
    , longEquationLimit = 1 * (params.windowWidth |> toFloat)
    , showTOC = True
    , showErrorMessages = False
    , selectedId = params.selectedId
    , selectedSlug = params.selectedSlug
    , backgroundColor = getThemedElementColor .background params.theme
    , textColor = getThemedElementColor .text params.theme
    , codeColor = getThemedElementColor .codeText params.theme
    , linkColor = getThemedElementColor .link params.theme
    , highlight = highlightColor
    , codeBackground = getThemedElementColor .codeBackground params.theme
    , titlePrefix = ""
    , isStandaloneDocument = False
    , leftIndent = 0
    , leftIndentation = 18
    , leftRightIndentation = 18
    , wideLeftIndentation = 54
    , windowWidthScale = 0.3
    , maxHeadingFontSize = (titleSize |> toFloat) * 0.72
    , redColor = Element.rgb 0.7 0 0
    , topMarginForChildren = 6
    , data = params.data
    , theme = params.theme
    , paddingTop = 0
    , paddingBottom = 0
    , properties = Dict.singleton "number-to-level" (String.fromInt params.numberToLevel)
    }


{-| Parse CSS rgba color string to Element.Color.
Supports formats like "rgba(200, 200, 255, 0.4)" and "rgb(200, 200, 255)"
-}
stringToColor : String -> Maybe Element.Color
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
                            Maybe.map4 Element.rgba
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
                            Maybe.map3 Element.rgb
                                (String.toFloat r |> Maybe.map (\x -> x / 255))
                                (String.toFloat g |> Maybe.map (\x -> x / 255))
                                (String.toFloat b |> Maybe.map (\x -> x / 255))

                        _ ->
                            Nothing
               )

    else
        Nothing

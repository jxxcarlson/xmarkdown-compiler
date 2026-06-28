module Main exposing (main)

{-| A minimal demo: click a button, pick a `.md` file, and the XMarkdown
(SMarkdown) compiler renders it to the screen.
-}

import Browser
import Browser.Events
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import File exposing (File)
import File.Select as Select
import Html exposing (Html)
import Html.Attributes
import XMarkdown.API
import XMarkdown.Msg exposing (MarkupMsg)
import XMarkdown.Types exposing (Filter(..), defaultCompilerParameters)
import Task


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


subscriptions : Model -> Sub Msg
subscriptions _ =
    Browser.Events.onResize GotNewWindowDimensions


type alias Flags =
    { window : { windowWidth : Int, windowHeight : Int } }


type alias Model =
    { sourceText : String
    , fileName : Maybe String
    , count : Int
    , windowWidth : Int
    , windowHeight : Int
    , selectId : String
    }


type Msg
    = NoOp
    | MarkdownRequested
    | MarkdownSelected File
    | MarkdownLoaded String String
    | Render MarkupMsg
    | GotNewWindowDimensions Int Int


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { sourceText = "Click **Open .md file…** to load and render a document."
      , fileName = Nothing
      , count = 1
      , windowWidth = flags.window.windowWidth
      , windowHeight = flags.window.windowHeight
      , selectId = "@InitID"
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        GotNewWindowDimensions width height ->
            ( { model | windowWidth = width, windowHeight = height }, Cmd.none )

        MarkdownRequested ->
            ( model, Select.file [ "text/markdown", "text/x-markdown", "text/plain", ".md" ] MarkdownSelected )

        MarkdownSelected file ->
            ( model, Task.perform (MarkdownLoaded (File.name file)) (File.toString file) )

        MarkdownLoaded name content ->
            ( { model
                | sourceText = content
                , fileName = Just name
                , count = model.count + 1
              }
            , Cmd.none
            )

        Render markupMsg ->
            case markupMsg of
                XMarkdown.Msg.SelectId id ->
                    ( { model | selectId = id }, Cmd.none )

                _ ->
                    ( model, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    layoutWith { options = [ Element.focusStyle noFocus ] }
        [ bgGray 0.4, Font.size 16 ]
        (mainColumn model)


mainColumn : Model -> Element Msg
mainColumn model =
    column
        [ centerX
        , spacing 16
        , paddingXY 20 20
        , width (px (panelWidth model + 2 * xPadding))
        , height (px model.windowHeight)
        ]
        [ header model
        , displayRenderedText model |> Element.map Render
        ]


header : Model -> Element Msg
header model =
    row [ spacing 20, width fill ]
        [ openButton
        , el [ Font.color (rgb 1 1 1), Font.size 14, centerY ]
            (text (model.fileName |> Maybe.map (\n -> "Loaded: " ++ n) |> Maybe.withDefault "No file loaded"))
        ]


openButton : Element Msg
openButton =
    Input.button
        [ Background.color (rgb255 20 20 20)
        , Font.color (rgb 1 1 1)
        , Font.size 14
        , paddingXY 12 10
        , Border.rounded 4
        ]
        { onPress = Just MarkdownRequested
        , label = text "Open .md file…"
        }


displayRenderedText : Model -> Element MarkupMsg
displayRenderedText model =
    column
        [ spacing 4
        , Background.color (rgb 1.0 1.0 1.0)
        , width (px (panelWidth model))
        , height (px (panelHeight model))
        , paddingXY xPadding 24
        , htmlId "rendered-text"
        , scrollbarY
        ]
        (XMarkdown.API.compileSimple
            { defaultCompilerParameters
                | filter = NoFilter
                , docWidth = panelWidth model - 2 * xPadding
                , editCount = model.count
                , selectedId = model.selectId
                , idsOfOpenNodes = []
            }
            model.sourceText
        )



-- GEOMETRY


xPadding : Int
xPadding =
    24


panelWidth : Model -> Int
panelWidth model =
    min 800 (model.windowWidth - 60)


panelHeight : Model -> Int
panelHeight model =
    model.windowHeight - 120



-- HELPERS


noFocus : Element.FocusStyle
noFocus =
    { borderColor = Nothing, backgroundColor = Nothing, shadow = Nothing }


htmlId : String -> Attribute msg
htmlId str =
    Element.htmlAttribute (Html.Attributes.id str)


bgGray : Float -> Attr decorative msg
bgGray g =
    Background.color (rgb g g g)

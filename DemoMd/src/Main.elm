module Main exposing (main)

{-| A minimal demo: click a button, pick a `.md` file, and the XMarkdown
(SMarkdown) compiler renders it to the screen.
-}

import Browser
import Browser.Events
import File exposing (File)
import File.Select as Select
import Html exposing (Html, button, div, text)
import Html.Attributes exposing (id, style)
import Html.Events exposing (onClick)
import Task
import XMarkdown.API exposing (defaultCompilerParameters)
import XMarkdown.Types exposing (MarkupMsg(..))


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
                SelectId id ->
                    ( { model | selectId = id }, Cmd.none )

                _ ->
                    ( model, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    div
        [ style "display" "flex"
        , style "flex-direction" "column"
        , style "align-items" "center"
        , style "gap" "16px"
        , style "padding" "20px"
        , style "width" (String.fromInt (panelWidth model + 2 * xPadding) ++ "px")
        , style "height" (String.fromInt model.windowHeight ++ "px")
        , style "background-color" "rgba(102, 102, 102, 1)"
        , style "font-size" "16px"
        ]
        [ header model
        , Html.map Render (displayRenderedText model)
        ]


header : Model -> Html Msg
header model =
    div
        [ style "display" "flex"
        , style "gap" "20px"
        , style "width" "100%"
        ]
        [ openButton
        , div
            [ style "color" "rgb(255, 255, 255)"
            , style "font-size" "14px"
            , style "display" "flex"
            , style "align-items" "center"
            ]
            [ text (model.fileName |> Maybe.map (\n -> "Loaded: " ++ n) |> Maybe.withDefault "No file loaded")
            ]
        ]


openButton : Html Msg
openButton =
    button
        [ onClick MarkdownRequested
        , style "background-color" "rgb(20, 20, 20)"
        , style "color" "rgb(255, 255, 255)"
        , style "font-size" "14px"
        , style "padding" "10px 12px"
        , style "border-radius" "4px"
        , style "border" "1px solid #444"
        , style "cursor" "pointer"
        ]
        [ text "Open .md file…"
        ]


displayRenderedText : Model -> Html MarkupMsg
displayRenderedText model =
    div
        [ style "display" "flex"
        , style "flex-direction" "column"
        , style "gap" "4px"
        , style "background-color" "rgb(255, 255, 255)"
        , style "width" (String.fromInt (panelWidth model) ++ "px")
        , style "height" (String.fromInt (panelHeight model) ++ "px")
        , style "padding" (String.fromInt xPadding ++ "px 24px")
        , id "rendered-text"
        , style "overflow-y" "auto"
        ]
        (XMarkdown.API.compileSimple
            { defaultCompilerParameters
                | docWidth = panelWidth model - 2 * xPadding
                , editCount = model.count
                , selectedId = model.selectId
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


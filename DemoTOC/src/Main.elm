module Main exposing (main)

{-| A minimal demo: click a button, pick a `.md` file, and the XMarkdown
(SMarkdown) compiler renders it to the screen.
-}

import Browser
import Browser.Dom
import Browser.Events
import Data.Example exposing (exampleMarkdown)
import File exposing (File)
import File.Select as Select
import Html exposing (Html, button, div, text)
import Html.Attributes exposing (id, style)
import Html.Events exposing (onClick)
import Task
import XMarkdown.API exposing (compileOutput, defaultCompilerParameters, viewBodyOnly, viewTOC)
import XMarkdown.Types exposing (CompilerOutput, MarkupMsg(..))


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
    ( { sourceText = exampleMarkdown
      , fileName = Just "example.md"
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
                    ( { model | selectId = id }, scrollToElement id )

                _ ->
                    ( model, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    let
        compilerOutput =
            compileOutput defaultCompilerParameters model.sourceText

        tocElements =
            viewTOC compilerOutput

        shouldShowToc =
            not (List.isEmpty tocElements)
    in
    div
        [ style "display" "flex"
        , style "justify-content" "center"
        , style "height" "100%"
        , style "width" "100%"
        , style "background-color" "rgba(22, 22, 22, 1)"
        ]
        [ div
            [ style "display" "flex"
            , style "flex-direction" "column"
            , style "gap" "16px"
            , style "padding" "20px"
            , style "width"
                (String.fromInt
                    (if shouldShowToc then
                        panelWidth model + 250 + 2 * xPadding

                     else
                        panelWidth model + 2 * xPadding
                    )
                    ++ "px"
                )
            , style "height" (String.fromInt model.windowHeight ++ "px")
            , style "background-color" "rgba(102, 102, 102, 1)"
            , style "font-size" "16px"
            , style "overflow" "hidden"
            ]
            [ header model
            , div
                [ style "display" "flex"
                , style "gap" "16px"
                , style "flex" "1"
                , style "min-height" "0"
                ]
                ([ Html.map Render (displayRenderedText model compilerOutput)
                 ]
                    ++ (if shouldShowToc then
                            [ Html.map Render (displayTOC tocElements) ]

                        else
                            []
                       )
                )
            ]
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


displayRenderedText : Model -> XMarkdown.Types.CompilerOutput -> Html MarkupMsg
displayRenderedText model compilerOutput =
    div
        [ style "display" "flex"
        , style "flex-direction" "column"
        , style "gap" "4px"
        , style "background-color" "rgb(255, 255, 255)"
        , style "flex" "1"
        , style "min-height" "0"
        , style "padding" (String.fromInt xPadding ++ "px 24px")
        , id "rendered-text"
        , style "overflow-y" "auto"
        ]
        (viewBodyOnly (panelWidth model) compilerOutput)


displayTOC : List (Html MarkupMsg) -> Html MarkupMsg
displayTOC tocElements =
    div
        [ style "display" "flex"
        , style "flex-direction" "column"
        , style "background-color" "rgb(245, 245, 245)"
        , style "width" "200px"
        , style "min-height" "0"
        , style "padding" "12px 16px"
        , style "border-left" "1px solid #ddd"
        , style "overflow-y" "auto"
        , style "font-size" "13px"
        ]
        tocElements


scrollToElement : String -> Cmd Msg
scrollToElement elementId =
    Browser.Dom.getElement elementId
        |> Task.andThen
            (\targetElem ->
                Browser.Dom.getElement "rendered-text"
                    |> Task.map (\containerElem -> ( targetElem, containerElem ))
            )
        |> Task.andThen
            (\( targetElem, containerElem ) ->
                Browser.Dom.getViewportOf "rendered-text"
                    |> Task.map (\viewport -> ( targetElem, containerElem, viewport ))
            )
        |> Task.andThen
            (\( targetElem, containerElem, viewport ) ->
                let
                    targetY =
                        targetElem.element.y

                    containerY =
                        containerElem.element.y

                    currentScroll =
                        viewport.viewport.y

                    positionInContent =
                        targetY - containerY + currentScroll

                    targetScroll =
                        max 0 (positionInContent - 50)
                in
                Browser.Dom.setViewportOf "rendered-text" 0 targetScroll
            )
        |> Task.attempt (\_ -> NoOp)



-- GEOMETRY


xPadding : Int
xPadding =
    24


panelWidth : Model -> Int
panelWidth model =
    min 500 (model.windowWidth - 60)


panelHeight : Model -> Int
panelHeight model =
    model.windowHeight - 120

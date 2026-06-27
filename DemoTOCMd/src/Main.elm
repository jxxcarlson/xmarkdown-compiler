module Main exposing (main)

import Browser
import Browser.Dom
import Browser.Events
import Data.XMarkdown
import Element
import File exposing (File)
import File.Download
import File.Select
import Html exposing (Html, button, div, text)
import Html.Attributes exposing (class, id, style)
import Html.Events
import List.Extra
import Scripta.Compiler
import Scripta.Editor
import Scripta.Msg exposing (MarkupMsg)
import Scripta.Sync
import Scripta.Types exposing (Filter(..), defaultCompilerParameters)
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


type alias Model =
    { initialText : String
    , sourceText : String
    , count : Int
    , windowWidth : Int
    , windowHeight : Int
    , selectId : String
    , idsOfOpenNodes : List String
    , syncHighlight : Maybe Scripta.Sync.SyncHighlight
    , tick : Int
    , fileName : String
    }


type Msg
    = NoOp
    | InputText String
    | Render MarkupMsg
    | GotNewWindowDimensions Int Int
    | OpenFileRequested
    | FileSelected File
    | FileLoaded String
    | SaveFileRequested


type alias Flags =
    { window : { windowWidth : Int, windowHeight : Int } }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { initialText = Data.XMarkdown.text
      , sourceText = Data.XMarkdown.text
      , count = 0
      , windowWidth = flags.window.windowWidth
      , windowHeight = flags.window.windowHeight
      , selectId = "@InitID"
      , idsOfOpenNodes = []
      , syncHighlight = Nothing
      , tick = 0
      , fileName = "untitled.md"
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

        InputText str ->
            ( { model | sourceText = str, count = model.count + 1 }, Cmd.none )

        OpenFileRequested ->
            ( model, File.Select.file [ "text/markdown", "text/plain", ".md" ] FileSelected )

        FileSelected file ->
            ( { model | fileName = File.name file }, Task.perform FileLoaded (File.toString file) )

        FileLoaded content ->
            -- Changing initialText re-pushes the editor's `load` attribute, so
            -- editor.js replaces the document with the opened file's contents.
            ( { model
                | initialText = content
                , sourceText = content
                , count = model.count + 1
                , syncHighlight = Nothing
              }
            , Cmd.none
            )

        SaveFileRequested ->
            ( model, File.Download.string model.fileName "text/markdown" model.sourceText )

        Render msg_ ->
            case Scripta.Sync.fromMsg (model.tick + 1) msg_ of
                Just h ->
                    ( { model | syncHighlight = Just h, tick = model.tick + 1 }, Cmd.none )

                Nothing ->
                    case msg_ of
                        Scripta.Msg.ToggleTOCNodeID nodeId ->
                            let
                                idsOfOpenNodes =
                                    if String.left 2 nodeId == "@-" then
                                        if List.member nodeId model.idsOfOpenNodes then
                                            List.Extra.remove nodeId model.idsOfOpenNodes

                                        else
                                            nodeId :: model.idsOfOpenNodes

                                    else
                                        model.idsOfOpenNodes
                            in
                            ( { model | idsOfOpenNodes = idsOfOpenNodes }, Cmd.none )

                        Scripta.Msg.SelectId selId ->
                            if selId == "title" then
                                ( { model | selectId = selId }, jumpToTopOf Scripta.Editor.renderedTextId )

                            else
                                ( { model | selectId = selId }, Cmd.none )

                        _ ->
                            ( model, Cmd.none )



-- GEOMETRY


type alias Geometry =
    { editorW : Int, renderedW : Int, tocW : Int, docWidth : Int }


geometry : Model -> Geometry
geometry model =
    let
        tocW =
            200

        gap =
            16

        pad =
            24

        avail =
            model.windowWidth - tocW - 4 * gap

        half =
            max 240 (avail // 2)
    in
    { editorW = half, renderedW = half, tocW = tocW, docWidth = half - 2 * pad }



-- VIEW


view : Model -> Html Msg
view model =
    let
        g =
            geometry model

        params =
            { defaultCompilerParameters
                | docWidth = g.docWidth
                , editCount = model.count
                , selectedId = "selectedId"
                , idsOfOpenNodes = model.idsOfOpenNodes
                , filter = NoFilter
            }

        compilerOutput : Scripta.Compiler.CompilerOutput
        compilerOutput =
            Scripta.Compiler.compile params (String.lines model.sourceText)
    in
    div [ class "app" ]
        [ div [ class "app-header" ]
            [ div [ class "toolbar" ]
                [ button [ class "toolbar-button", Html.Events.onClick OpenFileRequested ] [ text "Open File" ]
                , button [ class "toolbar-button", Html.Events.onClick SaveFileRequested ] [ text "Save File" ]
                ]
            , div [ class "app-title" ] [ text "XMarkdown TOC Demo" ]
            ]
        , div [ class "panels" ]
            [ div [ class "panel editor-panel", style "width" (px g.editorW) ]
                [ editorView model ]
            , div
                [ class "panel rendered-panel"
                , id Scripta.Editor.renderedTextId
                , style "width" (px g.renderedW)
                ]
                [ Html.map Render (renderPanel (round compilerOutput.interBlockSpacing) compilerOutput.body) ]
            , div [ class "panel toc-panel", style "width" (px g.tocW) ]
                [ Html.map Render (renderPanel 18 compilerOutput.toc) ]
            ]
        ]


editorView : Model -> Html Msg
editorView model =
    Scripta.Editor.view
        { source = model.initialText
        , onInput = InputText
        , highlight = model.syncHighlight
        , attrs = []
        }


{-| Bridge the compiler's still-elm-ui output into the html app.
-}
renderPanel : Int -> List (Element.Element MarkupMsg) -> Html MarkupMsg
renderPanel blockSpacing elements =
    Element.layout [ Element.width Element.fill ]
        (Element.column
            [ Element.spacing blockSpacing, Element.width Element.fill ]
            elements
        )


px : Int -> String
px n =
    String.fromInt n ++ "px"


jumpToTopOf : String -> Cmd Msg
jumpToTopOf elementId =
    Browser.Dom.getViewportOf elementId
        |> Task.andThen (\_ -> Browser.Dom.setViewportOf elementId 0 0)
        |> Task.attempt (\_ -> NoOp)

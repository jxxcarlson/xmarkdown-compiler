module Main exposing (main)

import Browser
import Browser.Dom
import Browser.Events
import Data.XMarkdown
import Element
import Html exposing (Html, div, text)
import Html.Attributes exposing (class, id, style)
import List.Extra
import ScriptaV2.Compiler
import ScriptaV2.Editor
import ScriptaV2.Language
import ScriptaV2.Msg exposing (MarkupMsg)
import ScriptaV2.Types exposing (Filter(..), defaultCompilerParameters)
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
    }


type Msg
    = NoOp
    | InputText String
    | Render MarkupMsg
    | GotNewWindowDimensions Int Int


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

        Render msg_ ->
            case msg_ of
                ScriptaV2.Msg.ToggleTOCNodeID nodeId ->
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

                ScriptaV2.Msg.SelectId selId ->
                    if selId == "title" then
                        ( { model | selectId = selId }, jumpToTopOf ScriptaV2.Editor.renderedTextId )

                    else
                        ( { model | selectId = selId }, Cmd.none )

                ScriptaV2.Msg.SendLineNumber _ ->
                    ( model, Cmd.none )

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
                | lang = ScriptaV2.Language.SMarkdownLang
                , docWidth = g.docWidth
                , editCount = model.count
                , selectedId = "selectedId"
                , idsOfOpenNodes = model.idsOfOpenNodes
                , filter = NoFilter
            }

        compilerOutput =
            ScriptaV2.Compiler.compile params (String.lines model.sourceText)
    in
    div [ class "app" ]
        [ div [ class "app-header" ] [ text "XMarkdown TOC Demo" ]
        , div [ class "panels" ]
            [ div [ class "panel editor-panel", style "width" (px g.editorW) ]
                [ editorView model ]
            , div
                [ class "panel rendered-panel"
                , id ScriptaV2.Editor.renderedTextId
                , style "width" (px g.renderedW)
                ]
                [ Html.map Render (renderPanel compilerOutput.body) ]
            , div [ class "panel toc-panel", style "width" (px g.tocW) ]
                [ Html.map Render (renderPanel compilerOutput.toc) ]
            ]
        ]


editorView : Model -> Html Msg
editorView model =
    ScriptaV2.Editor.view
        { source = model.initialText
        , onInput = InputText
        , attrs = []
        }


{-| Bridge the compiler's still-elm-ui output into the html app. -}
renderPanel : List (Element.Element MarkupMsg) -> Html MarkupMsg
renderPanel elements =
    Element.layout [ Element.width Element.fill ]
        (Element.column
            [ Element.spacing 12, Element.width Element.fill ]
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

module Main exposing (main)

import Browser
import Browser.Dom
import Browser.Events
import Data.XMarkdown
import Element exposing (..)
import Element.Background as Background
import Element.Font as Font
import Element.Input as Input
import Html exposing (Html)
import Html.Attributes
import List.Extra
import ScriptaV2.Compiler
import ScriptaV2.Language
import ScriptaV2.Msg exposing (MarkupMsg)
import ScriptaV2.Types exposing (Filter(..), defaultCompilerParameters)
import Task


main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    Browser.Events.onResize GotNewWindowDimensions


type alias Model =
    { sourceText : String
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
    ( { sourceText = Data.XMarkdown.text
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
            ( { model
                | sourceText = str
                , count = model.count + 1
              }
            , Cmd.none
            )

        Render msg_ ->
            case msg_ of
                ScriptaV2.Msg.ToggleTOCNodeID id ->
                    let
                        idsOfOpenNodes =
                            if String.left 2 id == "@-" then
                                if List.member id model.idsOfOpenNodes then
                                    List.Extra.remove id model.idsOfOpenNodes

                                else
                                    id :: model.idsOfOpenNodes

                            else
                                model.idsOfOpenNodes
                    in
                    ( { model | idsOfOpenNodes = idsOfOpenNodes }, Cmd.none )

                ScriptaV2.Msg.SelectId id ->
                    if id == "title" then
                        ( { model | selectId = id }, jumpToTopOf "rendered-text" )

                    else
                        ( { model | selectId = id }, Cmd.none )

                ScriptaV2.Msg.SendLineNumber line ->
                    ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )



--
-- VIEW
--


view : Model -> Html Msg
view model =
    layoutWith { options = [ Element.focusStyle noFocus ] }
        [ bgGray 0.2 ]
        (mainColumn model)


mainColumn : Model -> Element Msg
mainColumn model =
    let
        params =
            { defaultCompilerParameters
                | lang = ScriptaV2.Language.SMarkdownLang
                , docWidth = rhPanelWidth model - 3 * xPadding
                , editCount = model.count
                , selectedId = "selectedId"
                , idsOfOpenNodes = model.idsOfOpenNodes
                , filter = NoFilter
            }

        compilerOutput =
            ScriptaV2.Compiler.compile params (String.lines model.sourceText)
    in
    column mainColumnStyle
        [ column [ width (px <| appWidth model), height (px <| appHeight model), clipY ]
            [ title "XMarkdown TOC Demo"
            , row [ spacing margin.between, centerX, width (px <| model.windowWidth - 50 - margin.left - margin.right) ]
                [ inputText model
                , displayRenderedText model compilerOutput |> Element.map Render
                , displayToc model compilerOutput |> Element.map Render
                ]
            ]
        ]


noFocus : Element.FocusStyle
noFocus =
    { borderColor = Nothing
    , backgroundColor = Nothing
    , shadow = Nothing
    }


title : String -> Element msg
title str =
    row [ centerX, Font.bold, fontGray 0.9, paddingEach { left = 0, right = 0, top = 0, bottom = 12 } ] [ text str ]



-- VIEWS


displayRenderedText model compilerOutput =
    column [ spacing 8, Font.size 14 ]
        [ el [ fontGray 0.9 ] (text "Rendered Text")
        , column
            [ spacing 12
            , Background.color (Element.rgb 1.0 1.0 1.0)
            , width (px <| panelWidth model)
            , panelHeight model
            , paddingXY 16 32
            , htmlId "rendered-text"
            , scrollbarY
            ]
            compilerOutput.body
        ]


displayToc model compilerOutput =
    column [ spacing 8, Font.size 14 ]
        [ el [ fontGray 0.9 ] (text "Table of Contents")
        , column
            [ spacing 4
            , Background.color (Element.rgb 1.0 1.0 1.0)
            , width (px <| tocWidth)
            , panelHeight model
            , paddingXY 16 32
            , htmlId "toc"
            , scrollbarY
            ]
            compilerOutput.toc
        ]


htmlId str =
    Element.htmlAttribute (Html.Attributes.id str)


inputText : Model -> Element Msg
inputText model =
    Input.multiline [ width (px <| lhPanelWidth model), panelHeight model, Font.size 14 ]
        { onChange = InputText
        , text = model.sourceText
        , placeholder = Nothing
        , label = Input.labelAbove [ fontGray 0.9 ] <| el [] (text "Source text")
        , spellcheck = False
        }



-- GEOMETRY


appWidth : Model -> Int
appWidth model =
    model.windowWidth


appHeight : Model -> Int
appHeight model =
    model.windowHeight - headerHeight


panelWidth : Model -> Int
panelWidth model =
    (appWidth model - (margin.left + margin.right + margin.between)) // 2


lhPanelWidth : Model -> Int
lhPanelWidth model =
    panelWidth model - tocWidth


rhPanelWidth : Model -> Int
rhPanelWidth model =
    panelWidth model - 80


tocWidth =
    200


panelHeight : Model -> Attribute msg
panelHeight model =
    height (px <| appHeight model - margin.bottom - margin.top)


margin =
    { left = 20, right = 20, top = 20, bottom = 60, between = 20 }


xPadding =
    16


headerHeight =
    40



-- Helpers and Constants


fontGray g =
    Font.color (Element.rgb g g g)


bgGray g =
    Background.color (Element.rgb g g g)


mainColumnStyle =
    [ centerX
    , centerY
    , bgGray 0.4
    , paddingXY 20 20
    ]


jumpToTopOf : String -> Cmd Msg
jumpToTopOf id =
    Browser.Dom.getViewportOf id
        |> Task.andThen (\info -> Browser.Dom.setViewportOf id 0 0)
        |> Task.attempt (\_ -> NoOp)

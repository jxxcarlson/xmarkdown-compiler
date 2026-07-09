module Main exposing (main)

--import XMarkdown.Compiler

import Browser
import Browser.Dom
import Browser.Events
import Color
import Data.XMarkdown
import File exposing (File)
import File.Download
import File.Select
import Html exposing (Html, button, div, input, text)
import Html.Attributes exposing (class, id, placeholder, style, value)
import Html.Events
import List.Extra
import Ports
import Render.Theme exposing (ThemedStyles, darkTheme, lightTheme)
import Task
import XMarkdown.API exposing (defaultCompilerParameters, fromMsg)
import XMarkdown.Types exposing (CompilerParameters, MarkupMsg(..), SyncHighlight, Theme(..))


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
    Sub.batch
        [ Browser.Events.onResize GotNewWindowDimensions
        , Ports.lrSyncRequest LRSync
        ]


type alias Model =
    { initialText : String
    , sourceText : String
    , count : Int
    , windowWidth : Int
    , windowHeight : Int
    , selectId : String
    , syncHighlight : Maybe SyncHighlight
    , tick : Int
    , compilerParameters : CompilerParameters
    , currentTheme : Theme
    , theme : Theme
    , fileName : String
    , lrSyncMatches : List XMarkdown.API.BlockMatch
    , lrSyncIndex : Int
    , lrSyncText : String
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
    | NewFileRequested
    | FileNameChanged String
    | LRSync String
    | ToggleTheme


type alias Flags =
    { window : { windowWidth : Int, windowHeight : Int } }


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        params =
            { defaultCompilerParameters | numberToLevel = 0 }
    in
    ( { initialText = Data.XMarkdown.text
      , sourceText = Data.XMarkdown.text
      , count = 0
      , windowWidth = flags.window.windowWidth
      , windowHeight = flags.window.windowHeight
      , selectId = "@InitID"
      , syncHighlight = Nothing
      , theme = Light
      , currentTheme = Light
      , tick = 0
      , fileName = "untitled.md"
      , lrSyncMatches = []
      , lrSyncIndex = 0
      , lrSyncText = ""
      , compilerParameters = params
      }
    , Ports.setEditorHighlightColor params.highlightColor
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

        NewFileRequested ->
            ( { model
                | initialText = ""
                , sourceText = ""
                , count = model.count + 1
                , syncHighlight = Nothing
                , fileName = "untitled.md"
              }
            , Cmd.none
            )

        FileNameChanged newFileName ->
            ( { model | fileName = newFileName }, Cmd.none )

        ToggleTheme ->
            let
                newTheme =
                    case model.theme of
                        Light ->
                            Dark

                        Dark ->
                            Light

                params =
                    model.compilerParameters

                newParams =
                    { params | theme = newTheme }

                currentTheme =
                    case newTheme of
                        Light ->
                            lightTheme

                        Dark ->
                            darkTheme

                themeCmd =
                    Ports.setThemeColors
                        { fg = currentTheme.text |> Color.toCssString
                        , bg = currentTheme.background |> Color.toCssString
                        }
            in
            ( { model | theme = newTheme, compilerParameters = newParams }
            , themeCmd
            )

        LRSync searchText ->
            let
                params =
                    { defaultCompilerParameters
                        | docWidth = geometry model |> .docWidth
                        , editCount = model.count
                        , selectedId = "selectedId"
                        , interBlockSpacing = 0
                        , paddingAboveHeadings = 18

                        -- JCX -- , numberToLevel = 0
                    }

                matches =
                    XMarkdown.API.searchBlocksContainingText params (String.lines model.sourceText) searchText

                newIndex =
                    if searchText == model.lrSyncText && not (List.isEmpty matches) then
                        (model.lrSyncIndex + 1) |> modBy (List.length matches)

                    else
                        0

                currentMatch =
                    List.drop newIndex matches |> List.head
            in
            case currentMatch of
                Just match ->
                    let
                        -- selectId should be the line number (as string) for highlighting
                        -- but we need the full ID for scrolling
                        lineNumberStr =
                            String.fromInt match.lineNumber

                        -- Create CSS rule for highlighting this line number and all descendants
                        css =
                            "[data-line-number=\""
                                ++ lineNumberStr
                                ++ "\"] { background-color: "
                                ++ params.highlightColor
                                ++ " !important; }\n"
                                ++ "[data-line-number=\""
                                ++ lineNumberStr
                                ++ "\"] * { background-color: "
                                ++ params.highlightColor
                                ++ " !important; }"
                    in
                    ( { model | lrSyncMatches = matches, lrSyncIndex = newIndex, lrSyncText = searchText, selectId = lineNumberStr }
                    , Cmd.batch
                        [ jumpToTopOfWithLineNumber match.id match.lineNumber
                        , Ports.injectHighlightCSS css
                        ]
                    )

                Nothing ->
                    ( { model | lrSyncMatches = matches, lrSyncIndex = newIndex, lrSyncText = searchText }, Cmd.none )

        Render msg_ ->
            case fromMsg (model.tick + 1) msg_ of
                Just h ->
                    ( { model | syncHighlight = Just h, tick = model.tick + 1 }, Cmd.none )

                Nothing ->
                    case msg_ of
                        SelectId selId ->
                            let
                                lineNum =
                                    String.split "." selId |> List.head |> Maybe.withDefault "0" |> String.dropLeft 2 |> String.toInt |> Maybe.withDefault 0
                            in
                            ( { model | selectId = selId }, jumpToTopOfWithLineNumber selId lineNum )

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

        -- Customize compiler parameters here
        params =
            { defaultCompilerParameters
                | docWidth = g.docWidth -- width of rendered text in pixels
                , editCount = model.count -- incremented on each edit; rendered text won't update withoug this
                , selectedId = model.selectId -- id of rendered text on which user clicked
                , theme = model.theme -- Dark or Light
                , numberToLevel = 3 -- automatically number sections to level 3. Omit if you don't want sections numbered
            }

        compilerOutput : XMarkdown.Types.CompilerOutput
        compilerOutput =
            XMarkdown.API.compile params (String.lines model.sourceText)
    in
    div [ class "app" ]
        [ div [ class "app-header" ]
            [ div [ class "toolbar" ]
                [ button [ class "toolbar-button", Html.Events.onClick OpenFileRequested ] [ text "Open File" ]
                , button [ class "toolbar-button", Html.Events.onClick SaveFileRequested ] [ text "Save File" ]
                , button [ class "toolbar-button", Html.Events.onClick NewFileRequested ] [ text "New File" ]
                , input
                    [ id "fileName"
                    , style "margin-left" "8px"
                    , style "padding" "6px"
                    , style "border" "1px solid #ccc"
                    , style "border-radius" "4px"
                    , style "font-size" "14px"
                    , value model.fileName
                    , Html.Events.onInput FileNameChanged
                    , placeholder "File name..."
                    ]
                    []
                , button
                    [ class "toolbar-button theme-toggle"
                    , Html.Events.onClick ToggleTheme
                    , Html.Attributes.title
                        (case model.theme of
                            Light ->
                                "Switch to Dark Mode"

                            Dark ->
                                "Switch to Light Mode"
                        )
                    , Html.Attributes.style "background-color" "black"
                    , style "margin-left" "auto"
                    ]
                    [ text
                        (case model.theme of
                            Light ->
                                "🌙"

                            Dark ->
                                "☀️"
                        )
                    ]
                ]
            , div [ class "app-title" ] [ text "XMarkdown TOC Demo" ]
            ]
        , div [ class "panels" ]
            [ div [ class "panel editor-panel", style "width" (px g.editorW) ]
                [ editorView model ]
            , div
                [ class "panel rendered-panel"
                , id XMarkdown.API.renderedTextId
                , style "width" (px g.renderedW)
                , style "background-color" (Render.Theme.themedColor .background model.theme)
                ]
                [ -- Html.map Render (renderPanel (round compilerOutput.interBlockSpacing) compilerOutput.body)
                  Html.map Render (renderPanel model.compilerParameters compilerOutput.body)
                ]
            , div
                [ -- class "panel toc-panel"
                  style "width" (px g.tocW)
                , style "background" (Render.Theme.themedColor .background model.theme)
                ]
                [ Html.map Render (renderPanel model.compilerParameters compilerOutput.toc) ]
            ]
        ]



--renderPanel : Render.Theme.RenderSettings -> List (Html MarkupMsg) -> Html MarkupMsg
--renderPanel settings elements


editorView : Model -> Html Msg
editorView model =
    XMarkdown.API.editorView
        { source = model.initialText
        , onInput = InputText
        , highlight = model.syncHighlight
        , attrs = []
        }


{-| Render the compiler's Html output into the panel.
-}
renderPanel : XMarkdown.Types.CompilerParameters -> List (Html MarkupMsg) -> Html MarkupMsg
renderPanel params elements =
    let
        settings =
            Render.Theme.makeSettings params
    in
    Html.div
        [ Html.Attributes.style "display" "flex"
        , Html.Attributes.style "flex-direction" "column"
        , Html.Attributes.style "gap" (String.fromInt (round settings.interBlockSpacing) ++ "px")
        , Html.Attributes.style "width" "100%"
        , Html.Attributes.style "background-color" (Render.Theme.themedColor .background settings.theme)
        , Html.Attributes.style "color" (Render.Theme.themedColor .text settings.theme)
        ]
        elements



-- getThemedColorAsCssString : (ThemedStyles -> Color) -> Theme -> String


px : Int -> String
px n =
    String.fromInt n ++ "px"


jumpToTopOfWithLineNumber : String -> Int -> Cmd Msg
jumpToTopOfWithLineNumber elementId lineNumber =
    Browser.Dom.getElement elementId
        |> Task.andThen (\elem -> Browser.Dom.getViewportOf XMarkdown.API.renderedTextId
            |> Task.map (\viewport -> (elem, viewport)))
        |> Task.andThen (\(elem, viewport) ->
            let
                targetScroll =
                    max 0 (elem.element.y - 50)
            in
            Browser.Dom.setViewportOf XMarkdown.API.renderedTextId 0 targetScroll)
        |> Task.attempt (\_ -> NoOp)

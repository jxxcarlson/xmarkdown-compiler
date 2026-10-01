module Main exposing (main)

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
import Json.Decode as Decode
import Ports
import Render.Theme exposing (ThemedStyles, darkTheme, lightTheme)
import Task
import XMarkdown.API exposing (defaultCompilerParameters, fromMsgToSyncHighlight)
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
subscriptions model =
    Sub.batch
        [ Browser.Events.onResize GotNewWindowDimensions
        , Ports.lrSyncRequest LRSync
        , case model.dragging of
            Just _ ->
                Sub.batch
                    [ Browser.Events.onMouseMove (Decode.map DragMove (Decode.field "clientX" Decode.float))
                    , Browser.Events.onMouseUp (Decode.succeed StopDrag)
                    ]

            Nothing ->
                Sub.none
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
    , numberedSections : Bool
    , compilerParameters : CompilerParameters
    , currentTheme : Theme
    , theme : Theme
    , fileName : String
    , lrSyncMatches : List XMarkdown.API.BlockMatch
    , lrSyncIndex : Int
    , lrSyncText : String
    , editorOpen : Bool
    , editorWidth : Int
    , tocWidth : Int
    , dragging : Maybe Divider
    }


{-| The draggable dividers between the panels.
-}
type Divider
    = EditorDivider
    | TocDivider


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
    | ToggleNumberSections
    | ToggleEditor
    | StartDrag Divider
    | DragMove Float
    | StopDrag


type alias Flags =
    { window : { windowWidth : Int, windowHeight : Int } }


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        -- set initial compiler parameters here by
        -- modifying the defaultCompilerParameters, e.g.,
        -- params = { defaultCompilerParameters | numberToLevel = 3 }
        params =
            defaultCompilerParameters
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
      , numberedSections = False
      , compilerParameters = params
      , editorOpen = False
      , editorWidth = max minEditorW ((flags.window.windowWidth - initialTocW - 2 * pagePad - 2 * dividerW) // 2)
      , tocWidth = initialTocW
      , dragging = Nothing
      }
    , Ports.setEditorHighlightColor params.highlightColor
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        GotNewWindowDimensions width height ->
            ( clampWidths { model | windowWidth = width, windowHeight = height }, Cmd.none )

        StartDrag divider ->
            ( { model | dragging = Just divider }, Cmd.none )

        DragMove x ->
            case model.dragging of
                -- A drag only moves the panel on its side of the divider; the
                -- rendered panel absorbs the change, down to its minimum.
                Just EditorDivider ->
                    let
                        maxEditor =
                            max minEditorW (panelSpace model - model.tocWidth - minRenderedW)
                    in
                    ( { model | editorWidth = clamp minEditorW maxEditor (round x - pagePad - dividerW // 2) }, Cmd.none )

                Just TocDivider ->
                    let
                        editorW =
                            if model.editorOpen then
                                model.editorWidth

                            else
                                0

                        maxToc =
                            max minTocW (panelSpace model - editorW - minRenderedW)
                    in
                    ( { model | tocWidth = clamp minTocW maxToc (model.windowWidth - pagePad - dividerW // 2 - round x) }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        StopDrag ->
            ( { model | dragging = Nothing }, Cmd.none )

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
                , editorOpen = True
              }
            , Cmd.none
            )

        ToggleEditor ->
            ( clampWidths { model | editorOpen = not model.editorOpen }, Cmd.none )

        FileNameChanged newFileName ->
            ( { model | fileName = newFileName }, Cmd.none )

        ToggleNumberSections ->
            let
                oldCompilerParameters =
                    model.compilerParameters
            in
            case model.numberedSections of
                False ->
                    ( { model
                        | compilerParameters = { oldCompilerParameters | numberToLevel = 3 }
                        , numberedSections = True
                      }
                    , Cmd.none
                    )

                True ->
                    ( { model
                        | compilerParameters = { oldCompilerParameters | numberToLevel = 0 }
                        , numberedSections = False
                      }
                    , Cmd.none
                    )

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
                        , indentGuide = currentTheme.indentGuide |> Color.toCssString
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
                        , numberToLevel = 0
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
            case fromMsgToSyncHighlight (model.tick + 1) msg_ of
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


{-| Horizontal padding of the panel row (each side), and width of a divider.
-}
pagePad : Int
pagePad =
    16


dividerW : Int
dividerW =
    16


minEditorW : Int
minEditorW =
    200


minRenderedW : Int
minRenderedW =
    300


minTocW : Int
minTocW =
    120


initialTocW : Int
initialTocW =
    200


{-| Space available for the panels themselves: the window minus the row's
padding and the visible dividers.
-}
panelSpace : Model -> Int
panelSpace model =
    if model.editorOpen then
        model.windowWidth - 2 * pagePad - 2 * dividerW

    else
        model.windowWidth - 2 * pagePad - dividerW


{-| Keep the editor and TOC within their minimums while leaving the rendered
panel at least `minRenderedW`. The TOC yields first when space runs out.
-}
clampWidths : Model -> Model
clampWidths model =
    let
        editorW =
            if model.editorOpen then
                model.editorWidth

            else
                0

        maxToc =
            max minTocW (panelSpace model - editorW - minRenderedW)

        tocWidth =
            clamp minTocW maxToc model.tocWidth

        maxEditor =
            max minEditorW (panelSpace model - tocWidth - minRenderedW)
    in
    { model
        | tocWidth = tocWidth
        , editorWidth = clamp minEditorW maxEditor model.editorWidth
    }


geometry : Model -> Geometry
geometry model =
    let
        pad =
            24

        editorW =
            if model.editorOpen then
                model.editorWidth

            else
                0

        -- The rendered panel fills whatever the editor and TOC leave.
        renderedW =
            max minRenderedW (panelSpace model - editorW - model.tocWidth)
    in
    { editorW = editorW
    , renderedW = renderedW
    , tocW = model.tocWidth

    -- Cap the text column at a readable width; renderPanel centers it.
    , docWidth = min 800 (renderedW - 2 * pad)
    }



-- VIEW


view : Model -> Html Msg
view model =
    let
        g =
            geometry model

        -- Base the compiler parameters on the model's settings (numberToLevel
        -- etc.), overriding only the per-render state. Customize durable
        -- settings in `init`, not here.
        params =
            { compilerParameters
                | docWidth = g.docWidth -- width of rendered text in pixels
                , windowWidth = g.docWidth -- block width used by the renderer
                , editCount = model.count -- incremented on each edit; rendered text won't update withoug this
                , selectedId = model.selectId -- id of rendered text on which user clicked
                , theme = model.theme -- Dark or Light
            }

        compilerParameters =
            model.compilerParameters

        compilerOutput : XMarkdown.Types.CompilerOutput
        compilerOutput =
            XMarkdown.API.compileOutput params model.sourceText
    in
    div [ class "app", Html.Attributes.classList [ ( "dragging", model.dragging /= Nothing ) ] ]
        [ div [ class "app-header" ]
            [ div [ class "toolbar" ]
                [ button [ class "toolbar-button", Html.Events.onClick ToggleEditor ]
                    [ text
                        (if model.editorOpen then
                            "Close Editor"

                         else
                            "Open Editor"
                        )
                    ]
                , button [ class "toolbar-button", Html.Events.onClick OpenFileRequested ] [ text "Open File" ]
                , button [ class "toolbar-button", Html.Events.onClick SaveFileRequested ] [ text "Save File As" ]
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
                , button [ class "toolbar-button", Html.Events.onClick NewFileRequested ] [ text "New File" ]
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
                , button
                    [ class "toolbar-button"
                    , Html.Events.onClick ToggleNumberSections
                    ]
                    [ text
                        (if model.numberedSections then
                            "Section numbering: Yes"

                         else
                            "Section numbering: No"
                        )
                    ]
                ]
            , div [ class "app-title" ] [ text "XMarkdown TOC+Sync Demo" ]
            ]
        , div [ class "panels" ]
            [ -- Hidden rather than removed when closed, so CodeMirror keeps the
              -- document, cursor and undo history.
              div
                [ class "panel editor-panel"
                , style "width" (px g.editorW)
                , style "display"
                    (if model.editorOpen then
                        "block"

                     else
                        "none"
                    )
                ]
                [ editorView model ]
            , dividerView model EditorDivider model.editorOpen
            , div
                [ class "panel rendered-panel"
                , id XMarkdown.API.renderedTextId
                , style "background-color" (Render.Theme.themedColor .background model.theme)
                ]
                [ -- Html.map Render (renderPanel (round compilerOutput.interBlockSpacing) compilerOutput.body)
                  Html.map Render (renderPanel params compilerOutput.body)
                ]
            , dividerView model TocDivider True
            , div
                [ -- class "panel toc-panel"
                  style "width" (px g.tocW)
                , style "flex" "none"
                , style "overflow" "auto"
                , style "overscroll-behavior" "contain"
                , style "min-height" "0"
                , style "background" (Render.Theme.themedColor .background model.theme)
                ]
                [ Html.map Render (renderPanel model.compilerParameters compilerOutput.toc) ]
            ]
        ]



--renderPanel : Render.Theme.RenderSettings -> List (Html MarkupMsg) -> Html MarkupMsg
--renderPanel settings elements


{-| A draggable divider. Hidden (not removed) when not `visible`, so the
panels' positions in the child list stay fixed and Elm never recreates the
editor element.
-}
dividerView : Model -> Divider -> Bool -> Html Msg
dividerView model divider visible =
    div
        [ class "divider"
        , Html.Attributes.classList [ ( "active", model.dragging == Just divider ) ]
        , Html.Attributes.title "Drag to resize"
        , style "display"
            (if visible then
                "block"

             else
                "none"
            )

        -- preventDefault stops the drag from selecting text.
        , Html.Events.preventDefaultOn "mousedown" (Decode.succeed ( StartDrag divider, True ))
        ]
        []


editorView : Model -> Html Msg
editorView model =
    XMarkdown.API.viewEditor
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
        , Html.Attributes.style "max-width" (px params.docWidth)
        , Html.Attributes.style "margin" "0 auto"
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
    -- Try to scroll by ID first, fall back to data-line-number
    Browser.Dom.getElement elementId
        |> Task.andThen performScroll
        |> Task.onError
            (\_ ->
                -- ID not found, try by data-line-number
                let
                    selector =
                        "[data-line-number=\"" ++ String.fromInt lineNumber ++ "\"]"
                in
                Browser.Dom.getElement selector
                    |> Task.andThen performScroll
            )
        |> Task.onError
            (\err ->
                Task.fail err
            )
        |> Task.attempt (\_ -> NoOp)


performScroll : Browser.Dom.Element -> Task.Task Browser.Dom.Error ()
performScroll headingElement =
    Browser.Dom.getElement XMarkdown.API.renderedTextId
        |> Task.andThen
            (\containerElement ->
                Browser.Dom.getViewportOf XMarkdown.API.renderedTextId
                    |> Task.andThen
                        (\containerViewport ->
                            let
                                -- Position of heading relative to the document viewport
                                headingAbsY =
                                    headingElement.element.y

                                -- Position of container relative to the document viewport
                                containerAbsY =
                                    containerElement.element.y

                                -- Current scroll position of the container
                                currentScroll =
                                    containerViewport.viewport.y

                                -- Position of heading relative to the container's content
                                headingInContent =
                                    headingAbsY - containerAbsY + currentScroll

                                -- Scroll to place heading near top of container
                                targetScroll =
                                    max 0 (headingInContent - 50)
                            in
                            Browser.Dom.setViewportOf XMarkdown.API.renderedTextId 0 targetScroll
                        )
            )

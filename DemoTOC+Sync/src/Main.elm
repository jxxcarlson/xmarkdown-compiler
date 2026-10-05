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
import Html.Keyed
import Json.Decode as Decode
import Json.Encode as Encode
import LaTeX.Export
import Ports
import Process
import Render.Theme exposing (ThemedStyles, darkTheme, lightTheme)
import Task
import XMarkdown.API exposing (defaultCompilerParameters, fromMsgToSyncHighlight)
import XMarkdown.Types exposing (CompilerParameters, MarkupMsg(..), SyncHighlight, Theme(..))


main : Program Decode.Value Model Msg
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
        , Ports.folderOpened FolderOpened
        , Ports.desktopResponse (Decode.decodeValue desktopEventDecoder >> Result.withDefault DesktopCancelled >> GotDesktopEvent)
        , Ports.linkedFile LinkedFileClicked
        , Ports.pdfExported PdfExported
        , case model.dragging of
            Just _ ->
                Sub.batch
                    [ Browser.Events.onMouseMove (Decode.map DragMove (Decode.field "clientX" Decode.float))
                    , Browser.Events.onMouseUp (Decode.succeed StopDrag)
                    ]

            Nothing ->
                Sub.none
        , if model.fileMenuOpen || model.dialog /= Nothing || model.printStatus /= Nothing then
            Browser.Events.onKeyDown
                (Decode.field "key" Decode.string
                    |> Decode.andThen
                        (\key ->
                            if key == "Escape" then
                                Decode.succeed EscapePressed

                            else
                                Decode.fail "not Escape"
                        )
                )

          else
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
    , folderName : Maybe String
    , notice : Maybe String
    , fileMenuOpen : Bool
    , dialog : Maybe FileNameDialog
    , platform : Platform
    , filePath : Maybe String
    , folderPath : Maybe String
    , dirty : Bool
    , docVersion : Int
    , editVersion : Int
    , pdfExport : Bool
    , pdfShown : Maybe String
    , printStatus : Maybe PrintStatus
    }


{-| File > Print with no PDF shown: the PDF is generated first (desktop.js
printDocument), with a message window while that runs or if it fails.
-}
type PrintStatus
    = GeneratingPdf
    | PrintFailed String


{-| Web: the browser app (Open via file picker, Save downloads).
Desktop: the Tauri app (assets/desktop.js does native dialogs and file I/O).
-}
type Platform
    = Web
    | Desktop


{-| Replies from assets/desktop.js on the `desktopResponse` port.
-}
type DesktopEvent
    = DesktopOpened FileLocation String
    | DesktopSaved { path : String, token : Int }
    | DesktopSavedAs FileLocation Int
    | DesktopCreated FileLocation
    | DesktopCloseRequested String
    | DesktopFolderChosen { folder : String, folderName : String }
    | DesktopPdfShown (Maybe String)
    | DesktopPdfGenerated
    | DesktopPrintFailed String
    | DesktopError String
    | DesktopCancelled


type alias FileLocation =
    { path : String, name : String, folder : String, folderName : String }


{-| A small window asking for a file name: for File > New or File > Save As.
`name` is the text in its field.
-}
type alias FileNameDialog =
    { purpose : DialogPurpose, name : String }


type DialogPurpose
    = NewFileDialog
    | SaveAsDialog


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
    | SaveRequested
    | NewRequested
    | SaveAsRequested
    | ExportPdfRequested
    | PrintRequested
    | PrintMessageDismissed
    | PdfExported (Maybe String)
    | ToggleFileMenu
    | FileMenuChose Msg
    | EscapePressed
    | DialogNameChanged String
    | DialogConfirmed
    | DialogCancelled
    | LRSync String
    | ToggleTheme
    | ToggleNumberSections
    | ToggleEditor
    | StartDrag Divider
    | DragMove Float
    | StopDrag
    | OpenFolderRequested
    | FolderOpened String
    | LinkedFileClicked { name : String, content : Maybe String, folder : Maybe String }
    | GotDesktopEvent DesktopEvent
    | AutoSaveDue Int


{-| Flags are decoded by hand so that `platform` and `pdfExport` are optional:
pages that predate them (e.g. DemoTOC+Sync's app.js) omit them.

`pdfExport`: whether File > Export PDF is offered. It needs pdflatex, via
DemoTOC+Sync's local serve.py or the desktop app; the Netlify site has neither
and passes false. Defaults to true.
-}
type alias Flags =
    { window : { windowWidth : Int, windowHeight : Int }, platform : Platform, pdfExport : Bool }


flagsDecoder : Decode.Decoder Flags
flagsDecoder =
    Decode.map3 Flags
        (Decode.field "window"
            (Decode.map2 (\w h -> { windowWidth = w, windowHeight = h })
                (Decode.field "windowWidth" Decode.int)
                (Decode.field "windowHeight" Decode.int)
            )
        )
        (Decode.oneOf
            [ Decode.field "platform" Decode.string
                |> Decode.map
                    (\p ->
                        if p == "desktop" then
                            Desktop

                        else
                            Web
                    )
            , Decode.succeed Web
            ]
        )
        (Decode.oneOf [ Decode.field "pdfExport" Decode.bool, Decode.succeed True ])


init : Decode.Value -> ( Model, Cmd Msg )
init flagsValue =
    let
        flags =
            Decode.decodeValue flagsDecoder flagsValue
                |> Result.withDefault { window = { windowWidth = 1200, windowHeight = 800 }, platform = Web, pdfExport = True }

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
      , folderName = Nothing
      , notice = Nothing
      , fileMenuOpen = False
      , dialog = Nothing
      , platform = flags.platform
      , filePath = Nothing
      , folderPath = Nothing
      , dirty = False
      , docVersion = 0
      , editVersion = 0
      , pdfExport = flags.pdfExport
      , pdfShown = Nothing
      , printStatus = Nothing
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
            let
                edited =
                    { model | sourceText = str, count = model.count + 1, dirty = True, editVersion = model.editVersion + 1 }
            in
            ( edited, scheduleAutoSave edited )

        AutoSaveDue version ->
            -- Only the timer of the latest edit saves: typing restarts the pause.
            if version == model.editVersion then
                ( model, autoSave model )

            else
                ( model, Cmd.none )

        OpenFileRequested ->
            case model.platform of
                Desktop ->
                    ( model, desktopRequest "open" [] )

                Web ->
                    ( model, File.Select.file [ "text/markdown", "text/plain", ".md" ] FileSelected )

        FileSelected file ->
            ( { model | fileName = File.name file }, Task.perform FileLoaded (File.toString file) )

        FileLoaded content ->
            ( loadDocument content model, Cmd.none )

        ExportPdfRequested ->
            ( { model | notice = Just "Exporting PDF…" }
            , Ports.exportPdf
                { name = pdfName model.fileName
                , tex = LaTeX.Export.exportDocument { title = "", authors = [], date = "" } model.sourceText
                , images = LaTeX.Export.imageUrls model.sourceText
                }
            )

        -- Print the PDF on show, or generate one from the document and print that.
        PrintRequested ->
            case model.pdfShown of
                Just path ->
                    ( model, desktopRequest "printPdf" [ ( "path", Encode.string path ) ] )

                Nothing ->
                    ( { model | printStatus = Just GeneratingPdf }
                    , desktopRequest "printDocument"
                        [ ( "name", Encode.string (pdfName model.fileName) )
                        , ( "tex", Encode.string (LaTeX.Export.exportDocument { title = "", authors = [], date = "" } model.sourceText) )
                        , ( "images"
                          , Encode.list (\( url, localPath ) -> Encode.list Encode.string [ url, localPath ])
                                (LaTeX.Export.imageUrls model.sourceText)
                          )
                        ]
                    )

        PrintMessageDismissed ->
            ( { model | printStatus = Nothing }, Cmd.none )

        PdfExported result ->
            ( { model | notice = result }, Cmd.none )

        OpenFolderRequested ->
            case model.platform of
                Desktop ->
                    ( model, desktopRequest "openFolder" [] )

                Web ->
                    ( model, Ports.openFolder () )

        FolderOpened name ->
            ( { model | folderName = Just name, notice = Nothing }, Cmd.none )

        LinkedFileClicked { name, content, folder } ->
            case ( content, folder ) of
                ( Just fileText, _ ) ->
                    ( loadDocument fileText { model | fileName = name, filePath = Nothing }, Cmd.none )

                ( Nothing, Nothing ) ->
                    ( { model | notice = Just ("To follow links to files such as " ++ name ++ ", first use Open Folder.") }, Cmd.none )

                ( Nothing, Just folderName ) ->
                    ( { model | notice = Just (name ++ " was not found in " ++ folderName ++ ".") }, Cmd.none )

        SaveRequested ->
            case ( model.platform, model.filePath ) of
                ( Desktop, Just path ) ->
                    ( model, desktopSave path model [] )

                ( Desktop, Nothing ) ->
                    ( model, desktopSaveAs model )

                ( Web, _ ) ->
                    ( { model | dirty = False }, saveFile model )

        NewRequested ->
            openDialog NewFileDialog "untitled.md" model

        SaveAsRequested ->
            case model.platform of
                Desktop ->
                    ( model, desktopSaveAs model )

                Web ->
                    openDialog SaveAsDialog model.fileName model

        GotDesktopEvent event ->
            case event of
                -- Switching documents: save the one being left first.
                DesktopOpened location content ->
                    ( loadDocument content (atLocation location model), autoSave model )

                DesktopCreated location ->
                    ( newDocument location.name (atLocation location model), autoSave model )

                -- A save of the current file (a save of a document we've since
                -- left must not touch the model). The token is the editVersion
                -- that was written; if editing continued meanwhile, stay dirty.
                DesktopSaved { path, token } ->
                    if Just path == model.filePath then
                        ( { model | dirty = token /= model.editVersion, notice = Nothing }, Cmd.none )

                    else
                        ( model, Cmd.none )

                DesktopSavedAs location token ->
                    ( { model | dirty = token /= model.editVersion, notice = Nothing } |> atLocation location, Cmd.none )

                -- The window is closing or the app quitting: save, or ask before
                -- discarding a document that has nowhere to be saved, then finish.
                DesktopCloseRequested andThen ->
                    let
                        andThenArg =
                            ( "then", Encode.string andThen )
                    in
                    case ( model.dirty, model.filePath ) of
                        ( True, Just path ) ->
                            ( model, desktopSave path model [ andThenArg ] )

                        ( True, Nothing ) ->
                            ( model, desktopRequest "confirmDiscard" [ ( "name", Encode.string model.fileName ), andThenArg ] )

                        ( False, _ ) ->
                            ( model, desktopRequest "finish" [ andThenArg ] )

                DesktopFolderChosen { folder, folderName } ->
                    ( { model | folderPath = Just folder, folderName = Just folderName, notice = Nothing }, Cmd.none )

                -- The exported PDF shown in the app (or closed): File > Print.
                DesktopPdfShown path ->
                    ( { model | pdfShown = path }, Cmd.none )

                -- File > Print: the PDF is ready and the print panel opens.
                DesktopPdfGenerated ->
                    ( { model | printStatus = Nothing }, Cmd.none )

                DesktopPrintFailed message ->
                    ( { model | printStatus = Just (PrintFailed message) }, Cmd.none )

                DesktopError message ->
                    ( { model | notice = Just message }, Cmd.none )

                DesktopCancelled ->
                    ( model, Cmd.none )

        ToggleFileMenu ->
            ( { model | fileMenuOpen = not model.fileMenuOpen }, Cmd.none )

        FileMenuChose itemMsg ->
            update itemMsg { model | fileMenuOpen = False }

        EscapePressed ->
            ( { model | fileMenuOpen = False, dialog = Nothing, printStatus = Nothing }, Cmd.none )

        DialogNameChanged name ->
            ( { model | dialog = Maybe.map (\d -> { d | name = name }) model.dialog }, Cmd.none )

        DialogCancelled ->
            ( { model | dialog = Nothing }, Cmd.none )

        DialogConfirmed ->
            case model.dialog of
                Just { purpose, name } ->
                    let
                        fileName =
                            String.trim name
                    in
                    if String.isEmpty fileName then
                        ( model, Cmd.none )

                    else
                        case ( purpose, model.platform, model.folderPath ) of
                            -- On the desktop, New creates the file in the current
                            -- folder; the document is cleared when that succeeds.
                            ( NewFileDialog, Desktop, Just folder ) ->
                                ( { model | dialog = Nothing }
                                , desktopRequest "create" [ ( "folder", Encode.string folder ), ( "name", Encode.string fileName ) ]
                                )

                            ( NewFileDialog, _, _ ) ->
                                ( newDocument fileName { model | dialog = Nothing, filePath = Nothing }, autoSave model )

                            ( SaveAsDialog, _, _ ) ->
                                let
                                    renamed =
                                        { model | fileName = fileName, dialog = Nothing, dirty = False }
                                in
                                ( renamed, saveFile renamed )

                Nothing ->
                    ( model, Cmd.none )

        ToggleEditor ->
            ( clampWidths { model | editorOpen = not model.editorOpen }, Cmd.none )

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



{-| Browsers can't write to disk directly: saving downloads the document
under the current file name.
-}
saveFile : Model -> Cmd Msg
saveFile model =
    File.Download.string model.fileName "text/markdown" model.sourceText


openDialog : DialogPurpose -> String -> Model -> ( Model, Cmd Msg )
openDialog purpose name model =
    ( { model | dialog = Just { purpose = purpose, name = name } }
    , Task.attempt (\_ -> NoOp) (Browser.Dom.focus dialogInputId)
    )


dialogInputId : String
dialogInputId =
    "dialog-file-name"


{-| Replace the document. Bumping docVersion re-creates the editor element
(see editorPanel), so it shows `content` even when initialText is unchanged,
e.g. two New files in a row.
-}
loadDocument : String -> Model -> Model
loadDocument content model =
    { model
        | initialText = content
        , sourceText = content
        , count = model.count + 1
        , docVersion = model.docVersion + 1
        , syncHighlight = Nothing
        , notice = Nothing
        , dirty = False
    }


{-| An empty document named `name`, with the editor open for typing.
-}
newDocument : String -> Model -> Model
newDocument name model =
    loadDocument "" { model | fileName = name, editorOpen = True } |> clampWidths


{-| Record where the current document lives on disk (desktop only).
-}
atLocation : FileLocation -> Model -> Model
atLocation location model =
    { model
        | fileName = location.name
        , filePath = Just location.path
        , folderPath = Just location.folder
        , folderName = Just location.folderName
    }


{-| Send a request to assets/desktop.js: `op` plus named arguments.
-}
desktopRequest : String -> List ( String, Encode.Value ) -> Cmd Msg
desktopRequest op args =
    Ports.desktopRequest (Encode.object (( "op", Encode.string op ) :: args))


desktopSaveAs : Model -> Cmd Msg
desktopSaveAs model =
    desktopRequest "saveAs"
        [ ( "folder", model.folderPath |> Maybe.map Encode.string |> Maybe.withDefault Encode.null )
        , ( "name", Encode.string model.fileName )
        , ( "content", Encode.string model.sourceText )
        , ( "token", Encode.int model.editVersion )
        ]


{-| Write the current document to `path` (plus any extra request fields).
-}
desktopSave : String -> Model -> List ( String, Encode.Value ) -> Cmd Msg
desktopSave path model extra =
    desktopRequest "save"
        ([ ( "path", Encode.string path )
         , ( "content", Encode.string model.sourceText )
         , ( "token", Encode.int model.editVersion )
         ]
            ++ extra
        )



-- AUTO-SAVE (desktop only)


{-| Pause after the last keystroke before the document is saved.
-}
autoSaveDelay : Float
autoSaveDelay =
    1000


{-| Start the pause timer for the edit just made (desktop, saved files only).
-}
scheduleAutoSave : Model -> Cmd Msg
scheduleAutoSave model =
    if autoSaves model then
        Process.sleep autoSaveDelay |> Task.perform (\_ -> AutoSaveDue model.editVersion)

    else
        Cmd.none


{-| Save now if there are unsaved changes that auto-save covers.
-}
autoSave : Model -> Cmd Msg
autoSave model =
    case ( autoSaves model, model.dirty, model.filePath ) of
        ( True, True, Just path ) ->
            desktopSave path model []

        _ ->
            Cmd.none


{-| Auto-save applies only in the desktop app, and only to a document that
already has a file on disk; the web app never auto-saves.
-}
autoSaves : Model -> Bool
autoSaves model =
    model.platform == Desktop && model.filePath /= Nothing


desktopEventDecoder : Decode.Decoder DesktopEvent
desktopEventDecoder =
    let
        tokenField =
            Decode.oneOf [ Decode.field "token" Decode.int, Decode.succeed -1 ]

        location =
            Decode.map4 FileLocation
                (Decode.field "path" Decode.string)
                (Decode.field "name" Decode.string)
                (Decode.field "folder" Decode.string)
                (Decode.field "folderName" Decode.string)
    in
    Decode.field "kind" Decode.string
        |> Decode.andThen
            (\kind ->
                case kind of
                    "opened" ->
                        Decode.map2 DesktopOpened location (Decode.field "content" Decode.string)

                    "saved" ->
                        Decode.map2 (\path token -> DesktopSaved { path = path, token = token })
                            (Decode.field "path" Decode.string)
                            tokenField

                    "savedAs" ->
                        Decode.map2 DesktopSavedAs location tokenField

                    "closeRequested" ->
                        Decode.map DesktopCloseRequested (Decode.field "then" Decode.string)

                    "created" ->
                        Decode.map DesktopCreated location

                    "folder" ->
                        Decode.map2 (\folder folderName -> DesktopFolderChosen { folder = folder, folderName = folderName })
                            (Decode.field "folder" Decode.string)
                            (Decode.field "folderName" Decode.string)

                    "pdfGenerated" ->
                        Decode.succeed DesktopPdfGenerated

                    "printFailed" ->
                        Decode.map DesktopPrintFailed (Decode.field "message" Decode.string)

                    "pdfShown" ->
                        Decode.map DesktopPdfShown (Decode.field "path" (Decode.nullable Decode.string))

                    "error" ->
                        Decode.map DesktopError (Decode.field "message" Decode.string)

                    _ ->
                        Decode.succeed DesktopCancelled
            )



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
            [ div [ class "app-label" ] [ text "XMarkdown" ]
            , button [ class "toolbar-button", Html.Events.onClick ToggleEditor ]
                [ text
                    (if model.editorOpen then
                        "Close Editor"

                     else
                        "Open Editor"
                    )
                ]
            , fileMenu model
            , case model.folderName of
                Just name ->
                    div [ class "header-item", Html.Attributes.title "file:// links are opened from this folder" ]
                        [ Html.span [ class "header-key" ] [ text "Folder " ], text name ]

                Nothing ->
                    text ""
            , div
                [ class "header-item"
                , id "fileName"
                , Html.Attributes.title
                    (Maybe.withDefault model.fileName model.filePath
                        ++ (if autoSaves model then
                                " (saved automatically)"

                            else
                                ""
                           )
                    )
                ]
                [ Html.span [ class "header-key" ] [ text "File " ]
                , text model.fileName
                , if model.dirty then
                    Html.span [ class "dirty", Html.Attributes.title "Unsaved changes" ] [ text " •" ]

                  else
                    text ""
                ]
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
            , case model.notice of
                Just message ->
                    div [ class "notice" ] [ text message ]

                Nothing ->
                    text ""
            , div [ class "header-item word-count" ]
                [ text (formatCount (wordCount model.sourceText)), Html.span [ class "header-key" ] [ text " words" ] ]
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
                [ -- Keyed on docVersion: a new document gets a fresh editor element.
                  Html.Keyed.node "div"
                    [ style "height" "100%" ]
                    [ ( String.fromInt model.docVersion, editorView model ) ]
                ]
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
        , case model.dialog of
            Just dialog ->
                fileNameDialogView dialog

            Nothing ->
                text ""
        , case model.printStatus of
            Just status ->
                printStatusView status

            Nothing ->
                text ""
        ]



--renderPanel : Render.Theme.RenderSettings -> List (Html MarkupMsg) -> Html MarkupMsg
--renderPanel settings elements


{-| "notes.md" -> "notes.pdf"
-}
pdfName : String -> String
pdfName fileName =
    (if String.endsWith ".md" fileName then
        String.dropRight 3 fileName

     else
        fileName
    )
        ++ ".pdf"


{-| Words in the source: whitespace-separated tokens containing a letter or
digit, so markup like `#`, `-` and `$$` isn't counted.
-}
wordCount : String -> Int
wordCount source =
    source
        |> String.words
        |> List.filter (String.any Char.isAlphaNum)
        |> List.length


{-| 12345 -> "12,345"
-}
formatCount : Int -> String
formatCount n =
    let
        group digits =
            if String.length digits <= 3 then
                [ digits ]

            else
                group (String.dropRight 3 digits) ++ [ String.right 3 digits ]
    in
    String.join "," (group (String.fromInt n))


fileMenu : Model -> Html Msg
fileMenu model =
    let
        item label msg =
            button [ class "menu-item", Html.Events.onClick (FileMenuChose msg) ] [ text label ]
    in
    div [ class "menu" ]
        [ button
            [ class "toolbar-button"
            , Html.Attributes.classList [ ( "open", model.fileMenuOpen ) ]
            , Html.Events.onClick ToggleFileMenu
            ]
            [ text "File ▾" ]
        , if model.fileMenuOpen then
            -- The backdrop catches clicks outside the menu and closes it.
            div []
                [ div [ class "menu-backdrop", Html.Events.onClick ToggleFileMenu ] []
                , div [ class "menu-list" ]
                    ([ item "New…" NewRequested
                    , item "Open…" OpenFileRequested
                    , item "Open Folder…" OpenFolderRequested
                    , item "Save" SaveRequested
                    , item "Save As…" SaveAsRequested
                    ]
                        ++ (if model.pdfExport then
                                [ item "Export PDF" ExportPdfRequested ]

                            else
                                []
                           )
                        ++ (if model.platform == Desktop then
                                [ item "Print" PrintRequested ]

                            else
                                []
                           )
                    )
                ]

          else
            text ""
        ]


printStatusView : PrintStatus -> Html Msg
printStatusView status =
    div [ class "dialog-backdrop" ]
        [ div [ class "dialog" ]
            (case status of
                GeneratingPdf ->
                    [ Html.h2 [] [ text "Print" ]
                    , Html.p [] [ text "Generating PDF…" ]
                    ]

                PrintFailed message ->
                    [ Html.h2 [] [ text "Print" ]
                    , Html.p [] [ text ("The PDF could not be generated: " ++ message) ]
                    , div [ class "dialog-buttons" ]
                        [ button [ class "toolbar-button primary", Html.Events.onClick PrintMessageDismissed ] [ text "OK" ] ]
                    ]
            )
        ]


fileNameDialogView : FileNameDialog -> Html Msg
fileNameDialogView dialog =
    let
        title =
            case dialog.purpose of
                NewFileDialog ->
                    "New File"

                SaveAsDialog ->
                    "Save As"
    in
    div [ class "dialog-backdrop" ]
        [ Html.form [ class "dialog", Html.Events.onSubmit DialogConfirmed ]
            [ Html.h2 [] [ text title ]
            , Html.label [ Html.Attributes.for dialogInputId ] [ text "File name" ]
            , input
                [ id dialogInputId
                , value dialog.name
                , Html.Events.onInput DialogNameChanged
                , placeholder "name.md"
                , Html.Attributes.autocomplete False
                ]
                []
            , div [ class "dialog-buttons" ]
                [ button [ class "toolbar-button", Html.Attributes.type_ "button", Html.Events.onClick DialogCancelled ] [ text "Cancel" ]
                , button
                    [ class "toolbar-button primary"
                    , Html.Attributes.type_ "submit"
                    , Html.Attributes.disabled (String.isEmpty (String.trim dialog.name))
                    ]
                    [ text "Do it" ]
                ]
            ]
        ]


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

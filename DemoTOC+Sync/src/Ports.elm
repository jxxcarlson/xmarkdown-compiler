port module Ports exposing (lrSyncRequest, injectHighlightCSS, setEditorHighlightColor, setThemeColors, openFolder, folderOpened, linkedFile, desktopRequest, desktopResponse)

import Json.Decode
import Json.Encode


port lrSyncRequest : (String -> msg) -> Sub msg


port injectHighlightCSS : String -> Cmd msg


port setEditorHighlightColor : String -> Cmd msg


port setThemeColors : { fg : String, bg : String, indentGuide : String } -> Cmd msg


{-| Show the folder picker (assets/file-links.js). -}
port openFolder : () -> Cmd msg


{-| The name of the folder the user picked. -}
port folderOpened : (String -> msg) -> Sub msg


{-| A clicked `file://` link: `content` is Nothing when the file isn't in the
opened folder (or can't be read); `folder` is Nothing when no folder is open.
-}
port linkedFile : ({ name : String, content : Maybe String, folder : Maybe String } -> msg) -> Sub msg


{-| Desktop (Tauri) only: a request for assets/desktop.js, `{ op, ... }`. -}
port desktopRequest : Json.Encode.Value -> Cmd msg


{-| Desktop (Tauri) only: the reply, `{ kind, ... }`; see Main.desktopEventDecoder. -}
port desktopResponse : (Json.Decode.Value -> msg) -> Sub msg

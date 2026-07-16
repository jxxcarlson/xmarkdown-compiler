port module Ports exposing (lrSyncRequest, injectHighlightCSS, setEditorHighlightColor, setThemeColors)


port lrSyncRequest : (String -> msg) -> Sub msg


port injectHighlightCSS : String -> Cmd msg


port setEditorHighlightColor : String -> Cmd msg


port setThemeColors : { fg : String, bg : String } -> Cmd msg

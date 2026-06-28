port module Ports exposing (lrSyncRequest, injectHighlightCSS, setEditorHighlightColor)


port lrSyncRequest : (String -> msg) -> Sub msg


port injectHighlightCSS : String -> Cmd msg


port setEditorHighlightColor : String -> Cmd msg

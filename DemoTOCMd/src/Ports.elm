port module Ports exposing (lrSyncRequest, injectHighlightCSS)


port lrSyncRequest : (String -> msg) -> Sub msg


port injectHighlightCSS : String -> Cmd msg

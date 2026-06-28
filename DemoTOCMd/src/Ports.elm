port module Ports exposing (lrSyncRequest)


port lrSyncRequest : (String -> msg) -> Sub msg

module ScriptaV2.Msg exposing (MarkupMsg(..), Handling(..))

{-| The ScriptaV2.Msg.MarkupMsg type is need for synchronization of the source and rendered
text when using the Codemirror editor.

@docs MarkupMsg, Handling

-}


{-| -}
type MarkupMsg
    = SendMeta { begin : Int, end : Int, index : Int, id : String }
    | SendLineNumber { begin : Int, end : Int }
    | SelectId String
    | ToggleTOCNodeID String
    | HighlightId String
      --| RequestAnchorOffset_
      --| ReceiveAnchorOffset_ (Maybe Int)
    | JumpToTop
    | MMNoOp


{-| -}
type Handling
    = MHStandard
    | MHAsCheatSheet

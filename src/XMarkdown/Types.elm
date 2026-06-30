module XMarkdown.Types exposing
    ( CompilerParameters, defaultCompilerParameters, Filter(..)
    , CompilerOutput, Handling(..), MarkupMsg(..), SyncHighlight
    )

{-| This module defines the core types used for configuring the Scripta compiler.
The main type is `CompilerParameters`, which controls how XMarkdown source text
is compiled and rendered.


# Configuration

@docs CompilerParameters, defaultCompilerParameters, Filter


## Key Parameters

  - **docWidth**: Width of the rendered document in pixels
  - **editCount**: Increment this after each edit for live editing contexts (use 0 for static documents)
  - **selectedId**: ID of the currently selected block for highlighting
  - **theme**: Visual theme (Light or Dark)
  - **idsOfOpenNodes**: List of IDs for expanded/collapsed sections


## Usage

For simple use cases, start with `defaultCompilerParameters` and override the fields you need:

    { defaultCompilerParameters
        | docWidth = 600
        , editCount = model.editCount
    }

-}

import Dict exposing (Dict)
import Element exposing (Element)
import Render.Theme


{-| -}
type Filter
    = NoFilter
    | SuppressDocumentBlocks


{-| -}
defaultCompilerParameters : CompilerParameters
defaultCompilerParameters =
    { docWidth = 500
    , editCount = 0
    , selectedId = ""
    , selectedSlug = Nothing
    , idsOfOpenNodes = []
    , filter = NoFilter
    , theme = Render.Theme.Light

    --
    , highlightColor = "rgba(200, 200, 255, 0.4)"
    , paddingAboveHeadings = 10
    , interBlockSpacing = 0
    , lineHeight = 1.5
    , fontSize = 16
    , windowWidth = 500
    , scale = 1
    , numberToLevel = 0
    , data = Dict.empty
    }


{-| -}
type alias CompilerOutput =
    { body : List (Element MarkupMsg)
    , banner : Maybe (Element MarkupMsg)
    , toc : List (Element MarkupMsg)
    , title : Element MarkupMsg
    , interBlockSpacing : Float
    }


{-| -}
type alias CompilerParameters =
    { windowWidth : Int
    , scale : Float
    , docWidth : Int
    , editCount : Int
    , selectedId : String
    , selectedSlug : Maybe String
    , idsOfOpenNodes : List String
    , filter : Filter
    , theme : Render.Theme.Theme

    --
    , highlightColor : String
    , paddingAboveHeadings : Float
    , interBlockSpacing : Float
    , lineHeight : Float
    , fontSize : Int
    , numberToLevel : Int
    , data : Dict String String
    }


{-| Messages from rendered markup for synchronization with the editor.
Used for rendered-to-source syncing (e.g., clicking rendered text highlights source).
-}
type MarkupMsg
    = SendMeta { begin : Int, end : Int, index : Int, id : String }
    | SendLineNumber { begin : Int, end : Int }
    | SelectId String
    | ToggleTOCNodeID String
    | HighlightId String
    | JumpToTop
    | MMNoOp


{-| How to handle a MarkupMsg.
-}
type Handling
    = MHStandard
    | MHAsCheatSheet


{-| A source span to highlight in the editor.

  - `mode = "chars"`: `start`/`end` are document character offsets (`end` exclusive).
    Used for inline (phrase) clicks.
  - `mode = "lines"`: `start`/`end` are 1-indexed source lines, both inclusive.
    Used for block clicks.
  - `tick` is a monotonic counter so repeat clicks on the same span re-trigger the editor.

-}
type alias SyncHighlight =
    { mode : String
    , start : Int
    , end : Int
    , tick : Int
    }

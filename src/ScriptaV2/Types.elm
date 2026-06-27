module ScriptaV2.Types exposing (CompilerParameters, defaultCompilerParameters, Filter(..))

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
    , fontSize = 16
    , windowWidth = 500
    , scale = 1
    , numberToLevel = 1
    , data = Dict.empty
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
    , fontSize : Int
    , numberToLevel : Int
    , data : Dict String String
    }

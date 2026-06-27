module Render.BlockRegistry exposing
    ( BlockRegistry, BlockRenderer
    , empty, registerBatch, lookup
    )

{-| This module provides a registry for block renderers.

Instead of having a single monolithic dictionary of renderers, this module
allows renderers to be registered from various modules and looked up by name.

@docs BlockRegistry, BlockRenderer
@docs empty, registerBatch, lookup

-}

import Dict exposing (Dict)
import Element exposing (Element)
import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock)
import Render.Settings exposing (RenderSettings)
import Scripta.Msg exposing (MarkupMsg)


{-| Type alias for a block renderer function
-}
type alias BlockRenderer =
    Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg


{-| Type alias for the block registry
-}
type alias BlockRegistry =
    Dict String BlockRenderer


{-| Create an empty registry
-}
empty : BlockRegistry
empty =
    Dict.empty


{-| Register a renderer for a block type
-}
register : String -> BlockRenderer -> BlockRegistry -> BlockRegistry
register name renderer registry =
    Dict.insert name renderer registry


{-| Register multiple renderers at once
-}
registerBatch : List ( String, BlockRenderer ) -> BlockRegistry -> BlockRegistry
registerBatch renderers registry =
    List.foldl (\( name, renderer ) acc -> register name renderer acc) registry renderers


{-| Look up a renderer by name
-}
lookup : String -> BlockRegistry -> Maybe BlockRenderer
lookup =
    Dict.get

module Render.BlockType exposing
    ( BlockType(..), TextBlockType(..), DocumentBlockType
    , fromString
    )

{-| This module defines a type system for block types in the renderer.

Instead of using string comparisons to determine block types, we use proper
typed representations for better safety and maintainability.

@docs BlockType, TextBlockType, DocumentBlockType
@docs fromString

-}


{-| The main block type, categorizing blocks by their general purpose
-}
type BlockType
    = TextBlock TextBlockType
    | DocumentBlock DocumentBlockType
    | MiscBlock String -- For any blocks that don't fit the categories above


{-| Types of blocks that primarily format text
-}
type TextBlockType
    = Quotation


{-| Types of blocks related to document structure
-}
type DocumentBlockType
    = Title
    | Subtitle


{-| Convert a string to a BlockType
-}
fromString : String -> BlockType
fromString str =
    case str of
        -- Text blocks
        "quotation" ->
            TextBlock Quotation

        -- Document blocks
        "title" ->
            DocumentBlock Title

        "subtitle" ->
            DocumentBlock Subtitle

        _ ->
            MiscBlock str

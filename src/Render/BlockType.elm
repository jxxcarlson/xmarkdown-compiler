module Render.BlockType exposing
    ( BlockType(..), TextBlockType(..), ContainerBlockType(..), DocumentBlockType, InteractiveBlockType, ListBlockType(..)
    , fromString
    )

{-| This module defines a type system for block types in the renderer.

Instead of using string comparisons to determine block types, we use proper
typed representations for better safety and maintainability.

@docs BlockType, TextBlockType, ContainerBlockType, DocumentBlockType, InteractiveBlockType, ListBlockType
@docs fromString

-}


{-| The main block type, categorizing blocks by their general purpose
-}
type BlockType
    = TextBlock TextBlockType
    | ContainerBlock ContainerBlockType
    | DocumentBlock DocumentBlockType
    | InteractiveBlock InteractiveBlockType
    | ListBlock ListBlockType
    | MiscBlock String -- For any blocks that don't fit the categories above


{-| Types of blocks that primarily format text
-}
type TextBlockType
    = Indent
    | Center
    | Quotation
    | Identity
    | Compact
    | Red
    | Red2
    | Blue


{-| Types of blocks that act as containers for other content
-}
type ContainerBlockType
    = Box
    | Env
    | Comment
    | Collection
    | Bibitem


{-| Types of blocks related to document structure
-}
type DocumentBlockType
    = Title
    | Subtitle
    | Author
    | Date
    | Section
    | UnnumberedSection
    | Subheading
    | Contents
    | Banner
    | VisibleBanner
    | RunningHead
    | Document
    | Tags
    | Type


{-| Types of blocks that have interactive elements
-}
type InteractiveBlockType
    = Question
    | Answer
    | Reveal


{-| Types of blocks related to lists
-}
type ListBlockType
    = Item
    | Numbered
    | Description


{-| Convert a string to a BlockType
-}
fromString : String -> BlockType
fromString str =
    case str of
        -- Text blocks
        "indent" ->
            TextBlock Indent

        "center" ->
            TextBlock Center

        "quotation" ->
            TextBlock Quotation

        "identity" ->
            TextBlock Identity

        "compact" ->
            TextBlock Compact

        "red" ->
            TextBlock Red

        "red2" ->
            TextBlock Red2

        "blue" ->
            TextBlock Blue

        -- Container blocks
        "box" ->
            ContainerBlock Box

        "env" ->
            ContainerBlock Env

        "comment" ->
            ContainerBlock Comment

        "collection" ->
            ContainerBlock Collection

        "bibitem" ->
            ContainerBlock Bibitem

        -- Document blocks
        "title" ->
            DocumentBlock Title

        "subtitle" ->
            DocumentBlock Subtitle

        "author" ->
            DocumentBlock Author

        "date" ->
            DocumentBlock Date

        "section" ->
            DocumentBlock Section

        "section*" ->
            DocumentBlock UnnumberedSection

        "subheading" ->
            DocumentBlock Subheading

        "sh" ->
            DocumentBlock Subheading

        "contents" ->
            DocumentBlock Contents

        "banner" ->
            DocumentBlock Banner

        "visibleBanner" ->
            DocumentBlock VisibleBanner

        "runninghead_" ->
            DocumentBlock RunningHead

        "document" ->
            DocumentBlock Document

        "tags" ->
            DocumentBlock Tags

        "type" ->
            DocumentBlock Type

        -- Interactive blocks
        "q" ->
            InteractiveBlock Question

        "a" ->
            InteractiveBlock Answer

        "reveal" ->
            InteractiveBlock Reveal

        -- List blocks
        "item" ->
            ListBlock Item

        "numbered" ->
            ListBlock Numbered

        "desc" ->
            ListBlock Description

        -- Default case for anything else
        _ ->
            MiscBlock str

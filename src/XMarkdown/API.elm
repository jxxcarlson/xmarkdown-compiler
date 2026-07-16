module XMarkdown.API exposing
    ( compileOutput
    , viewBodyOnly, viewTOC, BlockMatch, renderedTextId, searchBlocksContainingText
    , viewEditor, compileString, compileStringWithTitle, defaultCompilerParameters
    , fromMsgToSyncHighlight
    )

{-| XMarkdown.API provides the core compilation interface for converting XMarkdown
(SMarkdown) source text into renderable Html.


# Overview

The API follows a two-step workflow:

1.  **Compile** source text into a `CompilerOutput` using `compileOutput`
2.  **View** the compiled output using `viewBodyOnly` or `viewTOC`

This separation allows you to compile once and render different parts (body, table
of contents) independently, which is useful for building rich document viewers with
navigation panels.


# Compilation

@docs compileOutput


# Viewing

@docs viewBodyOnly, viewTOC, BlockMatch, compile, fromMsg, renderedTextId, searchBlocksContainingText
@docs viewEditor, compileString, compileStringWithTitle, defaultCompilerParameters, editorView


# Usage Example

    import XMarkdown.API
    import XMarkdown.Types exposing (defaultCompilerParameters)


    -- Configure compiler
    params =
        { defaultCompilerParameters
            | docWidth = 600
            , editCount = 0
        }

    -- Compile source text
    output =
        XMarkdown.API.compileOutput params
            [ "# Introduction"
            , "This is a document with **bold** text."
            , ""
            , "## Details"
            , "More content here."
            ]

    -- Render the document body
    bodyElements =
        XMarkdown.API.viewBodyOnly 600 output

    -- Render table of contents separately
    tocElements =
        XMarkdown.API.viewTOC output


# Compiler parameters

To automatically number section headings imitate this example:


# See Also

For one-step compilation that parses and renders together, use `compileSimple`.

@docs compileSimple

-}

import Html exposing (Html)
import Html.Attributes
import XMarkdown.Compiler
import XMarkdown.Editor
import XMarkdown.Sync
import XMarkdown.Types exposing (MarkupMsg, SyncHighlight)


{-| Compile source text into a CompilerOutput structure.

This is the main compilation function that parses and processes XMarkdown source text.
The output contains the rendered body, optional banner, table of contents, and title,
which can then be displayed using the view functions.

    params =
        { defaultCompilerParameters
            | docWidth = 600
        }

    output =
        compileOutput params
            [ "# My Document"
            , "## Introduction"
            , "Content here."
            ]

-}
compileOutput : XMarkdown.Types.CompilerParameters -> String -> XMarkdown.Types.CompilerOutput
compileOutput =
    XMarkdown.Compiler.compile


{-| -}
compileString : XMarkdown.Types.CompilerParameters -> String -> List (Html MarkupMsg)
compileString params str =
    XMarkdown.Compiler.compile params str |> XMarkdown.Compiler.view params.docWidth


{-| defaultCompilerParameters =
{ docWidth = 500
, editCount = 0
, selectedId = ""
, selectedSlug = Nothing
, theme = Light
, backgroundColor = "rgba(255, 255, 255, 1.0)"
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
-}
defaultCompilerParameters : XMarkdown.Types.CompilerParameters
defaultCompilerParameters =
    XMarkdown.Types.defaultCompilerParameters


{-| Render only the body content from a CompilerOutput.

Takes a width parameter (in pixels) and returns a list of Html elements
representing the document body without the title or banner.

    bodyElements =
        viewBodyOnly 600 output

This is useful when you want to display the main content separately from other
document parts like the table of contents or title.

-}
viewBodyOnly : Int -> XMarkdown.Types.CompilerOutput -> List (Html MarkupMsg)
viewBodyOnly =
    XMarkdown.Compiler.viewBodyOnly


{-| Render the table of contents from a CompilerOutput.

Generates a navigable table of contents based on the document structure
(sections, subsections, etc.).

    tocElements =
        viewTOC output

The table of contents automatically includes links to document sections and
respects the document hierarchy.

-}
viewTOC : XMarkdown.Types.CompilerOutput -> List (Html MarkupMsg)
viewTOC =
    XMarkdown.Compiler.viewTOC


{-| -}
viewEditor : XMarkdown.Editor.Config msg -> Html msg
viewEditor =
    XMarkdown.Editor.view


{-| -}
fromMsgToSyncHighlight : Int -> MarkupMsg -> Maybe SyncHighlight
fromMsgToSyncHighlight =
    XMarkdown.Sync.fromMsg


{-| -}
renderedTextId : String
renderedTextId =
    XMarkdown.Editor.renderedTextId


{-| -}
compileStringWithTitle : String -> XMarkdown.Types.CompilerParameters -> String -> List (Html MarkupMsg)
compileStringWithTitle title params str =
    XMarkdown.Compiler.compile params str
        |> XMarkdown.Compiler.viewBodyOnly params.docWidth
        |> (\x -> Html.div [ Html.Attributes.style "height" "130px", Html.Attributes.style "font-size" "24px", Html.Attributes.style "padding" "8px 0 24px 0" ] [ Html.text title ] :: x)


{-| Re-export BlockMatch type for searching
-}
type alias BlockMatch =
    XMarkdown.Compiler.BlockMatch


{-| Search blocks in the document for text containing the search query.

Returns a list of matching blocks with their metadata (id, lineNumber, numberOfLines, sourceText).
The search is case-insensitive.

    matches =
        searchBlocksContainingText params (String.lines sourceText) "hello"

-}
searchBlocksContainingText : XMarkdown.Types.CompilerParameters -> List String -> String -> List BlockMatch
searchBlocksContainingText =
    XMarkdown.Compiler.searchBlocksContainingText

module XMarkdown.API exposing
    ( compileOutput
    , viewBodyOnly, viewTOC, BlockMatch, compile, fromMsg, renderedTextId, searchBlocksContainingText
    , viewEditor, compileString, compileStringWithTitle, defaultCompilerParameters, editorView
    , compileSimple
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


{-| -}
compile : XMarkdown.Types.CompilerParameters -> List String -> XMarkdown.Types.CompilerOutput
compile =
    XMarkdown.Compiler.compile


{-| -}
defaultCompilerParameters : XMarkdown.Types.CompilerParameters
defaultCompilerParameters =
    XMarkdown.Types.defaultCompilerParameters


{-| -}
editorView : XMarkdown.Editor.Config msg -> Html msg
editorView =
    XMarkdown.Editor.view


{-| -}
fromMsg : Int -> MarkupMsg -> Maybe SyncHighlight
fromMsg =
    XMarkdown.Sync.fromMsg


{-| -}
renderedTextId : String
renderedTextId =
    XMarkdown.Editor.renderedTextId


{-| -}
viewEditor : XMarkdown.Editor.Config msg -> Html msg
viewEditor =
    XMarkdown.Editor.view


{-| Compile source text to Html in one step (parse + render). The width of
the rendered text in pixels is `docWidth`. Use `editCount = 0` for a static
document; in a live-editing context, increment it after each edit so the rendered
text updates correctly.

    import Html exposing (Html)
    import XMarkdown.API exposing (MarkupMsg, defaultCompilerParameters)

Your `Msg` type should include `| Render MarkupMsg`.

-}
compileSimple : XMarkdown.Types.CompilerParameters -> String -> List (Html MarkupMsg)
compileSimple params sourceText =
    XMarkdown.Compiler.compile params (String.lines sourceText) |> XMarkdown.Compiler.viewBodyOnly params.docWidth


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
compileOutput : XMarkdown.Types.CompilerParameters -> List String -> XMarkdown.Types.CompilerOutput
compileOutput params lines =
    XMarkdown.Compiler.compile params lines


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
compileString : XMarkdown.Types.CompilerParameters -> String -> List (Html MarkupMsg)
compileString params str =
    XMarkdown.Compiler.compile params (String.lines str) |> XMarkdown.Compiler.view params.docWidth


{-| -}
compileStringWithTitle : String -> XMarkdown.Types.CompilerParameters -> String -> List (Html MarkupMsg)
compileStringWithTitle title params str =
    XMarkdown.Compiler.compile params (String.lines str)
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

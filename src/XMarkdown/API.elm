module XMarkdown.API exposing
    ( compileOutput
    , viewBodyOnly, viewTOC
    , compileSimple
    , BlockMatch, compile, compileString, compileStringWithTitle, renderedTextId, searchBlocksContainingText, viewEditor
    , defaultCompilerParameters
    , fromMsg
    )

{-| XMarkdown.API provides the core compilation interface for converting XMarkdown
(SMarkdown) source text into renderable elm-ui Elements.


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

@docs viewBodyOnly, viewTOC


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


# See Also

For one-step compilation that parses and renders together, use `compileSimple`.

@docs compileSimple

-}

--4. XMarkdown.Msg exposing (MarkupMsg) — used for:
--  - Type: MarkupMsg (line 19 in type signature)
--  - Pattern matching: XMarkdown.Msg.ToggleTOCNodeID and XMarkdown.Msg.SelectId (lines 212, 227)
--5. XMarkdown.Sync — used for:
--  - Type: XMarkdown.Sync.SyncHighlight (line 51)
--  - Function: XMarkdown.Sync.fromMsg (line 206)
--6. XMarkdown.Types exposing (Filter(..), defaultCompilerParameters) — used for:
--  - Type: Filter (line 21 exposing, NoFilter at line 283)
--  - Value: defaultCompilerParameters (lines 92, 135, 278)

import Element exposing (Element)
import Element.Font
import Render.Settings
import XMarkdown.Compiler
import XMarkdown.Editor
import XMarkdown.Sync
import XMarkdown.Types exposing (MarkupMsg)


defaultCompilerParameters =
    XMarkdown.Types.defaultCompilerParameters


fromMsg =
    XMarkdown.Sync.fromMsg


compile =
    XMarkdown.Compiler.compile


viewEditor =
    XMarkdown.Editor.view


renderedTextId =
    XMarkdown.Editor.renderedTextId



--Pattern matching: XMarkdown.Msg.ToggleTOCNodeID and XMarkdown.Msg.SelectId


{-| Compile source text to elm-ui HTML in one step (parse + render). The width of
the rendered text in pixels is `docWidth`. Use `editCount = 0` for a static
document; in a live-editing context, increment it after each edit so the rendered
text updates correctly.

    import Element exposing (Element)
    import XMarkdown.API exposing (MarkupMsg, defaultCompilerParameters)

Your `Msg` type should include `| Render MarkupMsg`.

-}
compileSimple : XMarkdown.Types.CompilerParameters -> String -> List (Element MarkupMsg)
compileSimple params sourceText =
    XMarkdown.Compiler.compile params (String.lines sourceText) |> XMarkdown.Compiler.view params.docWidth


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
compileOutput : XMarkdown.Types.CompilerParameters -> List String -> XMarkdown.Compiler.CompilerOutput
compileOutput params lines =
    XMarkdown.Compiler.compile params lines


{-| Render only the body content from a CompilerOutput.

Takes a width parameter (in pixels) and returns a list of elm-ui Elements
representing the document body without the title or banner.

    bodyElements =
        viewBodyOnly 600 output

This is useful when you want to display the main content separately from other
document parts like the table of contents or title.

-}
viewBodyOnly : Int -> XMarkdown.Compiler.CompilerOutput -> List (Element MarkupMsg)
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
viewTOC : XMarkdown.Compiler.CompilerOutput -> List (Element MarkupMsg)
viewTOC =
    XMarkdown.Compiler.viewTOC


{-| -}
compileString : XMarkdown.Types.CompilerParameters -> String -> List (Element MarkupMsg)
compileString params str =
    XMarkdown.Compiler.compile params (String.lines str) |> XMarkdown.Compiler.view params.docWidth


compileStringWithTitle : String -> XMarkdown.Types.CompilerParameters -> String -> List (Element MarkupMsg)
compileStringWithTitle title params str =
    XMarkdown.Compiler.compile params (String.lines str)
        |> XMarkdown.Compiler.viewBodyOnly params.docWidth
        |> (\x -> Element.el [ Element.height (Element.px 130), Element.Font.size (Render.Settings.scaleFont (Render.Settings.defaultRenderSettings params) 24), Element.paddingEach { left = 0, right = 0, top = 8, bottom = 24 } ] (Element.text title) :: x)


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

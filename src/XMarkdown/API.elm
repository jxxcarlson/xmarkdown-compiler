module XMarkdown.API exposing
    ( compileOutput, compileString, compileStringWithTitle, defaultCompilerParameters
    , viewEditor, viewBodyOnly, viewTOC, BlockMatch, fromMsgToSyncHighlight, renderedTextId, searchBlocksContainingText
    )

{-| XMarkdown.API provides the core compilation interface for converting XMarkdown
source text into renderable Html. See [xmarkdowndemo.netlify.app](https://xmarkdowndemo.netlify.app/)
for a working example.


# Overview

The simplest way to compile XMarkdown text is to use `compileString`, e.g.

    compileString defaultCompilerParameters
        "# Mathematics\n\nPythagoras sez that $a^2 + b^2 = c^2$"

See below for more information on compiler parameters. The DemoTOC and DemoTOC+Sync+Sync examples require a two-step workflow:
(1) Compile source text into a CompilerOutput structure using the function `compileOutput`, (2) view the CompilerOutput structure using the function
`viewBodyOnly` for the body of the text `viewTOC`, for the table of contents, etc.


# Example

        import XMarkdown.API
        import XMarkdown.Types exposing (defaultCompilerParameters)


        -- Configure compiler
        params =
            { defaultCompilerParameters
                | docWidth = 600
            }

        -- Compile source text
        output =
            XMarkdown.API.compileOutput params
              """
              # Introduction"

              XMarkdown can render mathematical formulas in **real time.**

              ## Examples

              Pythagoras says that $a^2 + b^2 = c^2$.
              Integration of polynomials depends on the formula

              $$
              int x^n dx = frac(1,n+1) x^{n+1} + C
              $$
              """


# Compilation

@docs compileOutput, compileString, compileStringWithTitle, defaultCompilerParameters


# Viewing

@docs viewEditor, viewBodyOnly, viewTOC, BlockMatch, fromMsgToSyncHighlight, renderedTextId, searchBlocksContainingText

        -- Render the document body
        body =
            XMarkdown.API.viewBodyOnly 600 output

        -- Render table of contents separately
        toc =
            XMarkdown.API.viewTOC output

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

    body =
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

    toc =
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

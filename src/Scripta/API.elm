module Scripta.API exposing
    ( compileOutput
    , viewBodyOnly, viewTOC
    , compileSimple, compileString, compileStringWithTitle
    )

{-| Scripta.API provides the core compilation interface for converting XMarkdown
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

    import Scripta.API
    import Scripta.Types exposing (defaultCompilerParameters)


    -- Configure compiler
    params =
        { defaultCompilerParameters
            | docWidth = 600
            , editCount = 0
        }

    -- Compile source text
    output =
        Scripta.API.compileOutput params
            [ "# Introduction"
            , "This is a document with **bold** text."
            , ""
            , "## Details"
            , "More content here."
            ]

    -- Render the document body
    bodyElements =
        Scripta.API.viewBodyOnly 600 output

    -- Render table of contents separately
    tocElements =
        Scripta.API.viewTOC output


# See Also

For one-step compilation that parses and renders together, use `compileSimple`.

@docs compileSimple

-}

import Element exposing (Element)
import Element.Font
import Render.Settings
import Scripta.Compiler
import Scripta.Msg
import Scripta.Types


{-| Compile source text to elm-ui HTML in one step (parse + render). The width of
the rendered text in pixels is `docWidth`. Use `editCount = 0` for a static
document; in a live-editing context, increment it after each edit so the rendered
text updates correctly.

    import Element exposing (Element)
    import Scripta.API
    import Scripta.Msg exposing (MarkupMsg)
    import Scripta.Types exposing (defaultCompilerParameters)

Your `Msg` type should include `| Render MarkupMsg`.

-}
compileSimple : Scripta.Types.CompilerParameters -> String -> List (Element Scripta.Msg.MarkupMsg)
compileSimple params sourceText =
    Scripta.Compiler.compile params (String.lines sourceText) |> Scripta.Compiler.view params.docWidth


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
compileOutput : Scripta.Types.CompilerParameters -> List String -> Scripta.Compiler.CompilerOutput
compileOutput params lines =
    Scripta.Compiler.compile params lines


{-| Render only the body content from a CompilerOutput.

Takes a width parameter (in pixels) and returns a list of elm-ui Elements
representing the document body without the title or banner.

    bodyElements =
        viewBodyOnly 600 output

This is useful when you want to display the main content separately from other
document parts like the table of contents or title.

-}
viewBodyOnly : Int -> Scripta.Compiler.CompilerOutput -> List (Element Scripta.Msg.MarkupMsg)
viewBodyOnly =
    Scripta.Compiler.viewBodyOnly


{-| Render the table of contents from a CompilerOutput.

Generates a navigable table of contents based on the document structure
(sections, subsections, etc.).

    tocElements =
        viewTOC output

The table of contents automatically includes links to document sections and
respects the document hierarchy.

-}
viewTOC : Scripta.Compiler.CompilerOutput -> List (Element Scripta.Msg.MarkupMsg)
viewTOC =
    Scripta.Compiler.viewTOC


{-| -}
compileString : Scripta.Types.CompilerParameters -> String -> List (Element Scripta.Msg.MarkupMsg)
compileString params str =
    Scripta.Compiler.compile params (String.lines str) |> Scripta.Compiler.view params.docWidth


compileStringWithTitle : String -> Scripta.Types.CompilerParameters -> String -> List (Element Scripta.Msg.MarkupMsg)
compileStringWithTitle title params str =
    Scripta.Compiler.compile params (String.lines str)
        |> Scripta.Compiler.viewBodyOnly params.docWidth
        |> (\x -> Element.el [ Element.height (Element.px 130), Element.Font.size (Render.Settings.scaleFont (Render.Settings.defaultRenderSettings params) 24), Element.paddingEach { left = 0, right = 0, top = 8, bottom = 24 } ] (Element.text title) :: x)

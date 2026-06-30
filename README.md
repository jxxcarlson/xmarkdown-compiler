# XMarkdown Compiler

A standalone compiler for **XMarkdown** (Scientific Markdown / SMarkdown), which
compiles XMarkdown source text into elm-ui HTML elements.

## What is XMarkdown?

XMarkdown is a scientific-flavored Markdown dialect. It supports:

- Standard Markdown: headings (`#`, `##`, ...) and emphasis (`**bold**`, `*italic*`)
- Fenced code blocks (`` ``` ``)
- Math: inline math (`$...$`) and display math (`$$\n...\n$$`)
- Tables (GFM-style)
- Automatic table of contents generation

## Quick Start

Add the package:

```bash
elm install jxxcarlson/xmarkdown-compiler
```

### One-step compilation

For simple use cases, compile and render in one step:

```elm
import Element exposing (Element)
import XMarkdown.API exposing (compileSimple, defaultCompilerParameters)
import XMarkdown.Types exposing (MarkupMsg(..))

source : String
source = """
# Introduction

This is **bold** text.

## Math

$$
\\int_0^1 x^n dx = \\frac{1}{n+1}
$$
"""

params = 
    { defaultCompilerParameters
        | docWidth = 600
        , filter = NoFilter
    }

view : Element MarkupMsg
view = 
    Element.column [] 
        (compileSimple params source)
```

### Two-step compilation (for advanced use)

Compile once and render different parts separately:

```elm
import XMarkdown.API exposing (compileOutput, viewBodyOnly, viewTOC)

output = 
    compileOutput params (String.lines source)

-- Render just the body
body = viewBodyOnly 600 output.body

-- Render just the table of contents
toc = viewTOC output.toc
```

## Public API

| Module | Purpose |
|---|---|
| `XMarkdown.API` | Compilation and rendering functions; re-exports convenience values |
| `XMarkdown.Types` | `CompilerParameters`, `defaultCompilerParameters`, `Filter`, `MarkupMsg`, `SyncHighlight`, `Handling` |
| `XMarkdown.Editor` | Codemirror editor integration |
| `XMarkdown.Sync` | Rendered-to-source synchronization for live editing |
| `Render.Theme` | Light/Dark theme configuration |

## Configuration

All compilation requires a `CompilerParameters` record. Use `defaultCompilerParameters` 
and override fields as needed:

```elm
params = 
    { defaultCompilerParameters
        | docWidth = 800                    -- width in pixels
        , editCount = 0                     -- increment on each edit for live contexts
        , selectedId = ""                   -- highlight a specific block
        , idsOfOpenNodes = []               -- keep sections expanded/collapsed
        , theme = Render.Theme.Light        -- Light or Dark
        , fontSize = 16                     -- base font size
        , numberToLevel = 2                 -- heading levels for table of contents
    }
```

## Message Handling

When using the editor integration, handle `MarkupMsg` in your update function:

```elm
type Msg
    = Render MarkupMsg
    | ... other messages

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Render markupMsg ->
            -- Handle MarkupMsg (e.g., synchronize with editor, toggle sections)
            ( model, Cmd.none )
        ...
```

## Editor Integration

For live editing with the Codemirror editor, use `XMarkdown.Editor`:

```elm
import XMarkdown.Editor
import XMarkdown.Types exposing (SyncHighlight)

type alias Model =
    { editorText : String
    , syncHighlight : Maybe SyncHighlight
    , ... 
    }

editorConfig =
    { source = model.editorText
    , onInput = InputText
    , highlight = model.syncHighlight
    , attrs = []
    }

view = XMarkdown.Editor.view editorConfig
```

## License

MIT

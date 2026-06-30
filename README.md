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


## Usage

Add the package:

```bash
elm install jxxcarlson/xmarkdown-compiler
```

Then build an app around this:  

```elm
import XMarkdown.API exposing (defaultCompilerParameters)
import XMarkdown.Types exposing (MarkupMsg(..))

output : List (Element MarkupMsg)
output = XMarkdown.API.compileSimple defaultCompilerParameters source

source : String
source = """
# Introduction

This is **bold** text.

## Math

$$
int_0^1 x^n dx = frac(1,n+1)
$$
"""
```
You can also use standard TeX notation with lots of backslashes and curly braces:
`\\int_0^1 x^n dx = \\frac{1}{n+1)}`. See the [ETeX](https://package.elm-lang.org/packages/jxxcarlson/etex/latest/) package.

## Example Apps

See the `DemoMd` and `DemoTOCMd` folders for more complete examples.
The second of these shows how to construct an automatically updated
active table of contents which in addition enables the user to 

  - click on rendered text to highlight and scroll into view the corresponding source text
  - select source text and highlight and scroll into view the corresponding rendered text

## License

MIT

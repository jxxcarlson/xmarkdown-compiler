# XMarkdown Compiler

A standalone compiler for **XMarkdown** (Scientific Markdown / SMarkdown), which
compiles XMarkdown source text into elm-ui HTML elements.

## What is XMarkdown?

XMarkdown is a scientific-flavored Markdown dialect. It supports:
- Standard Markdown headings (`#`, `##`, ...) and emphasis (`**bold**`, `_italic_`)
- Fenced code blocks (`` ``` ``)
- Math blocks (`$$`) and inline math
- Named blocks (`| theorem`, `| equation`, `| code`, ...)
- Tables
- `@[...]` inline syntax for cells, rows, and custom inline elements
- Table of contents generation

## Quick Start

Add the package:

```bash
elm install jxxcarlson/xmarkdown-compiler
```

Compile source text:

```elm
import ScriptaV2.APISimple exposing (compile)
import ScriptaV2.Language exposing (Language(..))
import ScriptaV2.Types exposing (defaultCompilerParameters)
import ScriptaV2.Msg exposing (MarkupMsg)
import Element exposing (Element)

source : String
source = """
# Introduction

This is a **bold** introduction.

| theorem
There are infinitely many prime numbers.

$$
\\int_0^1 x^n dx = \\frac{1}{n+1}
$$
"""

output : List (Element MarkupMsg)
output = compile defaultCompilerParameters source
```

## Public API

| Module | Purpose |
|---|---|
| `ScriptaV2.APISimple` | High-level `compile` entry point |
| `ScriptaV2.API` | Full compiler API |
| `ScriptaV2.Types` | `CompilerParameters`, `defaultCompilerParameters`, `Filter` |
| `ScriptaV2.Msg` | `MarkupMsg` type for elm-ui |
| `ScriptaV2.Language` | `Language` type (`SMarkdownLang`) |
| `Render.Theme` | Light/Dark theme |

## License

MIT

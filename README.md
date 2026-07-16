# XMarkdown Compiler

A standalone compiler for **XMarkdown**.  XMarkdown is an extended version of Markdown with 
support for rendering mathematics. Mathematical text is presented either as TeX or ETeX (ergonomic TeX).
Consider the text for a standard calculus formula:

```
$$
\int_0^1 x^n dx = \frac{1}{n+1}
$$
```

That is the TeX version. ETeX looks like this:

```
$$
int_0^1 x^n dx = frac(1,n+1)
$$
```

XMarkdown accepts both forms.
Note that the double dollar signs occupy lines by themselves.  This
is good style in TeX but in XMarkdown it is required.  You can 
find the ETeX package [here](https://package.elm-lang.org/packages/jxxcarlson/etex/latest/).

There is also an [online demo](https://xmarkdowndemo.netlify.app/) of XMarkdown.

## What else?

XMarkdown is pretty much like standard markdown, with 
the usual`**bold**` and`*italic*` text. It also has
tables, better handling of images, automatic section 
numbering, and automatic generation of a live table of 
contents. Perhaps the most important feature, illustrated by
XXX, is synchronization of edited an rendered text:

- click on rendered text to highlight and scroll into view the corresponding source text
- select source text and highlight and scroll into view the corresponding rendered text

##   Compiler options




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

## Example Apps
 
See the `DemoTOC` and `DemoTOC+Sync` folders for more complete examples.
The second of these shows how to construct an automatically updated
active table of contents which in addition enables the user to 

  - click on rendered text to highlight and scroll into view the corresponding source text
  - select source text and highlight and scroll into view the corresponding rendered text

See also [this online demo](https://xmarkdowndemo.netlify.app/)

## License

MIT

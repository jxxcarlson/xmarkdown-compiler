module Data.XMarkdown exposing (text)


text =
    """

# Sample Document

XMarkdown is a version of Markdown which handles mathematical text and other features.  These are described below.

Feel free to edit this text.  Your changes will not be saved.

# Math

XMarkdown handles both inline and displayed mathematical text, e.g., $a^2 + b^2 = c^2$
and

$$
cos(x) = sum_{n=0}^infty (-1)^n frac(x^{2n},(2n)!)
$$

Here is the source text: `$a^2 + b^2 = c^2$` for inline formulas and

```
$$
cos(x) = sum_{n=0}^infty (-1)^n frac(x^{2n},(2n)!)
$$
```

for displayed formulas. The source text looks like TeX but without most of the backslashes and curly braces that are customary.  This is [ETeX](https://package.elm-lang.org/packages/jxxcarlson/etex/latest/), an Elm package which implements this simplified syntax.  You may also use regular TeX:

```
$$
\\cos{x} = \\sum_{n=0}^\\infty(-1)^n \\frac{x^{2n}}{(2n)!}
$$
```

In ETeX curly braces are used for grouping.

# Real-time Rendering

XMarkdown provides for real-time rendering: the rendered text is updated as you type.

# Synchronization

XMarkdown can synchronize source and rendered text:

- Click on a piece of rendered text. The corresponding piece of source text will be highlighted and scrolled into view.

- Select a piece of of rendered text and type cmd-S. (S for sync). The block of rendered text will be highlighted and scrolled into view.

# Table of Contents

XMarkdown provides for an optional real-time active table of contents.  If you create, edit, or remove sections, these changes will be reflected immediately in the table of contents.  Click on an entry in the table of contents and the corresponding source and rendered text will be scrolled into view.

Also note the search and replace features of the editor. Type cmd-F to bring up the editor, ESC to dismiss it.

*You can edit whatever you like in this document.  Your edits will not be saved.*


# Images

![European Robin — click to open in new tab width:400](https://fathersonbirding.com/wp-content/uploads/2020/01/European-Robin-Amsterdam-2019_12_282743-1536x1238.jpg)

The element `[...]` holds the caption for the image as well as optional properties such as `width:400`.


# Tables

XMarkdown provides for Github-style tables.  These tables may contain mathematical text.

**Ages, Occupations, and Favorite Formulas**

| Name  | Age | Occupation  | F.F.|
|:-------|----:|:-------------|-----:|
| Alice |  28 | *Engineer*    | $n!$ |
| Bob   |  34 | *Musician*    | $3:2$ |
| Carol |  41 | *Mathematician* | $sqrt(2 + \\sqrt5)$

 """

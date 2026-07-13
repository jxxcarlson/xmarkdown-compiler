module Data.Example exposing (exampleMarkdown)


exampleMarkdown : String
exampleMarkdown =
    """

# Sample Document

XMarkdown extends Markdown to handle mathematical text. Inline math can use either `$...$` syntax like $a^2 + b^2 = c^2$ or LaTeX-style `\\(...\\)` syntax like \\(a^2 + b^2 = c^2\\). Display math:

$$
cos(x) = sum_{n=0}^infty (-1)^n frac(x^{2n},(2n)!)
$$

Here is the source text:

```
$$
cos(x) = sum_{n=0}^infty (-1)^n frac(x^{2n},(2n)!)
$$
```

You can also use standard TeX format:

```
$$
\\cos(x) = \\sum_{n=0}^\\infty (-1)^n \\frac{x^{2n}}{(2n)!}
$$
```

## Images

Images are handled somewhat differently:

![European Robin — click to open in new tab width:400](https://fathersonbirding.com/wp-content/uploads/2020/01/European-Robin-Amsterdam-2019_12_282743-1536x1238.jpg)

The element `[...]` holds the caption for the image as well as optional properties such as `width:400`.

## LaTeX Math Syntax

You can also use LaTeX-style delimiters for inline math:

- Using dollars: $e = mc^2$
- Using backslash parens: \\(e = mc^2\\)
- Complex expression: \\(\\sum_{i=0}^n x_i = \\frac{n(n+1)}{2}\\)
- Mixed on same line: The formula $E=mc^2$ is equivalent to \\(E=mc^2\\).

## Tables

**Ages, Occupations, and Favorite Formulas**

| Name  | Age | Occupation  | F.V|
|-------|----:|-------------|
| Alice |  28 | *Engineer*    | $n!$ |
| Bob   |  34 | *Musician*    | $3:2$ |
| Carol |  41 | *Mathematician* | $sqrt(2)$

"""

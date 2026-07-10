module Data.Example exposing (exampleMarkdown)


exampleMarkdown : String
exampleMarkdown =
    """

# Sample Document

XMarkdown extends Markdown to handle mathematical text, e.g., $a^2 + b^2 = c^2$ or this:

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

## Tables

**Ages, Occupations, and Favorite Formulas**

| Name  | Age | Occupation  | F.V|
|-------|----:|-------------|
| Alice |  28 | *Engineer*    | $n!$ |
| Bob   |  34 | *Musician*    | $3:2$ |
| Carol |  41 | *Mathematician* | $sqrt(2)$

"""

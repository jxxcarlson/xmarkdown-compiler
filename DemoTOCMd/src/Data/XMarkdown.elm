module Data.XMarkdown exposing (text)


text =
    """


# Sample Document


This sample document illustrates both the standard and new features of XMarkdown as compared to ordinary Markdown. First of these are math support, e.g.

$$
cos(x) = sum_{n=0}^infty (-1)^n frac(x^{2n},(2n)!)
$$

Second is synchronization of source and rendered text:

- Click on a piece of rendered text. The corresponding piece of source text will be highlighted and scrolled into view.

- Select a piece of of rendered text and type cmd-S. (S for sync). The block of rendered text will be highlighted and scrolled into view.

Third is a real-time active table of contents.  If you create, edit, or remove sections, these changes will be reflected immediately in the table of contents.  Click on an entry in the table of contents and the corresponding source and rendered text will be scrolled into view.

Also note the search and replace features of the editor. Type cmd-F to bring up the editor, ESC to dismiss it.

*You can edit whatever you like in this document.  Your edits will not be saved.*

# Text

The *Schwarzschild radius* is one of the simplest and **most important quantities in black-hole physics**. It is the radius of the event horizon of a non-rotating, uncharged black hole.

# Links

I read the [New York Times](https://nytimes.com) every day.

# Images

![European Robin — click to open in new tab width:400](https://fathersonbirding.com/wp-content/uploads/2020/01/European-Robin-Amsterdam-2019_12_282743-1536x1238.jpg)

The element `[...]` holds the caption for the image as well as optional properties such as `width:400`.


# Quotations

Quotations are indented and rendered in italic:

> What we know is not much. What we do not know is immense. — Pierre-Simon Laplace


# Compact lists

Use "-" as the prefix for itemized lists:

- G is Newton’s gravitational constant.
- M is the mass of the object.
- c is the speed of light.

Use "." as the prefix for numbered lists:

. G is Newton’s gravitational constant,  G is Newton’s gravitational constant, G is Newton’s gravitational constant.
. M is the mass of the object.
. c  is the speed of light.


# Ordinary lists

Use "-" as the prefix for itemized lists:

- G is Newton’s gravitational constant. G is Newton’s gravitational constant.G is Newton’s gravitational constant.

- G is the mass of the object.

- c is the speed of light.

Use "." as the prefix for numbered lists:

. G is Newton’s gravitational constant. G is Newton’s gravitational constant. G is Newton’s gravitational constant.

. G is the mass of the object.

. c is the speed of light.


# Tables

**Ages, Occupations, and Favorite Formulas**

| Name  | Age | Occupation  | F.V|
|-------|----:|-------------|
| Alice |  28 | *Engineer*    | $n!$ |
| Bob   |  34 | *Musician*    | $3:2$ |
| Carol |  41 | *Mathematician* | $sqrt(2)$


# Code

Here is a snippet of inline code: `primes = []`

And below is a block of code:

```
def factorial(n):
    if n == 0:
        return 1
    else:
        return n * factorial(n - 1)
```

Multiparagaph blocks as displayed below require a bit more care.  By definition a block in XMarkdown is a sequence of nonempty lines with at least one empty line above and one below.  So put your text between backticks as below, select it, and type `cmd-]` to indent it by two spaces.  Why does this work? It is because a line consisting of two spaces is not empty.  You can see that from the coloring of the text.

```
    import math

    def first_n_primes(N):
        if N <= 0:
            return []

        primes = [2]
        candidate = 3

        while len(primes) < N:
            limit = math.isqrt(candidate)
            isprime = True

            for p in primes:
                if p > limit:
                    break
                if candidate % p == 0:
                    isprime = False
                    break

            if isprime:
                primes.append(candidate)

            candidate += 2

        return primes


    if __name__ == "__main__":
        N = int(input("How many primes? "))
        for p in first_n_primes(N):
            print(p)
```

# Math

Pythagoras sez: $a^2 + b^2 = c^2$.

The Schwarzschild radius of an uncharged, non-rotating black hole is

$$
r_s = rac{2GM}{c^2}
$$

where $G$ is Newton’s gravitational constant, $M$ is the mass, and $c$ is the speed of light.




"""


textw =
    """


!! XMarkdown TOC Demo

# Stuff

- **some of its history**

## More stuff

- @[red Introduce] notions that will be studied in detail in what follows.

@[hrule]

# Lists

. This

. That

  . Foo

  . Bar



Another list:

. This

. That

  . Foo

  . Bar

# Links and images

I read the [New York Times](https://nytimes.com) every day.

![Divorce party](https://imagedelivery.net/9U-0Y4sEzXlO6BXzTnQnYQ/663d702e-ba37-4227-1019-85fe74261900/public)


# Type Theory

*Type theory* brings together programming, logic, and mathematics.
 We outline



# Mathematics

Pythagoras said that $z^2 = x^2 + y^2$.

Newton said that inline: $\\int_0^1 x^2 dx = \\frac{1}{3}$.

Block math single-line: $$\\rho \\propto \\frac{1}{M^2}$$

Block math multi-line:

$$
\\rho \\propto \\frac{1}{M^2}
$$

# Code


Here is some inline code: `a[0] = $1`.

Here is some Python code:

```
def factorial(n):
    if n == 0:
        return 1
    else:
        return n * factorial(n - 1)
```

# Tables

| Name  | Age | Occupation    |
|-------|----:|:-------------:|
| Alice |  29 | Engineer      |
| Bob   |  34 | Musician      |
| Carol |  41 | $a^2+b^2$     |

 """

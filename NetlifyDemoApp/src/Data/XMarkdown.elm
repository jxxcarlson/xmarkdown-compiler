module Data.XMarkdown exposing (text)


text =
    """
# Plain Text

The Schwarzschild radius is one of the simplest and most important quantities in black-hole physics. It is the radius of the event horizon of a non-rotating, uncharged black hole.

# Links

I read the [New York Times](https://nytimes.com) every day.

# Images

![Divorce party — click to expand width:400](https://imagedelivery.net/9U-0Y4sEzXlO6BXzTnQnYQ/663d702e-ba37-4227-1019-85fe74261900/public)

The element `[...]` hold the caption for the image as well as optional properties such as `width:400`.


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


# Ordinary (non-compact) lists

Use "-" as the prefix for itemized lists:

- G is Newton’s gravitational constant. G is Newton’s gravitational constant.G is Newton’s gravitational constant.

- G is the mass of the object.

- c is the speed of light.

Use "." as the prefix for numbered lists:

. G is Newton’s gravitational constant. G is Newton’s gravitational constant. G is Newton’s gravitational constant.

. G is the mass of the object.

. c is the speed of light.


# Tables

| Name  | Age | Occupation  |
|-------|----:|-------------|
| Alice |  $x^{29}$ | *Engineer*    |
| Bob   |  34 | Musician    |
| Carol |  41 | Mathematician |


| Measure| Bass  | Figures | R.N. |  Notes |
|---|---|---|---|---|
| m. 1 | C | (root) | I | C - E - G - C |
| m. 2 | C | $\\begin{smallmatrix} 6 \\\\ 4 \\\\ 2 \\end{smallmatrix}$ | $\\text{ii}^{\\varnothing}{}_{2}^{4}$ (or IV/I) | C - D - F - A |
| m. 3 | B | $\\begin{smallmatrix} 6 \\\\ 5 \\end{smallmatrix}$ | V₅⁶ | B - D - G - F |
| m. 4 | C | (root) | I | C - E - G - C |
| m. 5 | A | 6 | vi₆ | A - C - E - A |
| m. 6 | D | $\\begin{smallmatrix} 6 \\\\ 5 \\end{smallmatrix}$ | V₅⁶/V | D - F$\\sharp$ - A - C |

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
r_s = \\frac{2GM}{c^2}
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

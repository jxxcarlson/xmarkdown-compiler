# Scripta Markup Language Specification

**Draft Version 0.1a**

## Overview

Scripta is a markup language designed for creating structured documents with mathematical content, real-time rendering, and interactive elements. The language uses:

- **Block-level syntax** for document structure (sections, lists, code blocks, equations)
- **Inline-level syntax** for text formatting and special content (bold, italics, math, code)
- **Indentation-based hierarchy** for organizing document structure
- **Three core inline delimiters**: square brackets `[]` for functions, dollar signs `$` for math, backticks `` ` `` for code

---

## 1. Inline Syntax

### 1.1 Function Calls

The primary inline mechanism uses square brackets:

```
[functionName arguments...]
```

**Rules:**
- Function name immediately follows `[` with no space
- Space after `[` is an error: `[ text]` fails
- Arguments are separated by spaces or nested brackets
- Functions can be nested: `[b [i text]]`

**Common formatting functions:**

| Syntax | Description |
|--------|-------------|
| `[b text]` | Bold |
| `[i text]` | Italic |
| `[u text]` | Underline |
| `[red text]` | Red text |
| `[blue text]` | Blue text |
| `[large text]` | Larger font |
| `[small text]` | Smaller font |
| `[code text]` | Inline code |
| `[term word]` | Terminology |

**Link functions:**

| Syntax | Description |
|--------|-------------|
| `[link text url]` | Hyperlink |
| `[ilink text anchor]` | Internal link |
| `[anchor label]` | Anchor target |

**Reference functions:**

| Syntax | Description |
|--------|-------------|
| `[ref label]` | Cross-reference |
| `[eqref label]` | Equation reference |
| `[bibitem label]` | Bibliography item |
| `[citation author]` | Citation |

**Other inline elements:**

| Syntax | Description |
|--------|-------------|
| `[hrule]` | Horizontal rule |
| `[br]` | Line break |
| `[image url]` | Image |
| `[iframe url]` | Embedded iframe |
| `[center text]` | Centered text |

### 1.2 Inline Math

Two equivalent syntaxes for inline math:

```
$a^2 + b^2 = c^2$
\(a^2 + b^2 = c^2\)
```

Math content is rendered via KaTeX. All LaTeX math commands are supported within math delimiters.

### 1.3 Inline Code

```
`function(x)`
```

Text between backticks is rendered as monospace code.

### 1.4 Plain Text

Any text not enclosed in special delimiters is treated as plain text.

---

## 2. Block Syntax

### 2.1 Paragraphs

Plain text separated by blank lines forms paragraphs:

```
This is the first paragraph with [b bold] text.

This is the second paragraph with $x^2$ math.
```

### 2.2 Section Headers

**Markdown-style (numbered):**

```
# Section Title
## Subsection Title
### Sub-subsection Title
```

**Markdown-style (unnumbered):**

```
* Section Title
** Subsection Title
```

**Pipe-style:**

```
| section
Section Title

| section*
Unnumbered Section Title
```

### 2.3 Pipe-Prefixed Blocks

General block syntax:

```
| blockname arg1 arg2 key:value
  content line 1
  content line 2
```

**Components:**
- `blockname` - the block type
- `arg1 arg2` - positional arguments (space-separated)
- `key:value` - property pairs

### 2.4 Ordinary Blocks (Parsed Content)

These blocks have their content parsed for inline expressions:

| Block Type | Description |
|------------|-------------|
| `| section` | Document section |
| `| section*` | Unnumbered section |
| `| item` | List item |
| `| numbered` | Numbered list item |
| `| theorem` | Theorem environment |
| `| lemma` | Lemma environment |
| `| definition` | Definition environment |
| `| quotation` | Block quote |
| `| box` | Decorative box |
| `| center` | Centered text |
| `| title` | Document title |
| `| banner` | Banner/header |
| `| contents` | Table of contents marker |
| `| list` | List container |

**Example:**

```
| theorem Pythagoras
If $a$, $b$, $c$ are sides of a right triangle
with hypotenuse $c$, then $a^2 + b^2 = c^2$.
```

### 2.5 Verbatim Blocks (Unparsed Content)

These blocks preserve content literally without parsing inline expressions:

| Block Type | Description |
|------------|-------------|
| `| code` | Source code |nnnn``````````````````````````````1
| `| math` | Display math |
| `| equation` | Numbered equation |
| `| aligned` | Aligned equations |
| `| array` | Array/matrix |
| `| table` | Table |
| `| chart` | Chart definition |
| `| svg` | SVG graphics |
| `| tikz` | TikZ diagrams |
| `| verse` | Poetry/verse |
| `| verbatim` | Preformatted text |

**Example:**

```
| equation label:pythagoras
a^2 + b^2 = c^2
```

### 2.6 Shorthand Block Syntax

| Syntax | Equivalent |
|--------|------------|
| `- text` | `| item` (list item) |
| `. text` | `| numbered` (numbered item) |
| ``` ``` | `| code` (code block) |
| `$$` | `| math` (math block) |

**Code block example:**

````
```
def factorial(n):
    return 1 if n <= 1 else n * factorial(n-1)
```
````

**Math block example:**

```
$$
\int_0^\infty e^{-x^2} dx = \frac{\sqrt{\pi}}{2}
$$
```

---

## 3. Block Properties and Arguments

Blocks can have positional arguments and key-value properties:

```
| theorem Pythagoras Senior
| equation label:pythagoras numbered
| image width:400 caption:My Figure
```

**Parsing:**
- Words after block name are positional arguments
- `key:value` pairs become properties
- Properties are accessible during rendering

**Common properties:**

| Property | Description |
|----------|-------------|
| `label:name` | Cross-reference target |
| `numbered` | Enable numbering |
| `width:n` | Width in pixels |
| `caption:text` | Caption text |

---

## 4. Document Structure

### 4.1 Indentation

Indentation creates hierarchy:

```
| list
  Item at level 1

    Item at level 2
    Another at level 2

  Back to level 1
```

### 4.2 Block Continuation

A block continues until:
- A blank line followed by a new block prefix
- A change in indentation level
- For verbatim blocks: the closing delimiter

### 4.3 Document Hierarchy

Sections form a tree structure based on heading levels:

```
# Introduction          (level 1)

Content here

## Background           (level 2, child of Introduction)

More content

## Methods              (level 2, sibling of Background)

### Data Collection     (level 3, child of Methods)
```

---

## 5. Cross-References

### 5.1 Creating Labels

Add a `label` property to any block:

```
| theorem label:pythagoras
...

| equation label:euler
e^{i\pi} + 1 = 0
```

### 5.2 Referencing Labels

```
See [ref pythagoras] for the proof.
Equation [eqref euler] is beautiful.
```

---

## 6. Complete Example

```
| title
Introduction to Type Theory

| banner
A Course in Foundations

# Overview

Type theory brings together [b programming], [b logic],
and [b mathematics]. The [term lambda calculus] provides
the foundation.

## Lambda Calculus

An expression like $\lambda x. x + 1$ is called an
[term abstraction]. We write function application as
$f\ x$ or $(f\ x)$.

| theorem Church-Rosser label:cr
If $M \to^* N_1$ and $M \to^* N_2$, then there exists
$P$ such that $N_1 \to^* P$ and $N_2 \to^* P$.

See [ref cr] for the confluence property.

| equation label:beta
(\lambda x. M)\ N \to M[x := N]

The beta reduction rule [eqref beta] is fundamental.

| code
-- Haskell example
identity :: a -> a
identity x = x

## Further Reading

- [link TAPL https://www.cis.upenn.edu/~bcpierce/tapl/]
- [link HoTT Book https://homotopytypetheory.org/book/]
```

---

## 7. Error Handling

The parser provides error recovery for common mistakes:

| Error | Display |
|-------|---------|
| `[????]` | Empty brackets |
| `[?]` | Extra right bracket |
| `[...?` | Missing right bracket |
| `$?$` | Unmatched dollar sign |
| `` `?` `` | Unmatched backtick |

Errors are highlighted in the rendered output to aid debugging.

---

## Sources

This specification was derived from analysis of the following source files in the scripta-compiler-v2 codebase:

**Core Parser Implementation:**
- `src/Scripta/Tokenizer.elm` - Tokenization logic (666 lines)
- `src/Scripta/Expression.elm` - Expression parser (759 lines)
- `src/Scripta/PrimitiveBlock.elm` - Block parsing (191 lines)
- `src/Scripta/Match.elm` - Bracket matching (173 lines)

**Language Definitions:**
- `src/Generic/Language.elm` - AST type definitions
- `src/Generic/PrimitiveBlock.elm` - Generic block parser
- `src/Scripta/Regex.elm` - Section header patterns

**Pipeline & Rendering:**
- `src/Generic/Pipeline.elm` - Compilation pipeline
- `src/Render/Block.elm` - Block rendering

**Test Files:**
- `tests/ToExpressionBlockTest.elm` - Example documents
- `tests/ToForestAndAccumulatorTest.elm` - Pipeline tests

**Demo Data:**
- `DemoSimple/src/Data/M.elm` - Sample documents

**Documentation:**
- `docs/pipeline.md` - Pipeline overview

---

## Summary

1. **Inline Syntax** - Function calls `[name args]`, math `$...$` or `\(...\)`, code `` `...` ``
2. **Block Syntax** - Pipe-prefixed blocks `| blockname`, section headers `#`/`*`, shorthand `-`, `.`, ``` ``` ```, `$$`
3. **Ordinary vs Verbatim Blocks** - Ordinary blocks parse inline expressions; verbatim blocks preserve content literally
4. **Properties & Arguments** - `| block arg1 key:value` syntax
5. **Document Structure** - Indentation-based hierarchy, section nesting
6. **Cross-References** - `label:name` properties with `[ref name]` references
7. **Error Handling** - Parser recovery for bracket mismatches

### Sources Used

- `src/Scripta/Tokenizer.elm` - Tokenization logic
- `src/Scripta/Expression.elm` - Expression parser
- `src/Scripta/PrimitiveBlock.elm` - Block parsing
- `src/Scripta/Match.elm` - Bracket matching
- `src/Generic/Language.elm` - AST definitions
- `tests/ToExpressionBlockTest.elm` - Example documents
- `DemoSimple/src/Data/M.elm` - Sample documents
- `docs/pipeline.md` - Pipeline documentation

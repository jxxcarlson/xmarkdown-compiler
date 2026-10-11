# Changelog

## xmarkdown-compiler 2.1.5 — 2026-10-10

Requires `jxxcarlson/etex` 1.0.8. The ETeX releases below are what make math
like `O(\|\delta\|^4)` work; this release adds LaTeX export support for the
new commands.

| Release | What changed |
|---|---|
| ETeX 1.0.6 | `ldots`, `cdots`, `vdots`, `ddots` and `dots` (plus amsmath's `dotsb` … `dotso`) and about 240 more KaTeX commands; 20 names removed that KaTeX doesn't define (`sech`, `lcm`, `scr`, …), which showed as red errors. All 736 names are checked against KaTeX 0.16.9. |
| ETeX 1.0.7 | `\|` fixed: a backslash followed by any character that isn't a letter or digit (`\| \! \: \> \# \& \_`, …) passes through unchanged. Before, it was an ETeX error. |
| ETeX 1.0.8 | ETeX no longer silently drops the rest of a formula at the first character it can't parse: `x in [0,1) cup (2,3]` used to become `x \in [0,1`. |
| xmarkdown-compiler 2.1.5 | Uses ETeX 1.0.8, and the LaTeX/PDF export defines the new commands. |

### Details

**Unmatched parentheses (ETeX 1.0.8).** An unmatched `(` or `)` is now kept
as an ordinary symbol, as in TeX, so half-open intervals work. Anything else
ETeX can't parse becomes an `[ETeX error]`, which falls back to the source
text instead of disappearing. Whether a `(` is closed is decided by looking
ahead for a matching `)`. An earlier, unreleased version used backtracking,
which got exponentially slower with each unclosed parenthesis. The released
version handles 200 unclosed parentheses instantly.

**Commands ETeX deliberately doesn't treat as names.** Single letters and
ordinary words (`P`, `R`, `S`, `it`, `set`, `real`, `empty`, …), delimiter
sizes (`left`, `right`, `big`, …), colours, font sizes, TeX primitives and
HTML commands. Otherwise `P(A)` would become `\P(A)`, the ¶ sign. All of these
still work when written with a backslash.

**LaTeX export (2.1.5).**

- The preamble loads `mathtools` whenever there's math, and `braket`, `bm`,
  `esint` and `arydshln` only when the document uses them.
- The remaining commands get a `\providecommand` definition, again only when
  used: capital Greek, `argmax`, the colon relations, a few rare arrows.
- A few definitions are approximations, e.g. `\oiiint` prints as `\iiint`.
- A document using all 247 new commands was exported through xmarkdown's own
  export code and compiled under LuaLaTeX with no errors.

**Tests.** ETeX: 89 passing; xmarkdown: 225 passing. Three xmarkdown tests used
`a\:b` as an example of math ETeX rejects. ETeX now accepts it, so they use
`a"b` instead.

## xmarkdown-compiler 2.1.4 — 2026-10-09

Requires `jxxcarlson/etex` 1.0.5 (code identical to 1.0.4). A function call
nested inside another function's arguments is converted:
`o(frac(x,log x))` → `o(\frac{x}{\log x})`. Before, it came out as
`o(\frac(x,\log x))`. The same fix applies to `sqrt(frac(x,y))` →
`\sqrt{\frac{x}{y}}`.

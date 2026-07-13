# CLI

Terminal tools for inspecting the XMarkdown compiler, built on
[albertdahlin/elm-posix](https://package.elm-lang.org/packages/albertdahlin/elm-posix/latest/)
(requires the `elm-cli` runner: `npm install -g elm-posix`).

## PXB — print primitive blocks

Parses an XMarkdown file with `Parser.Block.PrimitiveBlock.parse` and prints
the resulting blocks (heading, line number, indent, args, properties, body):

```bash
cd CLI
elm-cli run src/PXB.elm test/xa.txt
```

## History

This directory once also held `PMB`/`PLB` (primitive-block printers for the
M and MicroLaTeX languages) and `Diff`/`Benchmark` (benchmarks for the
differential compiler). Those languages and subsystems no longer exist in
this repo — the tools were removed in July 2026.

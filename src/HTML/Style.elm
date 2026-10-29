module HTML.Style exposing (defaultCss, katexHead)

{-| The fixed parts of an exported page: the default stylesheet and the
KaTeX head elements. The stylesheet targets only `xm-*` classes and plain
elements, so a page can be restyled by replacing it.
-}


katexVersion : String
katexVersion =
    "0.16.9"


katexBase : String
katexBase =
    "https://cdn.jsdelivr.net/npm/katex@" ++ katexVersion ++ "/dist/"


{-| KaTeX and mhchem from the CDN, and a script that typesets every `.xm-math`
element once they have loaded (deferred scripts run before
`DOMContentLoaded`). Only those elements are typeset, so a `$` in prose is
never read as math. KaTeX trusts only http(s) and relative urls (`\\href`),
so a formula cannot carry a `javascript:` link.
-}
katexHead : String
katexHead =
    String.join "\n"
        [ "<link rel=\"stylesheet\" href=\"" ++ katexBase ++ "katex.min.css\">"
        , "<script defer src=\"" ++ katexBase ++ "katex.min.js\"></script>"
        , "<script defer src=\"" ++ katexBase ++ "contrib/mhchem.min.js\"></script>"
        , "<script>"
        , "document.addEventListener(\"DOMContentLoaded\", function () {"
        , "  document.querySelectorAll(\".xm-math\").forEach(function (el) {"
        , "    katex.render(el.textContent, el, { displayMode: el.dataset.display === \"true\", throwOnError: false, trust: function (context) { return [\"http\", \"https\", \"_relative\"].includes(context.protocol); } });"
        , "  });"
        , "});"
        , "</script>"
        ]


defaultCss : String
defaultCss =
    String.join "\n"
        [ "body { margin: 0; padding: 2rem 1rem; background: #fff; color: #222; font-family: Georgia, \"Times New Roman\", serif; font-size: 18px; line-height: 1.55; }"
        , ".xm-document { max-width: 42rem; margin: 0 auto; }"
        , ".xm-title-block { margin-bottom: 2rem; }"
        , ".xm-title { margin-bottom: 0.25rem; }"
        , ".xm-authors, .xm-date { margin: 0.25rem 0; color: #555; }"
        , ".xm-toc { margin-bottom: 2rem; }"
        , ".xm-toc ul { list-style: none; padding-left: 1.25rem; margin: 0.2rem 0; }"
        , ".xm-toc > ul { padding-left: 0; }"
        , ".xm-toc a { text-decoration: none; }"
        , ".xm-section-number { margin-right: 0.25em; }"
        , ".xm-quotation { margin: 1rem 0; padding-left: 1rem; border-left: 3px solid #ccc; color: #444; }"
        , ".xm-verse { margin: 1rem 0 1rem 1.5rem; }"
        , ".xm-verse-line { white-space: pre-wrap; }"
        , ".xm-verse-blank { height: 1em; }"
        , ".xm-figure { margin: 1.5rem 0; text-align: center; }"
        , ".xm-figure img, img.xm-image { max-width: 100%; height: auto; }"
        , ".xm-figure figcaption { font-size: 0.9em; color: #555; }"
        , ".xm-table { border-collapse: collapse; margin: 1rem 0; }"
        , ".xm-table th, .xm-table td { border: 1px solid #ccc; padding: 0.3rem 0.6rem; }"
        , ".xm-code { background: #f5f5f5; padding: 0.75rem; overflow-x: auto; font-size: 0.85em; }"
        , "code { font-family: Menlo, Consolas, monospace; }"
        , "div.xm-math { overflow-x: auto; }"
        , ".xm-block { margin: 1rem 0; }"
        , ".xm-unsupported { color: #888; }"
        , "hr.xm-hrule { border: none; border-top: 1px solid #ccc; margin: 2rem 0; }"
        ]

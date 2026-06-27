module Scripta.APISimple exposing (compile)

{-| Use `Scripta.APISimple.compile` to transform XMarkdown source text to elm-ui HTML.
You will need the following imports in your Elm file:

    import Scripta.APISimple
    import Scripta.Msg exposing (MarkupMsg)
    import Element exposing (Element)

Your `Msg` type definition should read:

    type Msg
        =  ...
        | Render MarkupMsg

@docs compile

-}

import Element exposing (Element)
import Scripta.Compiler
import Scripta.Msg exposing (MarkupMsg)
import Scripta.Types exposing (CompilerParameters)


{-| Compile source text to elm-ui HTML. The width of the rendered text in pixels is
defined by docWidth. The editCount should be 0 for a static document. For documents
in a live editing context, the editCount should be increment after each edit.
This ensures that the rendered text is properly updated.
-}
compile : CompilerParameters -> String -> List (Element MarkupMsg)
compile params sourceText =
    Scripta.Compiler.compile params (String.lines sourceText) |> Scripta.Compiler.view params.docWidth

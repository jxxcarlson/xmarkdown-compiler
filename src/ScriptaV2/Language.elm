module ScriptaV2.Language exposing (Language(..), ExpressionBlock, toString)

{-|

@docs Language, ExpressionBlock, toString

-}

import Generic.Forest
import Generic.Language


{-| -}
type Language
    = ScriptaLang
    | SMarkdownLang


{-| -}
type alias ExpressionBlock =
    Generic.Language.ExpressionBlock


{-| -}
toString : Language -> String
toString lang =
    case lang of
        ScriptaLang ->
            "Scripta"

        SMarkdownLang ->
            "SMarkdown"


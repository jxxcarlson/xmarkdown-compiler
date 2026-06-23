module ScriptaV2.Language exposing (Language(..), ExpressionBlock, toString)

{-|

@docs Language, ExpressionBlock, toString

-}

import Generic.Language


{-| -}
type Language
    = SMarkdownLang


{-| -}
type alias ExpressionBlock =
    Generic.Language.ExpressionBlock


{-| -}
toString : Language -> String
toString lang =
    case lang of
        SMarkdownLang ->
            "SMarkdown"


module Parser.Inline.Symbol exposing (Symbol(..), convertTokens)

import Maybe.Extra
import Parser.Inline.Token exposing (Token(..))


type Symbol
    = LBracket
    | RBracket
    | LParen
    | RParen
    | SBold
    | SItalic
    | SImage
    | M
    | ML
    | MR
    | C


convertTokens : List Token -> List Symbol
convertTokens tokens =
    List.map toSymbol tokens |> Maybe.Extra.values


toSymbol : Token -> Maybe Symbol
toSymbol token =
    case token of
        LB _ ->
            Just LBracket

        RB _ ->
            Just RBracket

        LP _ ->
            Just LParen

        Bold _ ->
            Just SBold

        Italic _ ->
            Just SItalic

        Image _ ->
            Just SImage

        RP _ ->
            Just RParen

        MathToken _ ->
            Just M

        MathTokenLeft _ ->
            Just ML

        MathTokenRight _ ->
            Just MR

        CodeToken _ ->
            Just C

        _ ->
            Nothing

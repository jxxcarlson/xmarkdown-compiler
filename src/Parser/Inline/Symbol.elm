module Parser.Inline.Symbol exposing (Symbol(..), convertTokens, value)

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
    | SAT
    | M
    | ML
    | MR
    | C


value : Symbol -> Int
value symbol =
    case symbol of
        LBracket ->
            1

        RBracket ->
            -1

        LParen ->
            1

        RParen ->
            -1

        SBold ->
            0

        SItalic ->
            0

        SImage ->
            1

        SAT ->
            1

        M ->
            0

        ML ->
            0

        MR ->
            0

        C ->
            0


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

        AT _ ->
            Just SAT

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

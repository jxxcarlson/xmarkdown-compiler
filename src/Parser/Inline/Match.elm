module Parser.Inline.Match exposing (reducible)

import Parser.Inline.Symbol exposing (Symbol(..))


reducible : List Symbol -> Bool
reducible symbols =
    case List.head symbols of
        Just M ->
            List.head (List.reverse (List.drop 1 symbols)) == Just M

        Just ML ->
            List.head (List.reverse (List.drop 1 symbols)) == Just MR

        Just C ->
            List.head (List.reverse (List.drop 1 symbols)) == Just C

        Just SBold ->
            List.head (List.reverse (List.drop 1 symbols)) == Just SBold

        Just SItalic ->
            List.head (List.reverse (List.drop 1 symbols)) == Just SItalic

        Just SImage ->
            symbols == [ SImage, LBracket, RBracket, LParen, RParen ]

        Just LBracket ->
            if symbols == [ LBracket, RBracket, LParen, RParen ] then
                True

            else
                False

        _ ->
            reducibleF symbols


reducibleF : List Symbol -> Bool
reducibleF symbols =
    symbols
        == [ LBracket, RBracket, LParen, RParen ]
        || symbols
        == [ LParen, RParen ]



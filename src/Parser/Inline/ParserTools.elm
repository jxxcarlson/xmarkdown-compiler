module Parser.Inline.ParserTools exposing
    ( Problem(..)
    , StringData
    , text
    )

import Parser.Advanced as Parser exposing ((|.), (|=))


type Problem
    = ExpectingPrefix
    | ExpectingSymbol String
    | ExpectingImageStart


type alias Parser a =
    Parser.Parser () Problem a


type alias StringData =
    { begin : Int, end : Int, content : String }


{-| Get the longest string
whose first character satisfies `prefix` and whose remaining
characters satisfy `continue`. ParserTests:

    line =
        textPS (\c -> Char.isAlpha) [ '\n' ]

recognizes lines that start with an alphabetic character.

-}
text : (Char -> Bool) -> (Char -> Bool) -> Parser StringData
text prefix continue =
    Parser.succeed (\start finish content -> { begin = start, end = finish, content = String.slice start finish content })
        |= Parser.getOffset
        |. Parser.chompIf (\c -> prefix c) ExpectingPrefix
        |. Parser.chompWhile (\c -> continue c)
        |= Parser.getOffset
        |= Parser.getSource



-- LOOP

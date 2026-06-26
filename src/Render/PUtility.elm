module Render.PUtility exposing (parseItem)

import Parser exposing ((|.), (|=), Parser)


itemParser : String -> Parser String
itemParser item =
    Parser.succeed (\start end src -> String.slice start end src)
        |. Parser.chompUntil (item ++ "=")
        |. Parser.symbol (item ++ "=\"")
        |= Parser.getOffset
        |. Parser.chompUntil "\""
        |= Parser.getOffset
        |= Parser.getSource


{-|

    > str = """<iframe src="https://www.desmos.com/calculator/ycaswggsgb?embed" width="500" height="500" style="border: 1px solid #ccc" frameborder=0></iframe>"""
    > parseItem "src" str
      Just  "https://www.desmos.com/calculator/ycaswggsgb?embed"

-}
parseItem : String -> String -> Maybe String
parseItem item str =
    case Parser.run (itemParser item) str of
        Ok output ->
            Just output

        Err _ ->
            Nothing

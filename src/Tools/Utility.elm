module Tools.Utility exposing
    ( compressWhitespace
    , findOrdinaryTagAtEnd
    , replaceLeadingDashSpace
    , replaceLeadingDotSpace
    , replaceLeadingGreaterThanSign
    )

import Regex


ordinaryTagAtEndRegex : Regex.Regex
ordinaryTagAtEndRegex =
    Maybe.withDefault Regex.never <|
        Regex.fromString ".*\n| .*$"


findOrdinaryTagAtEnd : String -> Maybe String
findOrdinaryTagAtEnd string =
    Regex.find ordinaryTagAtEndRegex string
        |> List.map .match
        |> List.reverse
        |> List.head
        |> Maybe.map String.trim


replaceLeadingDotSpace : String -> String
replaceLeadingDotSpace str =
    let
        regex =
            Regex.fromString "^\\. " |> Maybe.withDefault Regex.never
    in
    Regex.replace regex (\_ -> "") str


replaceLeadingDashSpace : String -> String
replaceLeadingDashSpace str =
    let
        regex =
            Regex.fromString "^- " |> Maybe.withDefault Regex.never
    in
    Regex.replace regex (\_ -> "") str


replaceLeadingGreaterThanSign : String -> String
replaceLeadingGreaterThanSign str =
    let
        regex =
            Regex.fromString "^> " |> Maybe.withDefault Regex.never
    in
    Regex.replace regex (\_ -> "") str


compressWhitespace : String -> String
compressWhitespace string =
    userReplace "\\s\\s+" (\_ -> " ") string


userReplace : String -> (Regex.Match -> String) -> String -> String
userReplace regexString replacer string =
    case Regex.fromString regexString of
        Nothing ->
            string

        Just regex ->
            Regex.replace regex replacer string



-- > firstMatch "\\[subheading (.+?)\\]" "[subheading Intro]"
-- Just "Intro" : Maybe String

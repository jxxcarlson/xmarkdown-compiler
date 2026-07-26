module Tools.Utility exposing
    ( findOrdinaryTagAtEnd
    , replaceLeadingDashSpace
    , replaceLeadingGreaterThanSign
    , replaceLeadingNumberedMarker
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


{-| Strip a leading ordered-list marker: XMarkdown's ". " or standard
Markdown's "1. ", "2) ", etc. Only the marker is removed, so periods later in
the line survive.
-}
replaceLeadingNumberedMarker : String -> String
replaceLeadingNumberedMarker str =
    let
        regex =
            Regex.fromString "^(\\d+[.)]|\\.) " |> Maybe.withDefault Regex.never
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

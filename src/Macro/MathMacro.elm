module Macro.MathMacro exposing
    ( Deco(..)
    , MathExpr(..)
    , Problem
    )

import Parser.Advanced as PA
    exposing
        ( (|.)
        , (|=)
        , Step(..)
        , Token(..)
        , chompIf
        , chompWhile
        , getOffset
        , getSource
        , lazy
        , loop
        , map
        , oneOf
        , succeed
        , symbol
        )



-- TYPES


type MathExpr
    = AlphaNum String
    | F0 String
    | Arg (List MathExpr)
    | Sub Deco
    | Super Deco
    | Param Int
    | WS
    | MathSpace
    | MathSmallSpace
    | MathMediumSpace
    | LeftMathBrace
    | RightMathBrace
    | MathSymbols String
    | Macro String (List MathExpr)
    | Expr (List MathExpr)


type Deco
    = DecoM MathExpr
    | DecoI Int



-- RESUlT: [Macro "frac" [Arg [Macro "baar" [Arg [AlphaNum "X"]]],Arg [Macro "baar" [Arg [AlphaNum "Y"]]]]]


type Problem
    = ExpectingLeftBrace
    | ExpectingAlpha
    | ExpectingNotAlpha
    | ExpectingInt
    | InvalidNumber
    | ExpectingMathSmallSpace
    | ExpectingMathMediumSpace
    | ExpectingMathSpace
    | ExpectingLeftMathBrace
    | ExpectingRightMathBrace
    | ExpectingUnderscore
    | ExpectingCaret
    | ExpectingSpace
    | ExpectingRightBrace
    | ExpectingHash
    | ExpectingBackslash


type alias MathExprParser a =
    PA.Parser () Problem a



-- PARSER


macroParser =
    succeed Macro
        |. symbol (Token "\\" ExpectingBackslash)
        |= alphaNumParser_
        |= many argParser


mathExprParser =
    oneOf
        [ mathMediumSpaceParser
        , mathSmallSpaceParser
        , mathSpaceParser
        , leftBraceParser
        , rightBraceParser
        , macroParser
        , mathSymbolsParser
        , lazy (\_ -> argParser)
        , paramParser
        , whitespaceParser
        , alphaNumParser
        , f0Parser
        , subscriptParser
        , superscriptParser
        ]


mathSymbolsParser =
    (succeed String.slice
        |= getOffset
        |. chompIf (\c -> not (Char.isAlpha c) && not (List.member c [ '_', '^', '#', '\\', '{', '}' ])) ExpectingNotAlpha
        |. chompWhile (\c -> not (Char.isAlpha c) && not (List.member c [ '_', '^', '#', '\\', '{', '}' ]))
        |= getOffset
        |= getSource
    )
        |> PA.map MathSymbols


mathSpaceParser : PA.Parser c Problem MathExpr
mathSpaceParser =
    succeed MathSpace
        |. symbol (Token "\\ " ExpectingMathSpace)


mathSmallSpaceParser : PA.Parser c Problem MathExpr
mathSmallSpaceParser =
    succeed MathSmallSpace
        |. symbol (Token "\\," ExpectingMathSmallSpace)


mathMediumSpaceParser : PA.Parser c Problem MathExpr
mathMediumSpaceParser =
    succeed MathMediumSpace
        |. symbol (Token "\\;" ExpectingMathMediumSpace)


leftBraceParser : PA.Parser c Problem MathExpr
leftBraceParser =
    succeed LeftMathBrace
        |. symbol (Token "\\{" ExpectingLeftMathBrace)


rightBraceParser : PA.Parser c Problem MathExpr
rightBraceParser =
    succeed RightMathBrace
        |. symbol (Token "\\}" ExpectingRightMathBrace)


argParser : PA.Parser () Problem MathExpr
argParser =
    (succeed identity
        |. symbol (Token "{" ExpectingLeftBrace)
        |= lazy (\_ -> many mathExprParser)
    )
        |. symbol (Token "}" ExpectingRightBrace)
        |> PA.map Arg


whitespaceParser =
    symbol (Token " " ExpectingSpace) |> PA.map (\_ -> WS)


alphaNumParser : PA.Parser c Problem MathExpr
alphaNumParser =
    alphaNumParser_ |> PA.map AlphaNum


alphaNumParser_ : PA.Parser c Problem String
alphaNumParser_ =
    succeed String.slice
        |= getOffset
        |. chompIf Char.isAlpha ExpectingAlpha
        |. chompWhile Char.isAlphaNum
        |= getOffset
        |= getSource


f0Parser : PA.Parser () Problem MathExpr
f0Parser =
    second (symbol (Token "\\" ExpectingBackslash)) alphaNumParser_
        |> PA.map F0


paramParser =
    (succeed identity
        |. symbol (Token "#" ExpectingHash)
        |= PA.int ExpectingInt InvalidNumber
    )
        |> PA.map Param


subscriptParser =
    (succeed identity
        |. symbol (Token "_" ExpectingUnderscore)
        |= decoParser
    )
        |> PA.map Sub


superscriptParser =
    (succeed identity
        |. symbol (Token "^" ExpectingCaret)
        |= decoParser
    )
        |> PA.map Super


decoParser =
    oneOf [ numericDecoParser, lazy (\_ -> mathExprParser) |> PA.map DecoM ]


numericDecoParser =
    PA.int ExpectingInt InvalidNumber |> PA.map DecoI



-- PRINT


printList : List MathExpr -> String
printList exprs =
    List.map print exprs |> String.join ""


print : MathExpr -> String
print expr =
    case expr of
        AlphaNum str ->
            str

        LeftMathBrace ->
            "\\{"

        RightMathBrace ->
            "\\}"

        MathSmallSpace ->
            "\\,"

        MathMediumSpace ->
            "\\;"

        MathSpace ->
            "\\ "

        F0 str ->
            "\\" ++ str

        Param k ->
            "#" ++ String.fromInt k

        Arg exprs ->
            enclose (printList exprs)

        Sub deco ->
            -- "_" ++ enclose (printDeco deco)
            "_" ++ printDeco deco

        Super deco ->
            -- "^" ++ enclose (printDeco deco)
            "^" ++ printDeco deco

        MathSymbols str ->
            str

        WS ->
            " "

        Macro name body ->
            "\\" ++ name ++ printList body

        Expr exprs ->
            List.map print exprs |> String.join ""


printDeco : Deco -> String
printDeco deco =
    case deco of
        DecoM expr ->
            print expr

        DecoI k ->
            String.fromInt k



-- HELPERS


second : MathExprParser a -> MathExprParser b -> MathExprParser b
second p q =
    p |> PA.andThen (\_ -> q)


{-| Apply a parser zero or more times and return a list of the results.
-}
many : MathExprParser a -> MathExprParser (List a)
many p =
    loop [] (manyHelp p)


manyHelp : MathExprParser a -> List a -> MathExprParser (Step (List a) (List a))
manyHelp p vs =
    oneOf
        [ succeed (\v -> Loop (v :: vs))
            |= p

        -- |. PA.spaces
        , succeed ()
            |> map (\_ -> Done (List.reverse vs))
        ]


enclose : String -> String
enclose str =
    "{" ++ str ++ "}"

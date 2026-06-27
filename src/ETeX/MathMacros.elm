module ETeX.MathMacros exposing
    ( Deco(..)
    , MacroBody(..)
    , MathExpr(..)
    , MathMacroDict
    , NewCommand(..)
    , Problem
    )

import Dict exposing (Dict)
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
    | MacroName String
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
    | Comma
    | LeftParen
    | RightParen


type Deco
    = DecoM MathExpr
    | DecoI Int


type NewCommand
    = NewCommand MathExpr Int (List MathExpr)


type MacroBody
    = MacroBody Int (List MathExpr)



-- RESUlT: [Macro "frac" [Arg [Macro "baar" [Arg [AlphaNum "X"]]],Arg [Macro "baar" [Arg [AlphaNum "Y"]]]]]
-- evalMacro1 :


type alias MathMacroDict =
    Dict String MacroBody


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
    | ExpectingLeftParen
    | ExpectingRightParen
    | ExpectingComma


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
        , leftParenParser
        , rightParenParser
        , commaParser
        , macroParser
        , mathSymbolsParser
        , lazy (\_ -> argParser)
        , lazy (\_ -> parenthesizedGroupParser)
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
        |. chompIf (\c -> not (Char.isAlpha c) && not (List.member c [ '_', '^', '#', '\\', '{', '}', '(', ')', ',' ])) ExpectingNotAlpha
        |. chompWhile (\c -> not (Char.isAlpha c) && not (List.member c [ '_', '^', '#', '\\', '{', '}', '(', ')', ',' ]))
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


leftParenParser : PA.Parser c Problem MathExpr
leftParenParser =
    succeed LeftParen
        |. symbol (Token "(" ExpectingLeftParen)


rightParenParser : PA.Parser c Problem MathExpr
rightParenParser =
    succeed RightParen
        |. symbol (Token ")" ExpectingRightParen)


commaParser : PA.Parser c Problem MathExpr
commaParser =
    succeed Comma
        |. symbol (Token "," ExpectingComma)


argParser : PA.Parser () Problem MathExpr
argParser =
    (succeed identity
        |. symbol (Token "{" ExpectingLeftBrace)
        |= lazy (\_ -> many mathExprParser)
    )
        |. symbol (Token "}" ExpectingRightBrace)
        |> PA.map Arg


parenthesizedGroupParser : PA.Parser () Problem MathExpr
parenthesizedGroupParser =
    (succeed identity
        |. symbol (Token "(" ExpectingLeftParen)
        |= lazy (\_ -> many mathExprParser)
    )
        |. symbol (Token ")" ExpectingRightParen)
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
        |> PA.map MacroName


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

        MacroName str ->
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

        Comma ->
            ","

        LeftParen ->
            "("

        RightParen ->
            ")"


printDeco : Deco -> String
printDeco deco =
    case deco of
        DecoM expr ->
            print expr

        DecoI k ->
            String.fromInt k



-- HELPERS II
--getArgList: List MathExpr -> List (List MathExpr)
-- HELPERS


second : MathExprParser a -> MathExprParser b -> MathExprParser b
second p q =
    p
        |> PA.andThen (\_ -> q)


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



-- SYMBOL NAMES
-- MAKE FUNCTION NAMES --

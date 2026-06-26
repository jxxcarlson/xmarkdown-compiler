module Generic.TextMacro exposing
    ( Macro
    , buildDictionary
    , expand
    )

import Dict exposing (Dict)
import Generic.ASTTools as AT
import Generic.Language exposing (Expr(..), Expression)
import Generic.TextMacroParser
import List.Extra
import Scripta.Expression


type alias Macro =
    { name : String, vars : List String, body : List Expression }


macroFromString : String -> Maybe Macro
macroFromString str =
    case String.left 1 str of
        "\\" ->
            macroFromMicroLaTeXString str

        "[" ->
            macroFromL0String str

        _ ->
            Nothing


{-|

    Construct a Lambda from a string

-}
macroFromL0String : String -> Maybe Macro
macroFromL0String str =
    str
        |> Scripta.Expression.parse 0
        |> List.head
        |> Maybe.andThen extract


macroFromMicroLaTeXString : String -> Maybe Macro
macroFromMicroLaTeXString macroS =
    Maybe.andThen extract2 (parseMicroLaTeX macroS |> List.head)


extract2 : Expression -> Maybe Macro
extract2 expr =
    case expr of
        Fun name body _ ->
            if name == "newcommand" then
                extract2Aux body

            else
                Nothing

        _ ->
            Nothing


getVars : List Expression -> List String
getVars exprs =
    List.map getVars_ exprs |> List.concat |> List.Extra.unique |> List.sort


getVars_ : Expression -> List String
getVars_ expr =
    case expr of
        Text str _ ->
            getParam str

        Fun _ exprs _ ->
            List.map getVars_ exprs |> List.concat

        _ ->
            []


getParam : String -> List String
getParam str =
    case Generic.TextMacroParser.getParam str of
        Just result ->
            [ result ]

        Nothing ->
            []


extract2Aux body =
    case body of
        (Fun name _ _) :: rest ->
            Just (extract3Aux name rest)

        _ ->
            Nothing



-- extract3Aux : String -> List String -> meta -> Lambda


extract3Aux : String -> List Expression -> { name : String, vars : List String, body : List Expression }
extract3Aux name rest =
    { name = name, vars = getVars rest, body = rest }


extract : Expression -> Maybe Macro
extract expr_ =
    case expr_ of
        Fun "macro" ((Text argString _) :: exprs) _ ->
            case String.words (String.trim argString) of
                name :: rest ->
                    Just { name = name, vars = rest, body = exprs }

                _ ->
                    Nothing

        _ ->
            Nothing


{-| Insert a lambda in the dictionary
-}
insert : Maybe Macro -> Dict String Macro -> Dict String Macro
insert data dict =
    case data of
        Nothing ->
            dict

        Just macro ->
            Dict.insert macro.name macro dict


buildDictionary : List String -> Dict String Macro
buildDictionary lines =
    List.foldl (\line acc -> insert (macroFromString line) acc) Dict.empty lines


{-| Expand the given expression using the given dictionary of lambdas.
-}
expand : Dict String Macro -> Expression -> Expression
expand dict expr =
    case expr of
        Fun name _ _ ->
            case Dict.get name dict of
                Nothing ->
                    expr

                Just macro ->
                    expandWithMacro macro expr

        _ ->
            expr


{-| Substitute a for all occurrences of (Text var ..) in e
-}
subst : Expression -> String -> Expression -> Expression
subst a var body =
    case body of
        Text str _ ->
            if String.trim str == String.trim var then
                -- the trimming is a temporary hack.  Need to adjust the parser
                a

            else if String.contains var str then
                let
                    parts =
                        String.split var str |> List.map (\s -> Text s dummy)
                in
                List.intersperse a parts |> group

            else
                body

        Fun name exprs meta ->
            Fun name (List.map (subst a var) exprs) meta

        _ ->
            body


listSubst : List Expression -> List String -> List Expression -> List Expression
listSubst as_ vars exprs =
    if List.length as_ /= List.length vars then
        exprs

    else
        let
            funcs =
                List.map2 makeF as_ vars
        in
        List.foldl (\func acc -> func acc) exprs funcs


expandWithMacro : Macro -> Expression -> Expression
expandWithMacro macro expr =
    case expr of
        Fun name fArgs _ ->
            if name == macro.name then
                listSubst (fArgs |> filterOutBlanks) macro.vars macro.body |> group

            else
                expr

        _ ->
            expr


{-| Apply a lambda to an expression.
-}
group : List Expression -> Expression
group exprs =
    Fun "group" exprs dummy


makeF : Expression -> String -> (List Expression -> List Expression)
makeF a var =
    List.map (subst a var)



-- FOR TESTING --


parseMicroLaTeX : String -> List Expression
parseMicroLaTeX str =
    Scripta.Expression.parse 0 str



-- HELPERS


filterOutBlanks : List Expression -> List Expression
filterOutBlanks =
    AT.filterExprs (\e -> not (AT.isBlank e))


dummy =
    { begin = 0, end = 0, index = 0, id = "dummyId" }

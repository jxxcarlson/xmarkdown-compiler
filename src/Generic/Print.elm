module Generic.Print exposing (toStringFromList)

{-| Used for debugging with CLI.LOPB
-}

import Generic.Language exposing (Expr(..), Expression)


toStringFromList : List Expression -> String
toStringFromList expressions =
    List.map toString expressions |> String.join ""


toString : Expression -> String
toString expr =
    case expr of
        Fun name expressions _ ->
            let
                body_ =
                    List.map toString expressions |> String.join ""

                body =
                    if body_ == "" then
                        body_

                    else if String.left 1 body_ == "[" then
                        body_

                    else if String.left 1 body_ == " " then
                        body_

                    else
                        " " ++ body_
            in
            "[" ++ name ++ body ++ "]"

        Text str _ ->
            str

        VFun name str _ ->
            case name of
                "math" ->
                    "$" ++ str ++ "$"

                "code" ->
                    "`" ++ str ++ "`"

                _ ->
                    "error: verbatim " ++ name ++ " not recognized"

        ExprList _ _ _ ->
            "[ExprList]"

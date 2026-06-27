module ListSyncTest exposing (suite)

import Either exposing (Either(..))
import Expect
import AST.Language exposing (Expr(..))
import Library.Tree
import Scripta.Compiler
import Test exposing (Test, describe, test)


doc : String
doc =
    "intro\n\n- alpha beta\n- gamma delta\n"


{-| The source text obtained by slicing the document at each Text expression's
[begin, end] span. If RL-sync offsets are correct (absolute document positions),
each slice equals the phrase that produced it — including list items, which are
parsed from marker-stripped substrings and must be shifted to absolute positions.
-}
sliceAtTextSpans : String -> List String
sliceAtTextSpans str =
    let
        go expr =
            let
                m =
                    AST.Language.getMeta expr
            in
            case expr of
                Text _ _ ->
                    [ String.slice m.begin (m.end + 1) str ]

                Fun _ cs _ ->
                    List.concatMap go cs

                ExprList _ cs _ ->
                    List.concatMap go cs

                VFun _ _ _ ->
                    []
    in
    Scripta.Compiler.parseFromString str
        |> List.concatMap Library.Tree.flatten
        |> List.concatMap
            (\b ->
                case b.body of
                    Right exprs ->
                        List.concatMap go exprs

                    Left _ ->
                        []
            )


suite : Test
suite =
    describe "List items carry absolute source offsets (RL sync)"
        [ test "slicing the document at each list-item Text span yields its source text" <|
            \_ ->
                sliceAtTextSpans doc
                    |> Expect.equal [ "intro", "alpha beta", "gamma delta" ]
        ]

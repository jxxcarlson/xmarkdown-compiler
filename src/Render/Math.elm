module Render.Math exposing
    ( DisplayMode(..)
    , aligned
    , array
    , chem
    , displayedMath
    , equation
    , mathText
    )

import AST.Acc exposing (Accumulator)
import AST.Language exposing (Expr(..), ExpressionBlock)
import Dict exposing (Dict)
import Either
import ETeX.Transform
import Html exposing (Html)
import Html.Attributes
import Json.Encode
import Render.Theme exposing (RenderSettings)
import XMarkdown.Types exposing (MarkupMsg)


type DisplayMode
    = InlineMathMode
    | DisplayMathMode


{-| Get the math content from a block and transform it from ETeX to LaTeX
-}
getMathContent : ExpressionBlock -> String
getMathContent block =
    let
        rawContent =
            case block.body of
                Either.Left str ->
                    -- For Verbatim math blocks, content is already raw text
                    str
                Either.Right exprs ->
                    -- For expression-based math (inline), extract text
                    exprs
                        |> List.map extractExprText
                        |> String.concat

        stripped =
            rawContent
                |> String.trim
                |> stripMathDelimiters
    in
    -- Transform ETeX to LaTeX for KaTeX rendering
    -- transformETeX handles both ETeX and standard LaTeX properly
    ETeX.Transform.transformETeX Dict.empty stripped


{-| Extract text content from an expression
-}
extractExprText : Expr a -> String
extractExprText expr =
    case expr of
        Text str _ ->
            str
        VFun _ content _ ->
            content
        Fun _ exprList _ ->
            exprList
                |> List.map extractExprText
                |> String.concat
        ExprList _ exprList _ ->
            exprList
                |> List.map extractExprText
                |> String.concat


{-| Strip $$ delimiters from math content
-}
stripMathDelimiters : String -> String
stripMathDelimiters content =
    content
        |> String.trim
        |> (\s ->
            if String.startsWith "$$" s then
                String.dropLeft 2 s
            else
                s
           )
        |> String.trim
        |> (\s ->
            if String.endsWith "$$" s then
                String.dropRight 2 s
            else
                s
           )
        |> String.trim


{-| Render a math element using KaTeX via custom element
-}
renderMath : String -> Bool -> List (Html.Attribute MarkupMsg) -> Html MarkupMsg
renderMath content isDisplay attrs =
    Html.node "math-text"
        ([ Html.Attributes.attribute "data-content" content
         , Html.Attributes.attribute "data-display" (if isDisplay then "true" else "false")
         ]
            ++ attrs
        )
        [ Html.text content ]


{-| Render chemistry notation
-}
chem : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
chem count acc settings attrs block =
    let
        content = getMathContent block
        blockId = "e-" ++ String.fromInt block.meta.lineNumber ++ "." ++ String.fromInt count
    in
    renderMath content False
        ([ Html.Attributes.id blockId
         , Html.Attributes.attribute "data-line-number" (String.fromInt block.meta.lineNumber)
         , Html.Attributes.style "padding" "8px"
         ] ++ attrs)


{-| Render displayed math
-}
displayedMath : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
displayedMath count acc settings attrs block =
    let
        content = getMathContent block
        blockId = "e-" ++ String.fromInt block.meta.lineNumber ++ "." ++ String.fromInt count
    in
    renderMath content True
        ([ Html.Attributes.id blockId
         , Html.Attributes.attribute "data-line-number" (String.fromInt block.meta.lineNumber)
         , Html.Attributes.style "padding" "8px"
         ] ++ attrs)


{-| Render equation
-}
equation : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
equation count acc settings attrs block =
    let
        content = getMathContent block
        blockId = "e-" ++ String.fromInt block.meta.lineNumber ++ "." ++ String.fromInt count
    in
    renderMath content True
        ([ Html.Attributes.id blockId
         , Html.Attributes.attribute "data-line-number" (String.fromInt block.meta.lineNumber)
         , Html.Attributes.style "padding" "8px"
         ] ++ attrs)


{-| Render aligned math
-}
aligned : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
aligned count acc settings attrs block =
    let
        content = getMathContent block
        blockId = "e-" ++ String.fromInt block.meta.lineNumber ++ "." ++ String.fromInt count
    in
    renderMath content True
        ([ Html.Attributes.id blockId
         , Html.Attributes.attribute "data-line-number" (String.fromInt block.meta.lineNumber)
         , Html.Attributes.style "padding" "8px"
         ] ++ attrs)


{-| Render array/matrix
-}
array : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
array count acc settings attrs block =
    let
        content = getMathContent block
        blockId = "e-" ++ String.fromInt block.meta.lineNumber ++ "." ++ String.fromInt count
    in
    renderMath content True
        ([ Html.Attributes.id blockId
         , Html.Attributes.attribute "data-line-number" (String.fromInt block.meta.lineNumber)
         , Html.Attributes.style "padding" "8px"
         ] ++ attrs)


{-| Render inline math text
-}
mathText : String -> Int -> String -> DisplayMode -> String -> Html MarkupMsg
mathText theme generation id mode content =
    let
        isDisplay = mode == DisplayMathMode
    in
    renderMath content isDisplay []

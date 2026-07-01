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
import AST.Language exposing (ExpressionBlock)
import Html exposing (Html)
import Html.Attributes
import Render.Settings exposing (RenderSettings)
import XMarkdown.Types exposing (MarkupMsg)


type DisplayMode
    = InlineMathMode
    | DisplayMathMode


{-| Render chemistry notation
-}
chem : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
chem count acc settings attrs block =
    Html.div ([ Html.Attributes.style "border" "1px solid #ddd", Html.Attributes.style "padding" "8px" ] ++ attrs)
        [ Html.text "(chemistry notation)" ]


{-| Render displayed math
-}
displayedMath : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
displayedMath count acc settings attrs block =
    Html.div ([ Html.Attributes.style "border" "1px solid #ddd", Html.Attributes.style "padding" "8px" ] ++ attrs)
        [ Html.text "(displayed math)" ]


{-| Render equation
-}
equation : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
equation count acc settings attrs block =
    Html.div ([ Html.Attributes.style "border" "1px solid #ddd", Html.Attributes.style "padding" "8px" ] ++ attrs)
        [ Html.text "(equation)" ]


{-| Render aligned math
-}
aligned : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
aligned count acc settings attrs block =
    Html.div ([ Html.Attributes.style "border" "1px solid #ddd", Html.Attributes.style "padding" "8px" ] ++ attrs)
        [ Html.text "(aligned math)" ]


{-| Render array/matrix
-}
array : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
array count acc settings attrs block =
    Html.div ([ Html.Attributes.style "border" "1px solid #ddd", Html.Attributes.style "padding" "8px" ] ++ attrs)
        [ Html.text "(array/matrix)" ]


{-| Render inline math text
-}
mathText : String -> Int -> String -> DisplayMode -> String -> Html MarkupMsg
mathText theme generation id mode content =
    Html.span [ Html.Attributes.style "color" "#0066cc" ]
        [ Html.text ("(" ++ content ++ ")") ]

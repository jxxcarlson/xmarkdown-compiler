module Render.Graphics exposing (image, image2)

import Html exposing (Html)
import Html.Attributes
import Either
import AST.ASTTools as ASTTools
import AST.Language exposing (Expr(..), Expression, ExpressionBlock)
import Render.Theme exposing (RenderSettings)
import XMarkdown.Types exposing (MarkupMsg)


{-| Render an image
-}
image : Render.Theme.RenderSettings -> List (Html.Attribute MarkupMsg) -> List Expression -> Html MarkupMsg
image settings attrs body =
    let
        (url, alt) = extractImageData body
    in
    Html.img
        ([ Html.Attributes.src url
         , Html.Attributes.alt alt
         , Html.Attributes.style "max-width" "100%"
         ]
            ++ attrs
        )
        []


{-| Extract URL and alt text from image expressions
-}
extractImageData : List Expression -> (String, String)
extractImageData exprs =
    case exprs of
        [Text text _] ->
            let
                parts = String.split " " (String.trim text)
            in
            case parts of
                url :: altParts ->
                    (url, String.join " " altParts)
                _ ->
                    (String.trim text, "image")

        _ ->
            ("", "image")


{-| Render an image block
-}
image2 : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
image2 count acc settings attrs block =
    let
        (url, alt) =
            case block.body of
                Either.Right exprs ->
                    extractImageData exprs
                Either.Left _ ->
                    ("", "image")
    in
    Html.figure attrs
        [ Html.img
            [ Html.Attributes.src url
            , Html.Attributes.alt alt
            , Html.Attributes.style "max-width" "100%"
            ]
        , Html.figcaption [] [ Html.text alt ]
        ]

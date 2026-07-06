module Render.Graphics exposing (image, image2)

import AST.Language exposing (Expr(..), Expression, ExpressionBlock)
import Either
import Html exposing (Html)
import Html.Attributes
import XMarkdown.Types exposing (MarkupMsg)


{-| Render an image
-}
image : List (Html.Attribute MarkupMsg) -> List Expression -> Html MarkupMsg
image attrs body =
    let
        ( url, alt ) =
            extractImageData body
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
extractImageData : List Expression -> ( String, String )
extractImageData exprs =
    case exprs of
        [ Text text _ ] ->
            let
                parts =
                    String.split " " (String.trim text)
            in
            case parts of
                url :: altParts ->
                    ( url, String.join " " altParts )

                _ ->
                    ( String.trim text, "image" )

        _ ->
            ( "", "image" )


{-| Render an image block
-}
image2 : List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
image2 attrs block =
    let
        ( url, alt ) =
            case block.body of
                Either.Right exprs ->
                    extractImageData exprs

                Either.Left _ ->
                    ( "", "image" )
    in
    Html.figure attrs
        [ Html.img
            [ Html.Attributes.src url
            , Html.Attributes.alt alt
            , Html.Attributes.style "max-width" "100%"
            ]
        , Html.figcaption [] [ Html.text alt ]
        ]

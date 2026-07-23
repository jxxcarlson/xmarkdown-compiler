module Render.Expression exposing (render)

import AST.Language exposing (Expr(..), Expression)
import Dict exposing (Dict)
import ETeX.Transform
import Html exposing (Html)
import Html.Attributes
import Render.Theme
import XMarkdown.Types exposing (MarkupMsg, Theme)


{-| Render an expression to Html
-}
render : Theme -> Int -> List (Html.Attribute MarkupMsg) -> Expression -> Html MarkupMsg
render theme depth attrs expr =
    case expr of
        Text string _ ->
            Html.span attrs [ Html.text (string ++ " ") ]

        VFun name content _ ->
            if List.member name [ "math", "m", "chem" ] then
                let
                    -- ETeX -> LaTeX, exactly as block math does (Render.Math.getMathContent)
                    mathContent =
                        ETeX.Transform.transformETeX Dict.empty content
                in
                Html.node "math-text"
                    [ Html.Attributes.attribute "data-content" mathContent
                    , Html.Attributes.attribute "data-display" "false"
                    ]
                    [ Html.text mathContent ]

            else if name == "code" then
                Html.code [] [ Html.text content ]

            else
                Html.span [] [ Html.text content ]

        Fun name exprList _ ->
            if List.member name [ "chem", "math", "m" ] then
                let
                    mathContent =
                        extractMathContent exprList
                            |> ETeX.Transform.transformETeX Dict.empty
                in
                Html.node "math-text"
                    [ Html.Attributes.attribute "data-content" mathContent
                    , Html.Attributes.attribute "data-display" "false"
                    ]
                    [ Html.text mathContent ]

            else if name == "code" then
                Html.code []
                    (List.map (render theme depth attrs) exprList)

            else if List.member name [ "b", "strong", "bold" ] then
                Html.strong []
                    (List.map (render theme depth attrs) exprList)

            else if List.member name [ "i", "em", "italic" ] then
                Html.em []
                    (List.map (render theme depth attrs) exprList)

            else if name == "a" || name == "link" then
                let
                    -- Link text and URL are concatenated in the expression: "text url"
                    ( linkText, url ) =
                        extractLinkData exprList
                in
                Html.a
                    [ Html.Attributes.href url
                    , Html.Attributes.style "color" (Render.Theme.themedColor .link theme)
                    ]
                    [ Html.text linkText ]

            else if name == "image" || name == "img" then
                let
                    -- Image URL and alt text are concatenated in the expression: "url alt"
                    ( url, altText ) =
                        extractImageData exprList

                    -- Parse properties from alt text (e.g., "caption width:200 height:150")
                    ( caption, props ) =
                        parseImageProperties altText

                    -- Build image attributes from properties
                    imgAttrs =
                        buildImageAttributes props
                in
                Html.figure
                    [ Html.Attributes.style "text-align" "center"
                    , Html.Attributes.style "margin" "1em 0"
                    ]
                    [ Html.a
                        [ Html.Attributes.href url
                        , Html.Attributes.target "_blank"
                        , Html.Attributes.rel "noopener noreferrer"
                        ]
                        [ Html.img
                            ([ Html.Attributes.src url
                             , Html.Attributes.alt caption
                             , Html.Attributes.style "max-width" "100%"
                             , Html.Attributes.style "cursor" "pointer"
                             ]
                                ++ imgAttrs
                            )
                            []
                        ]
                    , if String.isEmpty caption then
                        Html.text ""

                      else
                        Html.figcaption
                            [ Html.Attributes.style "font-size" "0.9em"
                            , Html.Attributes.style "color" (Render.Theme.themedColor .offsetText theme)
                            , Html.Attributes.style "margin-top" "0.5em"
                            ]
                            [ Html.text caption ]
                    ]

            else
                Html.span []
                    (List.map (render theme depth attrs) exprList)

        ExprList indentation exprList _ ->
            let
                pseudoDepth =
                    indentation // 2
            in
            Html.div [] (List.map (render theme pseudoDepth attrs) exprList)


{-| Extract link text and URL from expressions
Link expressions have format: Text "linkText url" where URL is the last space-separated token
-}
extractLinkData : List Expression -> ( String, String )
extractLinkData exprs =
    let
        combined =
            exprs
                |> List.map
                    (\expr ->
                        case expr of
                            Text str _ ->
                                str

                            _ ->
                                ""
                    )
                |> String.concat
                |> String.trim
    in
    case String.split " " combined |> List.reverse of
        [] ->
            ( "Link", "#" )

        url :: rest ->
            ( String.join " " (List.reverse rest), url )


{-| Extract image URL and alt text from expressions
Image expressions have format: Text "url altText" where URL is the first space-separated token
-}
extractImageData : List Expression -> ( String, String )
extractImageData exprs =
    let
        combined =
            exprs
                |> List.map
                    (\expr ->
                        case expr of
                            Text str _ ->
                                str

                            _ ->
                                ""
                    )
                |> String.concat
                |> String.trim
    in
    case String.split " " combined of
        [] ->
            ( "", "Image" )

        url :: rest ->
            ( url, String.join " " rest )


{-| Parse image properties from alt text
Properties are in format "key:value" (e.g., "width:200 height:150")
Returns (caption, properties dict)
-}
parseImageProperties : String -> ( String, Dict String String )
parseImageProperties altText =
    let
        tokens =
            String.split " " altText

        ( propTokens, captionTokens ) =
            List.partition (\token -> String.contains ":" token) tokens

        props =
            propTokens
                |> List.map
                    (\token ->
                        case String.split ":" token of
                            [ key, value ] ->
                                Just ( key, value )

                            _ ->
                                Nothing
                    )
                |> List.filterMap identity
                |> Dict.fromList

        caption =
            String.join " " captionTokens |> String.trim
    in
    ( caption, props )


{-| Build HTML attributes from image properties
-}
buildImageAttributes : Dict String String -> List (Html.Attribute MarkupMsg)
buildImageAttributes props =
    let
        widthAttr =
            Dict.get "width" props
                |> Maybe.map (\w -> Html.Attributes.style "width" (w ++ "px"))

        heightAttr =
            Dict.get "height" props
                |> Maybe.map (\h -> Html.Attributes.style "height" (h ++ "px"))
    in
    [ widthAttr, heightAttr ]
        |> List.filterMap identity


{-| Extract math content from expressions (flatten Text nodes)
-}
extractMathContent : List Expression -> String
extractMathContent exprs =
    exprs
        |> List.map
            (\expr ->
                case expr of
                    Text str _ ->
                        str

                    _ ->
                        ""
            )
        |> String.concat
        |> String.trim

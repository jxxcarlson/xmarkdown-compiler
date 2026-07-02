module Render.Indentation exposing (indentParagraph, indentOrdinaryBlock)

import Html exposing (Html)
import Html.Attributes
import Render.Helper
import Render.Theme exposing (RenderSettings)


topPaddingForIndentedElements : Int
topPaddingForIndentedElements =
    Render.Helper.topPaddingForIndentedElements


{-| Indent a paragraph based on indent level
-}
indentParagraph : Int -> Html msg -> Html msg
indentParagraph indent x =
    if indent > 0 then
        Html.div [ Html.Attributes.style "padding-top" (String.fromInt topPaddingForIndentedElements ++ "px") ] [ x ]
    else
        x


{-| Indent an ordinary block based on indent level and id
-}
indentOrdinaryBlock : Int -> String -> RenderSettings -> Html msg -> Html msg
indentOrdinaryBlock indent id settings x =
    if indent > 0 then
        Html.div
            [ Html.Attributes.style "padding-top" (String.fromInt topPaddingForIndentedElements ++ "px") ]
            [ x ]
    else
        x

module Render.Footnote exposing (endnotes, index)

import Dict
import Element exposing (Element)
import Element.Events as Events
import Element.Font as Font
import Generic.Acc exposing (Accumulator)
import Generic.Language exposing (ExpressionBlock)
import Render.Helper
import Render.Settings exposing (RenderSettings)
import Render.Utility
import ScriptaV2.Msg exposing (MarkupMsg(..))


index : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
index _ acc _ _ _ =
    acc.terms
        |> Dict.toList
        |> List.map (\( name, item_ ) -> ( String.trim name, item_ ))
        |> List.sortBy (\( name, _ ) -> name)
        |> List.map indexItem_
        |> Element.column [ Element.alignTop, Element.spacing 6, Element.width (Element.px 150) ]


indexItem_ : Item -> Element MarkupMsg
indexItem_ ( name, loc ) =
    Element.link [ Font.color (Element.rgb 0 0 0.8), Events.onClick (SelectId loc.id) ]
        { url = Render.Utility.internalLink loc.id, label = Element.el [] (Element.text name) }



-- ENDNOTES


endnotes : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
endnotes _ acc _ attrs _ =
    let
        endnoteList =
            acc.footnotes
                |> Dict.toList
                |> List.map
                    (\( content, meta ) ->
                        { label = Dict.get meta.id acc.footnoteNumbers |> Maybe.withDefault 0
                        , content = content
                        , id = meta.id ++ "_"
                        }
                    )
                |> List.sortBy .label
    in
    Element.column ([ Element.spacing 12 ] ++ attrs)
        (Element.el [ Font.bold, Font.size 18 ] (Element.text "Endnotes")
            :: List.map renderFootnote endnoteList
        )


renderFootnote : { label : Int, content : String, id : String } -> Element MarkupMsg
renderFootnote { label, content, id } =
    Element.paragraph [ Element.spacing 4 ]
        [ Element.el [ Render.Helper.htmlId id, Element.width (Element.px 24) ] (Element.text (String.fromInt label ++ "."))
        , Element.text content
        ]


type alias Item =
    ( String, { begin : Int, end : Int, id : String } )

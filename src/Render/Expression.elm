module Render.Expression exposing (render)

import Dict exposing (Dict)
import ETeX.MathMacros
import ETeX.Transform
import Element exposing (Element, el, newTabLink, spacing)
import Element.Background as Background
import Element.Border
import Element.Events as Events
import Element.Font as Font
import Generic.ASTTools as ASTTools
import Generic.Acc exposing (Accumulator)
import Generic.Language exposing (Expr(..), Expression)
import Html
import Html.Attributes
import Html.Events
import Json.Decode
import List.Extra
import Render.Constants as Constants
import Render.Graphics
import Render.Html.Math
import Render.Math
import Render.Settings exposing (RenderSettings)
import Render.Sync
import Render.Theme
import Render.ThemeHelpers
import Render.Utility as Utility
import Scripta.Msg exposing (MarkupMsg(..))


render : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> Expression -> Element MarkupMsg
render generation acc settings attrs expr =
    let
        background =
            Background.color <| Render.Settings.getThemedElementColor .offsetBackground settings.theme
    in
    case expr of
        Text string meta ->
            Element.el (background :: [ onClickStop (SendMeta meta), htmlId meta.id ] ++ attrs) (Element.text (string ++ " "))

        Fun name exprList meta ->
            if List.member name [ "chem", "math", "m", "code" ] then
                Element.el [ onClickStop (SendMeta meta), htmlId meta.id ]
                    (renderVerbatim name generation acc settings meta (ASTTools.exprListToStringList exprList |> String.join " "))

            else if name == "anchor" then
                let
                    -- Check if the anchor's own ID matches selectedId
                    anchorIdMatches =
                        settings.selectedId == meta.id

                    -- Get all IDs from the content
                    contentIds =
                        List.map (Generic.Language.getMeta >> .id) exprList

                    -- Check if any content ID matches selectedId
                    contentIdMatches =
                        List.member settings.selectedId contentIds

                    -- Highlight if either the anchor ID or any content ID matches
                    shouldHighlight =
                        anchorIdMatches || contentIdMatches

                    highlightAttrs =
                        if shouldHighlight then
                            -- Use inline style for highlighting with a light blue color
                            [ Element.htmlAttribute (Html.Attributes.style "background-color" "#ADD8E6") -- Light blue
                            , Element.htmlAttribute (Html.Attributes.style "padding" "4px")
                            , Element.htmlAttribute (Html.Attributes.class "anchor-highlight")
                            ]

                        else
                            []
                in
                Element.el ([ onClickStop (SendMeta meta), htmlId meta.id ] ++ highlightAttrs)
                    (renderMarked name generation acc settings attrs exprList)

            else if name == "mark" then
                let
                    -- Check if the anchor's own ID matches selectedId
                    anchorIdMatches =
                        settings.selectedId == meta.id

                    highlightAttrs =
                        if anchorIdMatches then
                            -- Use inline style for highlighting with a light blue color
                            [ Element.htmlAttribute (Html.Attributes.style "background-color" "#ADD8E6") -- Light blue
                            , Element.htmlAttribute (Html.Attributes.style "padding" "4px")
                            , Element.htmlAttribute (Html.Attributes.class "anchor-highlight")
                            ]

                        else
                            []
                in
                Element.el ([ onClickStop (SendMeta meta), htmlId meta.id ] ++ highlightAttrs)
                    (renderMarked name generation acc settings attrs exprList)

            else
                Element.el (background :: [ onClickStop (SendMeta meta), htmlId meta.id ])
                    (renderMarked name generation acc settings attrs exprList)

        VFun name str meta ->
            -- Verbatim inline (math `$...$`, code) needs its own RL-sync click
            -- handler; without it a click falls through to the enclosing block
            -- and highlights the whole paragraph. stopPropagation keeps the
            -- click on the verbatim span.
            Element.el [ onClickStop (SendMeta meta), htmlId meta.id ]
                (renderVerbatim name generation acc settings meta str)

        ExprList _ exprList _ ->
            Element.column []
                [ Element.paragraph (background :: [ Element.paddingEach { left = 2, right = 0, top = 0, bottom = 0 } ]) (List.map (render generation acc settings attrs) exprList)
                ]


renderVerbatim : String -> Int -> { a | mathMacroDict : ETeX.MathMacros.MathMacroDict } -> RenderSettings -> { b | id : String } -> String -> Element msg
renderVerbatim name generation acc settings meta str =
    case Dict.get name verbatimDict of
        Nothing ->
            errorText 1 name

        Just f ->
            f generation acc settings meta str


renderMarked : String -> Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> List Expression -> Element MarkupMsg
renderMarked name generation acc settings attrs exprList =
    case Dict.get name markupDict of
        Nothing ->
            Element.paragraph [ spacing 8 ]
                (Element.el [ Background.color errorBackgroundColor, Element.paddingXY 4 2 ]
                    (Element.text name)
                    :: List.map (render generation acc settings attrs) exprList
                )

        Just f ->
            f generation acc settings attrs exprList


errorBackgroundColor =
    Element.rgb 1 0.8 0.8



-- DICTIONARIES


markupDict :
    Dict
        String
        (Int
         -> Accumulator
         -> RenderSettings
         -> List (Element.Attribute MarkupMsg)
         -> List Expression
         -> Element MarkupMsg
        )
markupDict =
    Dict.fromList
        [ ( "bibitem", \_ _ _ _ exprList -> bibitem exprList )

        -- STYLE
        , ( "bold", \g acc s attr exprList -> strong g acc s attr exprList )
        , ( "var", \g acc s attr exprList -> var g acc s attr exprList )
        , ( "marked", \g acc s attr exprList -> marked g acc s attr exprList )
        , ( "italic", \g acc s attr exprList -> italic g acc s attr exprList )
        , ( "textit", \g acc s attr exprList -> italic g acc s attr exprList )
        , ( "hrule"
          , \_ _ s _ _ ->
                Element.column
                    [ Element.width (Element.px s.width)
                    ]
                    [ Element.el
                        [ Element.Border.width 1
                        , Element.width (Element.px s.width)
                        , Element.centerX
                        , Element.Border.color (Element.rgb 0.75 0.75 0.75)
                        ]
                        (Element.text "")
                    ]
          )

        -- LATEX
        , ( "title", \g acc s attr exprList -> title g acc s attr exprList )
        , ( "errorHighlight", \g acc s attr exprList -> errorHighlight g acc s attr exprList )

        --
        --, ( "skip", \_ _ _ exprList -> skip exprList )
        , ( "link", \_ _ s _ exprList -> link s exprList )
        , ( "href", \_ _ _ _ exprList -> href exprList )
        , ( "abstract", \g acc s attr exprList -> abstract g acc s attr exprList )
        , ( "large", \g acc s attr exprList -> large g acc s attr exprList )
        , ( "cite", \_ acc _ attr exprList -> cite acc attr exprList )
        , ( "table", \g acc s attr exprList -> table g acc s attr exprList )
        , ( "image", \_ _ s attr exprList -> Render.Graphics.image s attr exprList )
        , ( "tags", \_ _ _ _ _ -> Element.none )
        , ( "quote", quote )
        , ( "anchor", anchor )
        , ( "mark", mark1 )
        , ( "vspace", vspace )
        , ( "break", vspace )
        , ( "//", par )
        , ( "par", par )
        , ( "indent", indent )

        -- inline text functions
        , ( "term", \g acc s attr exprList -> term g acc s attr exprList )
        , ( "term_", \_ _ _ _ _ -> Element.none )
        , ( "footnote", \_ acc s _ exprList -> footnote acc s exprList )
        , ( "emph", \g acc s attr exprList -> emph g acc s attr exprList )

        -- , ( "group", \g acc s attr  exprList -> identityFunction g acc s attr exprList )
        --
        , ( "dollarSign", \_ _ _ _ _ -> Element.el [] (Element.text "$") )
        , ( "dollar", \_ _ _ _ _ -> Element.el [] (Element.text "$") )
        , ( "brackets", \g acc s attr exprList -> brackets g acc s attr exprList )
        ]


verbatimDict =
    Dict.fromList
        [ ( "$", \g a s m str -> math g a s m str )
        , ( "`", \_ _ s m str -> code s m str )
        , ( "code", \_ _ s m str -> code s m str )
        , ( "math", \g a s m str -> math g a s m str )
        , ( "m", \g a s m str -> math g a s m str )
        , ( "chem", \g a s m str -> chem g a s m str )
        ]



-- FUNCTIONS


abstract g acc s attr exprList =
    Element.paragraph [] [ Element.el [ Font.size (Render.Settings.scaleFont s 18) ] (Element.text "Abstract."), simpleElement [] g acc s attr exprList ]


large : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> List Expression -> Element MarkupMsg
large g acc s attr exprList =
    simpleElement [ Font.size (Render.Settings.scaleFont s 18) ] g acc s attr exprList


link : RenderSettings -> List Expression -> Element MarkupMsg
link settings exprList =
    case List.head <| ASTTools.exprListToStringList exprList of
        Nothing ->
            errorText_ "Please provide label and url"

        Just argString ->
            let
                args =
                    String.words argString

                n =
                    List.length args
            in
            if n == 0 then
                errorText_ "Please provide url"

            else if n == 1 then
                let
                    url =
                        argString

                    label =
                        argString |> String.replace "https://" "" |> String.replace "http://" ""
                in
                newTabLink []
                    { url = url
                    , label = el [ Background.color settings.backgroundColor, Font.color settings.linkColor, Font.underline ] (Element.text label)
                    }

            else
                let
                    label =
                        List.take (n - 1) args |> String.join " "

                    url =
                        List.drop (n - 1) args |> String.join " "
                in
                newTabLink []
                    { url = url
                    , label = el [ Background.color settings.backgroundColor, Font.color settings.linkColor, Font.underline ] (Element.text label)
                    }


href : List Expression -> Element MarkupMsg
href exprList =
    let
        url =
            List.Extra.getAt 0 exprList |> Maybe.andThen ASTTools.getText |> Maybe.withDefault ""

        label =
            List.Extra.getAt 1 exprList |> Maybe.andThen ASTTools.getText |> Maybe.withDefault ""
    in
    newTabLink []
        { url = url
        , label = el [ Font.color linkColor ] (Element.text label)
        }


bibitem : List Expression -> Element MarkupMsg
bibitem exprs =
    Element.paragraph [ Element.width Element.fill ] [ Element.text (ASTTools.exprListToStringList exprs |> String.join " " |> (\s -> "[" ++ s ++ "]")) ]


cite : Accumulator -> List (Element.Attribute MarkupMsg) -> List Expression -> Element MarkupMsg
cite acc attr str =
    let
        tag : String
        tag =
            ASTTools.exprListToStringList str |> String.join ""

        id =
            Dict.get tag acc.reference |> Maybe.map .id |> Maybe.withDefault ""
    in
    Element.paragraph
        ([ Element.width Element.fill

         -- , Events.onClick (SendLineNumber _)
         , Events.onClick (SelectId id)
         , Font.color (Element.rgb 0.2 0.2 1.0)
         , Font.bold
         ]
            ++ attr
        )
        [ Element.text (tag |> (\s -> "[" ++ s ++ "]")) ]


code : RenderSettings -> { d | id : String } -> String -> Element msg
code s m str =
    verbatimElement s (codeStyle s) m str


math : Int -> { a | mathMacroDict : ETeX.MathMacros.MathMacroDict } -> Render.Settings.RenderSettings -> { b | id : String } -> String -> Element msg
math g a s m str =
    Element.el
        (Render.Sync.highlightIfIdSelected m.id s [])
        (mathElement g a s m str)


chem : Int -> { a | mathMacroDict : ETeX.MathMacros.MathMacroDict } -> Render.Settings.RenderSettings -> { b | id : String } -> String -> Element msg
chem g a s m str =
    Element.el
        (Render.Sync.highlightIfIdSelected m.id s [])
        (mathElement g a s m ("\\ce{" ++ str ++ "}"))


table : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> List Expression -> Element MarkupMsg
table g acc s attr rows =
    Element.column [ Element.spacing 8 ] (List.map (tableRow g acc s attr) rows)


tableRow : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> Expression -> Element MarkupMsg
tableRow g acc s attr expr =
    case expr of
        Fun "tableRow" items _ ->
            Element.row [ spacing 8 ] (List.map (tableItem g acc s attr) items)

        _ ->
            Element.none


tableItem : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> Expression -> Element MarkupMsg
tableItem g acc s attr expr =
    case expr of
        Fun "tableItem" exprList _ ->
            Element.paragraph [ Element.width (Element.px 100) ] (List.map (render g acc s attr) exprList)

        _ ->
            Element.none


vspace _ _ _ _ exprList =
    let
        h =
            ASTTools.exprListToStringList exprList |> String.join "" |> String.toInt |> Maybe.withDefault 1
    in
    -- Element.column [ Element.paddingXY 0 100 ] (Element.text "-")
    Element.column [ Element.height (Element.px h) ] [ Element.text "" ]


par _ _ _ _ _ =
    Element.column [ Element.height (Element.px 5) ] [ Element.text "" ]


indent _ _ _ _ _ =
    Element.el [ Element.height (Element.px 5) ] (Render.Html.Math.mathText 0 "24px" "abc" Render.Html.Math.InlineMathMode "\\quad")


strong g acc s attr exprList =
    simpleElement [ Font.bold ] g acc s attr exprList


var g acc s attr exprList =
    simpleElement [] g acc s attr exprList


brackets g acc s attr exprList =
    Element.paragraph [ Element.spacing 8 ] [ Element.text "[", simpleElement [] g acc s attr exprList, Element.text " ]" ]


italic : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> List Expression -> Element MarkupMsg
italic g acc s attr exprList =
    simpleElement [ Font.italic, Element.paddingEach { left = 0, right = 2, top = 0, bottom = 0 } ] g acc s attr exprList


marked : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> List Expression -> Element MarkupMsg
marked g acc s attr exprList =
    case exprList of
        --[] ->
        --    Element.none
        first :: [] ->
            simpleElement [] g acc s attr [ first ]

        (Text str _) :: rest ->
            simpleElement [ htmlId str ] g acc s attr rest

        _ ->
            Element.none


quote : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> List Expression -> Element MarkupMsg
quote g acc s attr exprList =
    let
        meta =
            { begin = 0, end = 1, index = 0, id = "qq" }

        leftQuote =
            String.fromChar '"'

        rightQuote =
            String.fromChar '"'
    in
    Element.paragraph [] (List.map (render g acc s attr) (Text leftQuote meta :: exprList ++ [ Text rightQuote meta ]))


anchor : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> List Expression -> Element MarkupMsg
anchor g acc s attr exprList =
    -- The CSS class (if any) is passed through the attr parameter
    -- We combine it with the underline style for anchors
    Element.paragraph (Font.underline :: attr) (List.map (render g acc s []) exprList)


mark1 : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> List Expression -> Element MarkupMsg
mark1 g acc s attr exprList =
    case exprList of
        [ Text str _, Fun "anchor" list _ ] ->
            Element.paragraph
                [ htmlId (String.trim str), Font.underline ]
                (List.map (render g acc s attr) list)

        _ ->
            Element.text "Parse error in element mark?"


title g acc s attr exprList =
    simpleElement [ Font.size (Render.Settings.scaleFont s Constants.titleFontSize), Element.paddingEach { left = 0, right = 2, top = 0, bottom = 0 } ] g acc s attr exprList


term g acc s attr exprList =
    simpleElement [ Font.italic, Element.paddingEach { left = 0, right = 2, top = 0, bottom = 0 } ] g acc s attr exprList


footnote : Accumulator -> RenderSettings -> List Expression -> Element MarkupMsg
footnote acc settings exprList =
    case exprList of
        (Text _ meta) :: [] ->
            case Dict.get meta.id acc.footnoteNumbers of
                Just k ->
                    Element.link
                        [ Font.color (Render.Theme.getElementColor settings.theme .footnote)

                        -- Font.color (Element.rgb 0 0 0.7)
                        , Font.bold
                        , Events.onClick (SelectId (meta.id ++ "_"))
                        ]
                        { url = Utility.internalLink (meta.id ++ "_")
                        , label = Element.el [] (Element.html <| Html.node "sup" [] [ Html.text (String.fromInt k) ])
                        }

                -- Element.el (htmlId meta.id :: []) (Element.text (String.fromInt k))
                _ ->
                    Element.none

        _ ->
            Element.none



-- Element.el (htmlId meta.id :: formatList) (Element.text str)


emph g acc s attr exprList =
    simpleElement [ Font.italic, Element.paddingEach { left = 0, right = 2, top = 0, bottom = 0 } ] g acc s attr exprList



-- COLOR FUNCTIONS
-- FONT STYLE FUNCTIONS


errorHighlight g acc s attr exprList =
    simpleElement [ Background.color (Element.rgb255 255 200 200), Element.paddingXY 4 2 ] g acc s attr exprList



-- HELPERS


simpleElement : List (Element.Attribute MarkupMsg) -> Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> List Expression -> Element MarkupMsg
simpleElement formatList g acc s attr exprList =
    Element.paragraph formatList (List.map (render g acc s attr) exprList)


verbatimElement settings formatList meta str =
    Element.el (Font.size (Render.Settings.scaleFont settings 13) :: htmlId meta.id :: Element.height (Element.px 11) :: Background.color settings.codeBackground :: formatList) (Element.text str)


{-| A click handler that does NOT bubble, so an inline expression click reports
only itself and not the enclosing block's right-to-left line sync.
-}
onClickStop : MarkupMsg -> Element.Attribute MarkupMsg
onClickStop msg =
    Element.htmlAttribute
        (Html.Events.stopPropagationOn "click" (Json.Decode.succeed ( msg, True )))


htmlId str =
    Element.htmlAttribute (Html.Attributes.id str)


errorText index str =
    Element.el [ Font.color (Element.rgb255 200 40 40) ] (Element.text <| "(" ++ String.fromInt index ++ ") not implemented: " ++ str)


errorText_ str =
    Element.el [ Font.color (Element.rgb255 200 40 40) ] (Element.text str)


mathElement generation acc s meta str =
    Render.Math.mathText (Render.ThemeHelpers.themeAsStringFromSettings s) generation meta.id Render.Math.InlineMathMode (ETeX.Transform.evalStr acc.mathMacroDict str)



-- DEFINITIONS


codeStyle : RenderSettings -> List (Element.Attribute msg)
codeStyle settings =
    [ Font.family
        [ Font.typeface "Inconsolata"
        , Font.monospace
        ]
    , Font.unitalicized
    , Font.color settings.codeColor
    , Background.color settings.codeBackground
    , Element.paddingEach { left = 2, right = 2, top = 0, bottom = 0 }
    ]


linkColor =
    Element.rgb 0 0 0.8

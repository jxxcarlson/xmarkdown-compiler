module Render.Blocks.Document exposing (registerRenderers)

{-| This module provides renderers for document structure blocks.

@docs registerRenderers
@docs title

-}

import Dict
import Element exposing (Element)
import Element.Font as Font
import Generic.Acc exposing (Accumulator)
import Generic.Language exposing (ExpressionBlock)
import Render.BlockRegistry exposing (BlockRegistry)
import Render.Expression
import Render.Helper
import Render.Settings exposing (RenderSettings)
import Render.Sync
import Render.Utility
import Scripta.Msg exposing (MarkupMsg)


{-| Register all document structure block renderers to the registry
-}
registerRenderers : BlockRegistry -> BlockRegistry
registerRenderers registry =
    Render.BlockRegistry.registerBatch
        [ ( "section", section )
        , ( "section*", unnumberedSection )
        ]
        registry


{-| Render a section heading
TODO: re-examine how we compute adn display hierarchical section numbers.
-}
section : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
section count acc settings attr block =
    -- level 1 is reserved for titles
    let
        maxNumberedLevel =
            Dict.get "number-to-level" settings.properties
                |> Maybe.andThen String.toFloat
                |> Maybe.withDefault 0

        headingLevel : Float
        headingLevel =
            case Dict.get "level" block.properties of
                Nothing ->
                    2

                Just n ->
                    String.toFloat n |> Maybe.withDefault 3

        fontSize =
            1.2 * (settings.maxHeadingFontSize / sqrt headingLevel) |> round

        sectionNumber =
            if headingLevel <= maxNumberedLevel then
                Element.el [ Font.size fontSize ] (Element.text (Render.Helper.blockLabel block.properties ++ ". "))

            else
                Element.none

        exprs =
            Generic.Language.getExpressionContent block
    in
    Element.link
        (sectionBlockAttributes block
            settings
            [ topPadding 20
            , Font.size fontSize
            ]
            ++ Render.Sync.attributes settings block
        )
        { url = Render.Utility.internalLink (settings.titlePrefix ++ "title")
        , label = Element.paragraph [] (sectionNumber :: renderWithDefaultWithSize 18 "--" count acc settings attr exprs)
        }


unnumberedSection : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
unnumberedSection count acc settings attr block =
    -- level 1 is reserved for titles
    let
        headingLevel : Float
        headingLevel =
            case Dict.get "level" block.properties of
                Nothing ->
                    2

                Just n ->
                    String.toFloat n |> Maybe.withDefault 3

        fontSize =
            1.2 * (settings.maxHeadingFontSize / sqrt headingLevel) |> round

        exprs =
            Generic.Language.getExpressionContent block
    in
    Element.link
        (sectionBlockAttributes block
            settings
            [ topPadding 20
            , Font.size fontSize
            ]
        )
        { url = Render.Utility.internalLink (settings.titlePrefix ++ "title")
        , label = Element.paragraph (Render.Sync.attributes settings block) (renderWithDefaultWithSize 18 "--" count acc settings attr exprs)
        }


{-| Helper for section block attributes
-}
sectionBlockAttributes : ExpressionBlock -> RenderSettings -> List (Element.Attr () MarkupMsg) -> List (Element.Attr () MarkupMsg)
sectionBlockAttributes block settings attrs =
    [ Render.Utility.makeId (Generic.Language.getExpressionContent block)
    , Render.Utility.idAttribute block.meta.id
    ]
        ++ Render.Sync.highlightIfIdIsSelected block.meta.lineNumber block.meta.numberOfLines settings
        ++ attrs


{-| Padding helper
-}
topPadding : Int -> Element.Attribute msg
topPadding k =
    Element.paddingEach { top = k, bottom = 0, left = 0, right = 0 }


{-| Helper for rendering with a default and size
-}
renderWithDefaultWithSize : Int -> String -> Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> List Generic.Language.Expression -> List (Element MarkupMsg)
renderWithDefaultWithSize size default count acc settings attr exprs =
    if List.isEmpty exprs then
        [ Element.el ([ Font.color settings.redColor, Font.size (Render.Settings.scaleFont settings size) ] ++ attr) (Element.text default) ]

    else
        List.map (Render.Expression.render count acc settings attr) exprs

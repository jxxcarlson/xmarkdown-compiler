module Render.OrdinaryBlock exposing (getAttributes, render)

{-| This module provides a new implementation of OrdinaryBlock using the registry pattern

@docs getAttributes, render

-}

import Either exposing (Either(..))
import Element exposing (Element)
import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock, Heading(..))
import Render.BlockRegistry exposing (BlockRegistry)
import Render.BlockType
import Render.Blocks.Container as ContainerBlocks
import Render.Blocks.Document as DocumentBlocks
import Render.Blocks.Text as TextBlocks
import Render.Indentation
import Render.List
import Render.Settings exposing (RenderSettings)
import Render.GHTable
import Scripta.Msg exposing (MarkupMsg)


{-| Get attributes for a specific block type by name
-}
getAttributes : String -> List (Element.Attribute MarkupMsg)
getAttributes name =
    let
        blockType =
            Render.BlockType.fromString name
    in
    case blockType of
        _ ->
            []


{-| Initialize the registry with all renderers
-}
initRegistry : BlockRegistry
initRegistry =
    Render.BlockRegistry.empty
        |> TextBlocks.registerRenderers
        |> ContainerBlocks.registerRenderers
        |> DocumentBlocks.registerRenderers
        |> Render.BlockRegistry.registerBatch
            [ ( "table", Render.GHTable.render )
            , ( "item", Render.List.item )
            , ( "desc", Render.List.desc )
            , ( "numbered", Render.List.numbered )
            ]


{-| Render an ordinary block using the registry
-}
render : Int -> Accumulator -> RenderSettings -> List (Element.Attribute MarkupMsg) -> ExpressionBlock -> Element MarkupMsg
render count acc settings attr block =
    let
        registry =
            initRegistry
    in
    case block.body of
        Left _ ->
            Element.none

        Right _ ->
            case block.heading of
                Ordinary functionName ->
                    let
                        renderedBlock =
                            case Render.BlockRegistry.lookup functionName registry of
                                Nothing ->
                                    -- Fall back to the environment renderer
                                    let
                                        -- Find the env renderer as our fallback
                                        envRenderer =
                                            Render.BlockRegistry.lookup "env" registry
                                                |> Maybe.withDefault (\_ _ _ _ _ -> Element.none)
                                    in
                                    envRenderer count acc settings attr block

                                Just renderer ->
                                    let
                                        blockType =
                                            Render.BlockType.fromString functionName

                                        newSettings =
                                            case blockType of
                                                _ ->
                                                    settings
                                    in
                                    renderer count acc newSettings attr block
                    in
                    -- Apply indentation to the rendered block
                    indentOrdinaryBlock block.indent (String.fromInt block.meta.lineNumber) settings renderedBlock

                _ ->
                    Element.none


{-| Apply indentation to an ordinary block
-}
indentOrdinaryBlock : Int -> String -> RenderSettings -> Element msg -> Element msg
indentOrdinaryBlock indent id settings x =
    Render.Indentation.indentOrdinaryBlock indent id settings x

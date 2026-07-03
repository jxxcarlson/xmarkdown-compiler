module Render.OrdinaryBlock exposing (getAttributes, render)

{-| This module provides a new implementation of OrdinaryBlock using the registry pattern

@docs getAttributes, render

-}

import AST.Acc exposing (Accumulator)
import AST.Language exposing (ExpressionBlock, Heading(..))
import Either exposing (Either(..))
import Html exposing (Html)
import Html.Attributes
import Render.BlockRegistry exposing (BlockRegistry)
import Render.BlockType
import Render.Blocks.Container as ContainerBlocks
import Render.Blocks.Document as DocumentBlocks
import Render.Blocks.Text as TextBlocks
import Render.GHTable
import Render.List
import Render.Math
import Render.Theme exposing (RenderSettings)
import XMarkdown.Types exposing (MarkupMsg)


{-| Get attributes for a specific block type by name (now returns Html.Attribute)
-}
getAttributes : String -> List (Html.Attribute MarkupMsg)
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
            , ( "equation", Render.Math.equation )
            , ( "aligned", Render.Math.aligned )
            , ( "array", Render.Math.array )
            , ( "chem", Render.Math.chem )
            ]


{-| Render an ordinary block using the registry (returns Html)
-}
render : Int -> Accumulator -> RenderSettings -> List (Html.Attribute MarkupMsg) -> ExpressionBlock -> Html MarkupMsg
render count acc settings attr block =
    let
        registry =
            initRegistry
    in
    case block.body of
        Left _ ->
            Html.text ""

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
                                                |> Maybe.withDefault (\_ _ _ _ _ -> Html.text "")
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
                    Html.text ""


{-| Apply indentation to an ordinary block (returns Html)
-}
indentOrdinaryBlock : Int -> String -> RenderSettings -> Html msg -> Html msg
indentOrdinaryBlock indent id settings x =
    if indent > 0 then
        Html.div [ Html.Attributes.style "margin-left" (String.fromInt (indent * 18) ++ "px") ] [ x ]

    else
        x

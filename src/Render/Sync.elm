module Render.Sync exposing
    ( attributes
    , highlightIfIdIsSelected
    , highlightIfIdSelected
    , highlighter
    , rightToLeftSyncHelper
    )

import AST.Language
import Color exposing (Color)
import Html
import Html.Attributes
import Html.Events as Events
import Render.Theme
import XMarkdown.Types exposing (MarkupMsg(..), Theme)


{-| Use this function to add all needed properties to an element for LR sync
-}
attributes : Render.Theme.RenderSettings -> AST.Language.ExpressionBlock -> List (Html.Attribute MarkupMsg)
attributes settings block =
    [ rightToLeftSyncHelper block.meta.lineNumber block.meta.numberOfLines
    ]
        ++ highlightIfIdIsSelected block.meta.lineNumber block.meta.numberOfLines settings



{-
   The Issue:
    The function compares id (which is block.meta.id) with settings.selectedId. However, when clicking on rendered text:

    1. The rightToLeftSyncHelper sends line numbers (SendLineNumber { begin = firstLineNumber, end = firstLineNumber + numberOfLines })
    2. This sets editorData with line numbers, not the block's meta.id
    3. The highlighting check compares the block's meta.id against selectedId, which likely contains line number information

    Why it fails:
    - The system is mixing two different identification schemes:
      - block.meta.id: A unique identifier for the block
      - block.meta.lineNumber: The line number in the source

    Recommendations:
    1. The highlightIfIdSelected function should compare line numbers instead of IDs when the selection comes from right-to-left sync
    2. Or, ensure that settings.selectedId is set to the block's meta.id when a right-to-left sync occurs
    3. The scrolling issue is related - the system needs to find elements by their ID attribute, but the selection mechanism is using line numbers

    The mismatch between what's being sent (line numbers) and what's being compared (meta.id) prevents both highlighting and scrolling from working
    correctly.
-}
--highlightIfIdSelected : String -> Render.Theme.RenderSettings -> List (Element.Attr () msg) -> List (Element.Attr () msg)


highlightIfIdSelected : b -> { a | selectedId : b, highlight : Color } -> List (Html.Attribute msg) -> List (Html.Attribute msg)
highlightIfIdSelected id settings attrs =
    if id == settings.selectedId then
        -- Background.color settings.highlight :: Html.padding 8 :: attrs
        Html.Attributes.style "background-color" (Color.toCssString settings.highlight) :: attrs

    else
        attrs


highlightIfIdIsSelected : Int -> Int -> Render.Theme.RenderSettings -> List (Html.Attribute MarkupMsg)
highlightIfIdIsSelected firstLineNumber numberOfLines settings =
    if String.fromInt firstLineNumber == settings.selectedId then
        [ rightToLeftSyncHelper firstLineNumber (firstLineNumber + numberOfLines)
        , Html.Attributes.style "background-color" (Color.toCssString settings.highlight)
        ]

    else
        []


rightToLeftSyncHelper : Int -> Int -> Html.Attribute MarkupMsg
rightToLeftSyncHelper firstLineNumber numberOfLines =
    Events.onClick (SendLineNumber { begin = firstLineNumber, end = firstLineNumber + numberOfLines })


highlighter : Theme -> List String -> List (Html.Attribute msg) -> List (Html.Attribute msg)
highlighter theme args attrs =
    if List.member "highlight" args then
        Html.Attributes.style "background-color" (Render.Theme.themedColor .highlight theme) :: attrs

    else
        attrs

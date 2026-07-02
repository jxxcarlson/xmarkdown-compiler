module XMarkdown.Msg exposing (deprecated)

{-| This module is deprecated and no longer needed.

The `MarkupMsg` and `Handling` types have been moved to `XMarkdown.Types`.
Update your imports:

    -- OLD:
    import XMarkdown.Msg exposing (MarkupMsg)

    -- NEW:
    import XMarkdown.Types exposing (MarkupMsg)

-}

deprecated : a -> a
deprecated x = x

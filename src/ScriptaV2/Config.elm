module ScriptaV2.Config exposing
    ( defaultLanguage
    , expressionIdPrefix
    , idPrefix
    , indentationQuantum
    )

import ScriptaV2.Language exposing (Language(..))


defaultLanguage =
    SMarkdownLang


idPrefix =
    "L"


expressionIdPrefix =
    "e-"


indentationQuantum =
    2

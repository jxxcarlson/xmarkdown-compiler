module ReviewConfig exposing (config)

{-| Review configuration focused on dead-code / unused detection:
unused dependencies (#1) and unused exports/imports/variables (#2).
-}

import NoUnused.CustomTypeConstructors
import NoUnused.Dependencies
import NoUnused.Exports
import NoUnused.Modules
import NoUnused.Parameters
import NoUnused.Patterns
import NoUnused.Variables
import Review.Rule exposing (Rule)


config : List Rule
config =
    [ NoUnused.Dependencies.rule
    , NoUnused.Exports.rule
    , NoUnused.Modules.rule
    , NoUnused.Variables.rule
    , NoUnused.CustomTypeConstructors.rule []
    , NoUnused.Parameters.rule
    , NoUnused.Patterns.rule
    ]

module AST.Language exposing
    ( Block
    , BlockMeta
    , Expr(..)
    , ExprMeta
    , Expression
    , ExpressionBlock
    , Heading(..)
    , PrimitiveBlock
    , boostBlock
    , emptyBlockMeta
    , emptyExprMeta
    , getExpressionContent
    , getFunctionName
    , getMeta
    , getName
    , getNameFromHeading
    , getVerbatimContent
    , shiftExpressionPositions
    , updateMeta
    )

import Dict exposing (Dict)
import Either exposing (Either(..))



-- PARAMETRIZED TYPES


type Expr metaData
    = Text String metaData
    | Fun String (List (Expr metaData)) metaData
    | VFun String String metaData
    | ExprList Int (List (Expr metaData)) metaData -- the Int parameter is the indentation of the expression list in the source


{-|

    PrimitiveBlocks, content = String
    ExpressionBlocks, content = Eith
    er String (List Expression)

-}
type alias Block content blockMetaData =
    { heading : Heading
    , indent : Int
    , args : List String
    , properties : Dict String String
    , firstLine : String
    , body : content
    , meta : blockMetaData
    }



-- HEADINGS


type Heading
    = Paragraph
    | Ordinary String -- block name
    | Verbatim String -- block name



-- METADATA TYPES


type alias ExprMeta =
    { begin : Int, end : Int, index : Int, id : String }


emptyExprMeta : { begin : number, end : number, index : number, id : String }
emptyExprMeta =
    { begin = 0, end = 0, index = 0, id = "id" }


type alias BlockMeta =
    { position : Int
    , lineNumber : Int
    , numberOfLines : Int
    , id : String
    , messages : List String
    , sourceText : String
    , error : Maybe String
    }



-- CONCRETE TYPES


type alias Expression =
    Expr ExprMeta


getMeta : Expression -> ExprMeta
getMeta expr =
    case expr of
        Fun _ _ meta ->
            meta

        VFun _ _ meta ->
            meta

        Text _ meta ->
            meta

        ExprList _ _ meta ->
            meta


setMeta : ExprMeta -> Expression -> Expression
setMeta meta expr =
    case expr of
        Fun name args _ ->
            Fun name args meta

        VFun name arg _ ->
            VFun name arg meta

        Text text _ ->
            Text text meta

        ExprList n eList _ ->
            ExprList n eList meta


{-|

    Transform meta so that begin and end are positions in the source text

-}
boost : Int -> ExprMeta -> ExprMeta
boost position meta =
    { meta | begin = meta.begin + position, end = meta.end + position }


boostBlock : ExpressionBlock -> ExpressionBlock
boostBlock block =
    let
        updater =
            boost block.meta.position
    in
    case block.body of
        Left str ->
            { block | body = Left str }

        Right exprs ->
            { block | body = Right (List.map (boostExpr updater) exprs) }


{-| Apply an ExprMeta updater to an expression AND all of its nested
sub-expressions. Used by boostBlock so the begin/end of nested inline content
(inside Fun for bold/italic/links, inside ExprList for list items) become
absolute source positions, not just the top-level expressions. (The non-recursive
updateMetaInBlock is kept for callers — e.g. the TOC — that only want the
top-level metas touched.)
-}
boostExpr : (ExprMeta -> ExprMeta) -> Expression -> Expression
boostExpr updater expr =
    case setMeta (updater (getMeta expr)) expr of
        Fun name children meta ->
            Fun name (List.map (boostExpr updater) children) meta

        ExprList indent children meta ->
            ExprList indent (List.map (boostExpr updater) children) meta

        other ->
            other


{-| Shift the begin/end of an expression and all of its nested sub-expressions by
`delta`. Used to relocate expressions parsed from a substring (e.g. a single list
item) into the coordinate frame of the enclosing block, so that the block-level
`boostBlock` pass then lands them at their absolute source positions.
-}
shiftExpressionPositions : Int -> Expression -> Expression
shiftExpressionPositions delta expr =
    boostExpr (boost delta) expr


updateMeta : (ExprMeta -> ExprMeta) -> Expression -> Expression
updateMeta update expr =
    setMeta (update (getMeta expr)) expr


{-| A block whose content is a list of strings.
-}
type alias PrimitiveBlock =
    Block (List String) BlockMeta


{-| A block whose content is a list of expressions.
-}
type alias ExpressionBlock =
    Block (Either String (List Expression)) BlockMeta



-- SIMPLIFIED TYPES
-- GENERIC SIMPLIFIERS
-- ExprList (List (Expr metaData)) metaData
-- CONCRETE SIMPLIFIERS
-- VALUES


emptyBlockMeta : BlockMeta
emptyBlockMeta =
    { position = 0
    , lineNumber = 0
    , numberOfLines = 0
    , id = ""
    , messages = []
    , sourceText = ""
    , error = Nothing
    }



-- HELPERS


getName : ExpressionBlock -> Maybe String
getName block =
    getNameFromHeading block.heading


getNameFromHeading : Heading -> Maybe String
getNameFromHeading heading =
    case heading of
        Paragraph ->
            Nothing

        Ordinary name ->
            Just name

        Verbatim name ->
            Just name


getExpressionContent : ExpressionBlock -> List Expression
getExpressionContent block =
    case block.body of
        Left _ ->
            []

        Right exprs ->
            exprs


getVerbatimContent : ExpressionBlock -> Maybe String
getVerbatimContent block =
    case block.body of
        Left str ->
            Just str

        Right _ ->
            Nothing


getFunctionName : Expression -> Maybe String
getFunctionName expression =
    case expression of
        Fun name _ _ ->
            Just name

        VFun _ _ _ ->
            Nothing

        Text _ _ ->
            Nothing

        ExprList _ _ _ ->
            Nothing

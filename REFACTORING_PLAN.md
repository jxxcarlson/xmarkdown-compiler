# Refactoring Plan: Element → Html

## Overview
Convert XMarkdown compiler from elm-ui `Element msg` to raw `Html msg` throughout the rendering pipeline. This is a breaking change (v2.0.0).

## Key Changes
- **Public API**: Returns `Html MarkupMsg` instead of `Element MarkupMsg`
- **Dependencies**: Remove elm-ui (mdgriffith/elm-ui)
- **Message type**: Keep `MarkupMsg` for consistency
- **Styling**: Switch from elm-ui attributes to Html.Attributes + inline styles or CSS classes

---

## Phase 1: Core API Layer

### XMarkdown/API.elm
- [ ] Change `viewBodyOnly : Int -> CompilerOutput -> List (Html MarkupMsg)`
- [ ] Change `viewTOC : CompilerOutput -> List (Html MarkupMsg)`
- [ ] Change `compileSimple : CompilerParameters -> String -> List (Html MarkupMsg)`
- [ ] Change `compileStringWithTitle : String -> CompilerParameters -> String -> List (Html MarkupMsg)`
- [ ] Remove elm-ui imports (Element, Element.Font, etc.)

### XMarkdown/Compiler.elm
- [ ] Change `view : Int -> CompilerOutput -> List (Html MarkupMsg)`
- [ ] Change `viewBodyOnly : Int -> CompilerOutput -> List (Html MarkupMsg)`
- [ ] Change `viewTOC : CompilerOutput -> List (Html MarkupMsg)`
- [ ] Update `renderForest` signature to return `List (Html MarkupMsg)`

---

## Phase 2: Tree Rendering (Core Pipeline)

### Render/Tree.elm
- [ ] Change all render functions to return `Html MarkupMsg`
- [ ] Replace elm-ui Element composition with Html.div, Html.p, etc.
- [ ] Convert Element.column/row to Html.div with CSS Flexbox
- [ ] Eliminate: `renderLeafNode`, `renderBranchNode`, `renderStandardBranch` (consolidate logic)

### Render/TreeSupport.elm
- [ ] Change `renderBody : ... -> List (Html MarkupMsg)`
- [ ] Change `renderAttributes` to return `List (Html.Attribute MarkupMsg)`
- [ ] Replace elm-ui attribute builders with Html.Attributes

---

## Phase 3: Block Renderers

### Render/OrdinaryBlock.elm
- [ ] Change `render : ... -> Html MarkupMsg`
- [ ] Eliminate or simplify `indentOrdinaryBlock` (use CSS margin-left instead)

### Render/VerbatimBlock.elm
- [ ] Change `render : ... -> Html MarkupMsg`
- [ ] Keep SyntaxHighlight for now; wrap output in Html
- [ ] Functions to convert:
  - [ ] `renderCode`
  - [ ] `viewCodeWithHighlight`
  - [ ] `viewCodeWithHighlight_`
  - [ ] `renderVerbatim`
  - [ ] `renderVerse`

### Render/Blocks/Text.elm
- [ ] Change all block renderers to return `Html MarkupMsg`:
  - [ ] `centered`
  - [ ] `indented`
  - [ ] `compact`
  - [ ] `identity`
  - [ ] `red`, `red2`, `blue`
  - [ ] `quotation`

### Render/Blocks/Container.elm
- [ ] Update all container block renderers

### Render/Blocks/Document.elm
- [ ] Update title, subtitle renderers
- [ ] Eliminate `title` as separate element (merge into main flow)

### Render/Blocks/Stack.elm
- [ ] Update/eliminate as needed

### Render/GHTable.elm
- [ ] Change `render : ... -> Html MarkupMsg`
- [ ] Use Html.table, tr, td

### Render/List.elm
- [ ] Change `item`, `desc`, `numbered` to return `Html MarkupMsg`
- [ ] Use Html.li, Html.dl, etc.

---

## Phase 4: Expression Rendering

### Render/Expression.elm
- [ ] Change `render : ... -> Html MarkupMsg`
- [ ] Update all inline element rendering
- [ ] Replace Element.text with Html.text
- [ ] Replace Element.link with Html.a

### Render/VerbatimBlock.elm (inline code)
- [ ] Already covered above

---

## Phase 5: Helper & Utility Functions

### Render/Helper.elm
- [ ] Eliminate elm-ui dependent functions
- [ ] Functions to remove/refactor:
  - [ ] `blockAttributes` → eliminate (use CSS classes)
  - [ ] `noteFromPropertyKey` → convert to Html
  - [ ] `renderNothing` → Html.text ""
  - [ ] `noSuchVerbatimBlock` → Html error display
  - [ ] `features` → return CSS-friendly data structure
  - [ ] `leftPadding` → CSS margin-left
  - [ ] `selectedColor` → CSS class
  - [ ] `showError` → Html error rendering

### Render/Sync.elm
- [ ] Convert attribute functions to Html.Attributes
- [ ] Keep event handlers (onClick, etc.)
- [ ] Change `attributes : ... -> List (Html.Attribute MarkupMsg)`

### Render/Utility.elm
- [ ] Convert any Element-dependent functions
- [ ] `idAttributeFromInt` → Html.Attributes.id

### Render/Indentation.elm
- [ ] Eliminate or convert to CSS margin/padding utilities
- [ ] `indentOrdinaryBlock` → CSS class or inline style

---

## Phase 6: Math & Graphics

### Render/Math.elm
- [ ] Change `displayedMath`, `equation`, `aligned`, `array`, `chem` to return `Html MarkupMsg`

### Render/Graphics.elm
- [ ] Change `image2` to return `Html MarkupMsg`
- [ ] Keep or replace SyntaxHighlight rendering

### Render/Html/Math.elm
- [ ] Already returns Html; verify compatibility

---

## Phase 7: Styling & Theme

### Render/Settings.elm
- [ ] Keep RenderSettings structure but update field types
- [ ] Eliminate elm-ui color conversion functions
- [ ] Add CSS class generation utilities
- [ ] Keep `scaleFont` for sizing calculations

### Render/Theme.elm
- [ ] Keep color definitions
- [ ] Eliminate `getElementColor` (elm-ui specific)
- [ ] Add HTML color helper functions

### Render/NewColor.elm
- [ ] Keep as-is (color definitions only)

### Render/TOCTree.elm
- [ ] Change to return `List (Html MarkupMsg)`
- [ ] Replace elm-ui Element tree rendering with Html

### Render/Attributes.elm
- [ ] Convert to CSS class/style generators
- [ ] Replace `getBlockAttributes` with class name generation

---

## Phase 8: Constants & Cleanup

### Render/Constants.elm
- [ ] Update color constants if needed
- [ ] Keep dimensions

### Render/BlockType.elm
- [ ] Keep as-is (type definitions)

### Render/BlockRegistry.elm
- [ ] Update to work with `Html MarkupMsg` instead of `Element MarkupMsg`

---

## Elimination Candidates (Simplification)

These may be simplified or removed to reduce complexity:

- [ ] `Render/Indentation.elm` → Replace with CSS utilities
- [ ] `Render/Blocks/Document.elm` → Merge title handling into Tree.elm
- [ ] Complex attribute builders → Replace with CSS class generation
- [ ] `renderLeafNode` / `renderBranchNode` → Consolidate into single render path
- [ ] Element-specific color converters → Keep only Html-compatible versions

---

## Implementation Strategy

1. **Start at the leaves** (helpers, math, graphics) and work up to the root
2. **Batch similar changes** (e.g., all block renderers at once)
3. **Test after each phase** by running elm make
4. **Use branch** for this work to keep main stable
5. **Update CLAUDE.md** to document new architecture

---

## Files to Create

- [ ] `Render/Html/Attributes.elm` - CSS class/style generators
- [ ] `Render/Html/Layout.elm` - Layout utilities (flexbox helpers)
- [ ] `Render/Css.elm` - Global CSS constants/helpers

---

## Files to Delete

- Remove elm-ui dependency from elm.json
- All obsolete elm-ui wrapper files once refactored

---

## Testing Strategy

- [ ] Compile after each phase
- [ ] Run tests after major changes
- [ ] Compare rendered output in DemoTOCMd before/after (visual regression test)
- [ ] Verify message routing still works (MarkupMsg handling)

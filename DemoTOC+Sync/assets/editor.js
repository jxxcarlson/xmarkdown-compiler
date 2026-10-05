// Minimal CodeMirror 6 custom element for DemoTOC+Sync.
console.log("editor.js: starting to load dependencies");
import { basicSetup, EditorView } from "../node_modules/codemirror/dist/index.js";
import { EditorState, StateField, StateEffect } from "../node_modules/@codemirror/state/dist/index.js";
import { Decoration, keymap } from "../node_modules/@codemirror/view/dist/index.js";
console.log("editor.js: dependencies loaded successfully");

// RL sync: a background decoration over the source span the user clicked.
const setSyncHighlight = StateEffect.define();
const clearSyncHighlight = StateEffect.define();
const syncMark = Decoration.mark({ class: "cm-sync-highlight" });

const syncHighlightField = StateField.define({
    create() {
        return Decoration.none;
    },
    update(deco, tr) {
        for (const e of tr.effects) {
            if (e.is(setSyncHighlight)) {
                return Decoration.set([syncMark.range(e.value.from, e.value.to)]);
            }
            if (e.is(clearSyncHighlight)) {
                return Decoration.none;
            }
        }
        // Clear the highlight on any document edit (user typing or programmatic).
        if (tr.docChanged) {
            return Decoration.none;
        }
        return deco.map(tr.changes);
    },
    provide: (f) => EditorView.decorations.from(f),
});

// Markdown syntax highlighting: headings, bold, italic, code, links, quotes, lists
const markdownSyntax = StateField.define({
    create() {
        return Decoration.none;
    },
    update(deco, tr) {
        try {
            const decorations = [];
            const doc = tr.state.doc.toString();
            const lines = doc.split('\n');
            let pos = 0;

            for (let lineNum = 0; lineNum < lines.length; lineNum++) {
                const line = lines[lineNum];
                const lineStart = pos;

                // Headings: # ## ### at start of line
                const headingMatch = line.match(/^(#{1,6})\s+(.+)$/);
                if (headingMatch) {
                    const level = headingMatch[1].length;
                    const levelClass = `cm-md-h${level}`;
                    decorations.push(Decoration.mark({ class: levelClass }).range(lineStart, lineStart + headingMatch[0].length));
                }

                // Block quotes: lines starting with >
                if (line.match(/^\s*>\s/)) {
                    decorations.push(Decoration.mark({ class: "cm-md-quote" }).range(lineStart, lineStart + line.length));
                }

                // Lists: lines starting with - * + or digits.
                if (line.match(/^\s*([*\-+]|\d+\.)\s+/)) {
                    decorations.push(Decoration.mark({ class: "cm-md-list" }).range(lineStart, lineStart + line.length));
                }

                // Inline patterns: bold, italic, code, links (within the line)
                // Bold: **text** or __text__
                let boldRegex = /(\*\*|__)(.+?)\1/g;
                let match;
                while ((match = boldRegex.exec(line)) !== null) {
                    decorations.push(Decoration.mark({ class: "cm-md-strong" }).range(lineStart + match.index, lineStart + match.index + match[0].length));
                }

                // Italic: *text* or _text_ (but not inside bold)
                let italicRegex = /(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)|(?<!_)_(?!_)(.+?)(?<!_)_(?!_)/g;
                while ((match = italicRegex.exec(line)) !== null) {
                    decorations.push(Decoration.mark({ class: "cm-md-em" }).range(lineStart + match.index, lineStart + match.index + match[0].length));
                }

                // Code: `text`
                let codeRegex = /`([^`]+)`/g;
                while ((match = codeRegex.exec(line)) !== null) {
                    decorations.push(Decoration.mark({ class: "cm-md-code" }).range(lineStart + match.index, lineStart + match.index + match[0].length));
                }

                // Links: [text](url)
                let linkRegex = /\[([^\]]+)\]\(([^\)]+)\)/g;
                while ((match = linkRegex.exec(line)) !== null) {
                    decorations.push(Decoration.mark({ class: "cm-md-link" }).range(lineStart + match.index, lineStart + match.index + match[0].length));
                }

                pos += line.length + 1; // +1 for newline
            }

            return Decoration.set(decorations);
        } catch (err) {
            console.error("Error in markdownSyntax:", err);
            return deco;
        }
    },
    provide: (f) => EditorView.decorations.from(f),
});

// XMarkdown-specific syntax: @[...] macros, $$...$$ math blocks, and $ ... $ inline math
const xmarkdownSyntax = StateField.define({
    create() {
        return Decoration.none;
    },
    update(deco, tr) {
        try {
            const allDecorations = [];
            const doc = tr.state.doc.toString();

            // Collect all decorations with position info
            const decorationList = [];

            // Highlight @[...] macros
            const macroRegex = /@\[[^\]]*\]/g;
            let match;
            while ((match = macroRegex.exec(doc)) !== null) {
                decorationList.push({
                    from: match.index,
                    to: match.index + match[0].length,
                    decoration: Decoration.mark({ class: "cm-xmd-macro" })
                });
            }

            // Highlight $$...$$ math blocks (both single-line and multi-line)
            const blockMatches = [];

            // Multi-line blocks: $$ + newline, content, then (blank line OR closing $$)
            const multilineBlockRegex = /\$\$\n([\s\S]*?)(?:\n\$\$|\n\n)/g;
            while ((match = multilineBlockRegex.exec(doc)) !== null) {
                console.log("Math block match:", match[0].slice(0, 50), "at", match.index);
                blockMatches.push({ start: match.index, end: match.index + match[0].length });
                decorationList.push({
                    from: match.index,
                    to: match.index + match[0].length,
                    decoration: Decoration.mark({ class: "cm-xmd-math" })
                });
            }

            // Single-line blocks: $$content$$ (not followed by content on same line, or at end of line)
            const singlelineBlockRegex = /\$\$([^\n]*?)\$\$(?=\s*$|\s+[^$])/gm;
            while ((match = singlelineBlockRegex.exec(doc)) !== null) {
                // Make sure this isn't part of inline math (check context)
                const beforeIdx = Math.max(0, match.index - 1);
                const afterIdx = match.index + match[0].length;
                const charBefore = beforeIdx > 0 ? doc[beforeIdx] : ' ';
                const charAfter = afterIdx < doc.length ? doc[afterIdx] : ' ';

                // Only treat as block if not surrounded by word characters or other $
                if (!/\w/.test(charBefore) && !/\w/.test(charAfter) && charBefore !== '$' && charAfter !== '$') {
                    console.log("Single-line math block:", match[0].slice(0, 50), "at", match.index);
                    blockMatches.push({ start: match.index, end: match.index + match[0].length });
                    decorationList.push({
                        from: match.index,
                        to: match.index + match[0].length,
                        decoration: Decoration.mark({ class: "cm-xmd-math" })
                    });
                }
            }

            console.log("Total block matches:", blockMatches.length);

            // Highlight table syntax: pipes, separators, and cell backgrounds
            // Tables have format: | col1 | col2 | ... | and separator rows |---|
            const lines = doc.split('\n');
            let linePos = 0;
            for (let i = 0; i < lines.length; i++) {
                const line = lines[i];
                // Match lines with pipes that look like table rows
                if (line.includes('|')) {
                    const isSeparator = /^\s*\|[\s\-:|\s]+\|\s*$/.test(line);
                    const isTableRow = /^\s*\|.+\|\s*$/.test(line);

                    if (isSeparator || isTableRow) {
                        console.log("Table row:", line.slice(0, 40), "at", linePos);

                        if (isSeparator) {
                            // Highlight entire separator row
                            decorationList.push({
                                from: linePos,
                                to: linePos + line.length,
                                decoration: Decoration.mark({ class: "cm-xmd-table-sep" })
                            });
                        } else {
                            // For data rows, highlight pipes and cell backgrounds separately
                            // Highlight pipes
                            let pipePos = 0;
                            while ((pipePos = line.indexOf('|', pipePos)) !== -1) {
                                decorationList.push({
                                    from: linePos + pipePos,
                                    to: linePos + pipePos + 1,
                                    decoration: Decoration.mark({ class: "cm-xmd-table-pipe" })
                                });
                                pipePos++;
                            }

                            // Highlight cell backgrounds (between pipes)
                            const cells = line.split('|').slice(1, -1); // Remove empty strings from start/end
                            let cellStart = linePos + line.indexOf('|') + 1;
                            for (let j = 0; j < cells.length; j++) {
                                const cellEnd = cellStart + cells[j].length;
                                if (cellStart < cellEnd) {
                                    decorationList.push({
                                        from: cellStart,
                                        to: cellEnd,
                                        decoration: Decoration.mark({ class: "cm-xmd-table-cell" })
                                    });
                                }
                                cellStart = cellEnd + 1; // +1 for the pipe
                            }
                        }
                    }
                }
                linePos += line.length + 1; // +1 for newline
            }

            // Highlight code blocks (```...```)
            const codeBlockRegex = /```[\s\S]*?```/g;
            while ((match = codeBlockRegex.exec(doc)) !== null) {
                console.log("Code block match at", match.index);
                decorationList.push({
                    from: match.index,
                    to: match.index + match[0].length,
                    decoration: Decoration.mark({ class: "cm-xmd-code-block" })
                });
            }

            // Highlight inline code `...`
            const inlineCodeRegex = /`[^`\n]+`/g;
            while ((match = inlineCodeRegex.exec(doc)) !== null) {
                console.log("Inline code match:", match[0], "at", match.index);
                decorationList.push({
                    from: match.index,
                    to: match.index + match[0].length,
                    decoration: Decoration.mark({ class: "cm-xmd-code" })
                });
            }

            // Highlight $ ... $ inline math (skip if inside a block)
            const inlineMathRegex = /\$[^\$\n]+\$/g;
            while ((match = inlineMathRegex.exec(doc)) !== null) {
                // Check if this match is inside a block math region
                const isInBlock = blockMatches.some(b => match.index >= b.start && match.index + match[0].length <= b.end);
                if (!isInBlock) {
                    console.log("Inline math match:", match[0], "at", match.index, "isInBlock:", isInBlock);
                    decorationList.push({
                        from: match.index,
                        to: match.index + match[0].length,
                        decoration: Decoration.mark({ class: "cm-xmd-inline-math" })
                    });
                } else {
                    console.log("Skipping inline math inside block:", match[0], "at", match.index);
                }
            }

            // Sort ALL decorations by position and convert
            decorationList.sort((a, b) => a.from - b.from);
            for (const d of decorationList) {
                allDecorations.push(d.decoration.range(d.from, d.to));
            }
            console.log("Total decorations:", allDecorations.length);

            return Decoration.set(allDecorations);
        } catch (err) {
            console.error("Error in xmarkdownSyntax:", err);
            return deco;
        }
    },
    provide: (f) => EditorView.decorations.from(f),
});

// Indentation guides: faint vertical lines at each 2-space indent stop, so
// nested/indented source is easier to scan. The bar color comes from the theme
// via the --cm-indent-guide CSS variable (set by app.js on theme change); the
// fallback matches the light theme so guides are correct before the first toggle.
const INDENT_UNIT = 2; // spaces per indent level
const GUIDE_OFFSET_PX = 4; // aligns the first bar with the .cm-line left padding; tuned by eye

function indentGuideStyle(levels, w) {
    // Paint a faint background band across the `w` leading spaces, then `levels`
    // 1px-wide vertical bars at character columns 0, 2, 4, ... on top of it.
    // Monospace font => 1ch == one character advance, so bars land on the grid.
    // The band reuses the theme guide color at reduced strength so it tracks the
    // theme (deep blue light / deep orange dark) without extra plumbing.
    const images = [];
    const positions = [];
    const sizes = [];
    if (w > 0) {
        const band = "color-mix(in srgb, var(--cm-indent-guide, rgba(0,0,0,0.15)) 22%, transparent)";
        images.push(`linear-gradient(${band}, ${band})`);
        positions.push(`${GUIDE_OFFSET_PX}px 0`);
        sizes.push(`${w}ch 100%`);
    }
    const bar = "linear-gradient(var(--cm-indent-guide, rgba(0,0,0,0.15)), var(--cm-indent-guide, rgba(0,0,0,0.15)))";
    for (let i = 0; i < levels; i++) {
        images.push(bar);
        positions.push(`calc(${i * INDENT_UNIT}ch + ${GUIDE_OFFSET_PX}px) 0`);
        sizes.push("1px 100%");
    }
    return `background-image: ${images.join(", ")};` +
        `background-position: ${positions.join(", ")};` +
        `background-size: ${sizes.join(", ")};` +
        `background-repeat: no-repeat;`;
}

function buildIndentGuides(state) {
    const decorations = [];
    const doc = state.doc;
    for (let n = 1; n <= doc.lines; n++) {
        const line = doc.line(n);
        const text = line.text;
        let w = 0;
        while (w < text.length && text[w] === " ") w++;
        const levels = Math.floor(w / INDENT_UNIT);
        if (w > 0) {
            decorations.push(
                Decoration.line({ attributes: { style: indentGuideStyle(levels, w) } }).range(line.from)
            );
        }
    }
    return Decoration.set(decorations);
}

const indentGuideField = StateField.define({
    create(state) {
        return buildIndentGuides(state);
    },
    update(deco, tr) {
        // Guides depend only on line indentation, so recompute on doc changes.
        if (tr.docChanged) {
            return buildIndentGuides(tr.state);
        }
        return deco.map(tr.changes);
    },
    provide: (f) => EditorView.decorations.from(f),
});

const lightTheme = EditorView.theme(
    {
        "&": {
            color: "var(--cm-fg, #1a1a1a)",
            backgroundColor: "var(--cm-bg, #ffffff)",
            height: "100%",
        },
        ".cm-content": {
            caretColor: "var(--cm-caret, rgba(255,80,0,0.7))",
            fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace",
            fontSize: "14px",
        },
        ".cm-cursor, .cm-dropCursor": {
            borderLeftColor: "var(--cm-caret, rgba(255,80,0,0.7))",
            borderLeftWidth: "2px",
        },
        ".cm-scroller": { overflow: "auto" },
        "&.cm-focused > .cm-scroller > .cm-selectionLayer .cm-selectionBackground, .cm-selectionBackground, .cm-content ::selection":
            { backgroundColor: "var(--cm-selection-bg, #d7e6ff)" },
        ".cm-gutters": {
            backgroundColor: "var(--cm-gutter-bg, #f4f4f4)",
            color: "var(--cm-gutter-fg, #999)",
            border: "none",
        },
        ".cm-sync-highlight": {
            backgroundColor: "var(--cm-sync-highlight-bg, #fff3b0)",
        },
        // Markdown elements
        ".cm-md-h1, .cm-md-h2, .cm-md-h3, .cm-md-h4, .cm-md-h5, .cm-md-h6": {
            color: "#0066cc",
            fontWeight: "bold",
        },
        ".cm-md-h1": { fontSize: "120%" },
        ".cm-md-h2": { fontSize: "110%" },
        ".cm-md-h3": { fontSize: "105%" },
        ".cm-md-strong": {
            fontWeight: "bold",
            color: "#333",
        },
        ".cm-md-em": {
            fontStyle: "italic",
            color: "#666",
        },
        ".cm-md-code": {
            backgroundColor: "#f0f8f0",
            color: "#0d3d0d",
            fontFamily: "monospace",
        },
        ".cm-md-link": {
            color: "#0066cc",
            textDecoration: "underline",
        },
        ".cm-md-quote": {
            color: "#6a737d",
            fontStyle: "italic",
        },
        ".cm-md-list": {
            color: "#6a737d",
        },
        // XMarkdown elements
        ".cm-xmd-macro": {
            color: "#6f42c1",
            fontWeight: "bold",
        },
        ".cm-xmd-math": {
            color: "#d73a49",
            backgroundColor: "#f6f8fa",
        },
        ".cm-xmd-inline-math": {
            color: "#d73a49",
            backgroundColor: "#ffe6e6",
        },
        ".cm-xmd-table-pipe": {
            color: "#6f42c1",
            fontWeight: "bold",
        },
        ".cm-xmd-table-cell": {
            backgroundColor: "#f0f7ff",
        },
        ".cm-xmd-table-sep": {
            backgroundColor: "#e8f0ff",
            color: "#6f42c1",
        },
        ".cm-xmd-code-block": {
            backgroundColor: "#f0f8f0",
            color: "#0d3d0d",
            fontFamily: "monospace",
        },
        ".cm-xmd-code": {
            backgroundColor: "#f0f8f0",
            color: "#0d3d0d",
            fontFamily: "monospace",
        },
    },
    { dark: false }
);

function sendText(editor) {
    const event = new CustomEvent("text-change", {
        detail: {
            source: editor.state.doc.toString(),
            position: editor.state.selection.main.head,
        },
        bubbles: true,
        composed: true,
    });
    editor.dom.dispatchEvent(event);
}

class CodemirrorEditor extends HTMLElement {
    static get observedAttributes() {
        return ["load", "highlight"];
    }

    constructor() {
        super();
        // Attribute changes can arrive before the EditorView exists (it is
        // created in a deferred setTimeout). Buffer them here.
        this.pendingAttributes = {};
    }

    connectedCallback() {
        console.log("editor.js: connectedCallback triggered");
        this.style.display = "block";
        this.style.height = "100%";

        // Defer creation one tick so layout/dimensions settle first.
        setTimeout(() => {
            const editor = new EditorView({
                state: EditorState.create({
                    doc: "",
                    extensions: [
                        basicSetup,
                        lightTheme,
                        // markdownSyntax,
                        // xmarkdownSyntax,
                        EditorView.lineWrapping,
                        syncHighlightField,
                        indentGuideField,
                        keymap.of([
                            {
                                key: "Escape",
                                run: (view) => {
                                    view.dispatch({ effects: clearSyncHighlight.of(null) });
                                    return true;
                                },
                            },
                            {
                                key: "Mod-s",
                                run: (view) => {
                                    console.log("Ctrl+S pressed");
                                    const selection = view.state.sliceDoc(view.state.selection.main.from, view.state.selection.main.to);
                                    console.log("Selected text:", selection);
                                    if (selection) {
                                        const event = new CustomEvent("lr-sync", {
                                            detail: { text: selection },
                                            bubbles: true,
                                            composed: true,
                                        });
                                        console.log("Dispatching lr-sync event with text:", selection);
                                        view.dom.dispatchEvent(event);
                                    }
                                    return true;
                                },
                            },
                        ]),
                        EditorView.updateListener.of((v) => {
                            if (!v.docChanged) return;
                            if (editor.isProgrammaticUpdate) {
                                editor.isProgrammaticUpdate = false; // suppress echo
                            } else {
                                sendText(editor);
                            }
                        }),
                    ],
                }),
                parent: this,
            });
            this.editor = editor;

            for (const attr in this.pendingAttributes) {
                this.handleAttributeChange(attr, this.pendingAttributes[attr]);
            }
            this.pendingAttributes = {};
        }, 0);
    }

    handleAttributeChange(attr, value) {
        if (attr === "load" && typeof value === "string") {
            const editor = this.editor;
            // Nothing to replace: dispatching anyway would produce no doc change,
            // leave isProgrammaticUpdate set, and swallow the user's first edit.
            if (editor.state.doc.toString() === value) return;
            // Replace the whole document without echoing a text-change back to Elm.
            editor.isProgrammaticUpdate = true;
            editor.dispatch({
                changes: { from: 0, to: editor.state.doc.length, insert: value },
            });
        }
        if (attr === "highlight" && typeof value === "string") {
            const editor = this.editor;
            let h;
            try {
                h = JSON.parse(value);
            } catch (e) {
                return; // malformed payload: ignore
            }
            const doc = editor.state.doc;
            if (!h) return;
            let from;
            let to;
            if (h.mode === "lines") {
                // start/end are 1-indexed source lines, both inclusive.
                const firstLine = Math.max(1, Math.min(h.start, doc.lines));
                const lastLine = Math.max(firstLine, Math.min(h.end, doc.lines));
                from = doc.line(firstLine).from;
                to = doc.line(lastLine).to;
            } else {
                // "chars": start/end are absolute document character offsets (end exclusive).
                from = Math.max(0, Math.min(h.start, doc.length));
                to = Math.max(from, Math.min(h.end, doc.length));
            }
            this.showSourceSpan(from, to);
        }
    }

    // Highlight source characters [from, to) and scroll them into view.
    showSourceSpan(from, to) {
        const editor = this.editor;
        if (!editor) return;
        editor.dispatch({
            effects: [setSyncHighlight.of({ from, to })],
        });
        // Center the target line by writing the editor scroller's scrollTop
        // directly, instead of EditorView.scrollIntoView. CM's scrollIntoView
        // walks ancestor elements too (even overflow:hidden ones are
        // programmatically scrollable), which dragged the whole app shell up
        // when the target was near the end of the document. A direct
        // scrollTop write is clamped by the browser to the scroller's own
        // valid range: true centering everywhere, graceful clamp at the ends,
        // and the shell never moves.
        editor.requestMeasure({
            read: (view) => {
                const block = view.lineBlockAt(from);
                const scroller = view.scrollDOM;
                return {
                    scroller,
                    target: block.top - (scroller.clientHeight - block.height) / 2,
                };
            },
            write: ({ scroller, target }) => {
                scroller.scrollTop = target; // browser clamps to [0, max]
            },
        });
    }

    attributeChangedCallback(attr, oldVal, newVal) {
        if (this.editor) {
            this.handleAttributeChange(attr, newVal);
        } else {
            this.pendingAttributes[attr] = newVal;
        }
    }
}

// RL sync, rendered -> source. Each prose run in the rendered text is a
// <span data-src-begin data-src-end> giving the run's absolute source offsets
// (end inclusive), and its text matches the source character for character
// (tests/OffsetRoundTripTest.elm). So:
//   - a click highlights the word under the pointer;
//   - a selection highlights the corresponding source range.
// Clicks elsewhere (math, code, tables, ...) fall through to Elm, which
// highlights the whole block (SendLineNumber).

const WORD_CHAR = /[\p{L}\p{N}_'’-]/u;

// The run span holding `node` and the run's offsets, or null.
function runOf(node) {
    const el = node && (node.nodeType === Node.TEXT_NODE ? node.parentElement : node);
    const span = el && el.closest && el.closest("[data-src-begin]");
    if (!span || span.closest("a")) return null;
    const begin = parseInt(span.getAttribute("data-src-begin"), 10);
    const end = parseInt(span.getAttribute("data-src-end"), 10);
    if (isNaN(begin) || isNaN(end)) return null;
    return { span, begin, length: end - begin + 1 };
}

// Source offset of a DOM position inside a run's text node, or null.
function sourceOffset(node, offset) {
    if (!node || node.nodeType !== Node.TEXT_NODE) return null;
    const run = runOf(node);
    if (!run) return null;
    return run.begin + Math.min(offset, run.length);
}

// The source span [from, to) of the word at a click, or null.
function wordAt(node, offset, doc) {
    if (!node || node.nodeType !== Node.TEXT_NODE) return null;
    const run = runOf(node);
    if (!run) return null;
    const text = node.data.slice(0, run.length); // drop the renderer's trailing " "
    let i = Math.min(offset, text.length);
    if (!WORD_CHAR.test(text[i] || "") && WORD_CHAR.test(text[i - 1] || "")) i -= 1;
    if (!WORD_CHAR.test(text[i] || "")) return null;
    let a = i;
    let b = i + 1;
    while (a > 0 && WORD_CHAR.test(text[a - 1])) a -= 1;
    while (b < text.length && WORD_CHAR.test(text[b])) b += 1;
    const word = { from: run.begin + a, to: run.begin + b };
    // Guard against a stale render (source edited since): if the source no
    // longer has this word there, highlight the whole run instead.
    if (doc.sliceString(word.from, word.to) !== text.slice(a, b)) {
        return { from: run.begin, to: run.begin + run.length };
    }
    return word;
}

// The source span [from, to) of a selection. An end outside any run (e.g. in
// math) snaps to the nearest run inside the selection.
function rangeOf(range) {
    let from = sourceOffset(range.startContainer, range.startOffset);
    let to = sourceOffset(range.endContainer, range.endOffset);
    if (from === null || to === null) {
        let root = range.commonAncestorContainer;
        if (root.nodeType !== Node.ELEMENT_NODE) root = root.parentElement;
        const runs = [...root.querySelectorAll("[data-src-begin]")]
            .filter((span) => range.intersectsNode(span))
            .map(runOf)
            .filter(Boolean);
        if (runs.length === 0) return null;
        if (from === null) from = runs[0].begin;
        if (to === null) to = runs[runs.length - 1].begin + runs[runs.length - 1].length;
    }
    return from < to ? { from, to } : { from: to, to: from };
}

let swallowNextClick = false;

document.addEventListener("mousedown", () => {
    swallowNextClick = false;
});

document.addEventListener("mouseup", (event) => {
    if (event.button !== 0) return;
    const host = document.querySelector("codemirror-editor");
    const sel = window.getSelection();
    if (!host || !host.editor || !sel || sel.rangeCount === 0) return;
    if (host.contains(sel.anchorNode)) return; // a selection in the editor itself
    const doc = host.editor.state.doc;
    const span = sel.isCollapsed ? wordAt(sel.anchorNode, sel.anchorOffset, doc) : rangeOf(sel.getRangeAt(0));
    if (!span) return;
    const from = Math.max(0, Math.min(span.from, doc.length));
    const to = Math.max(from, Math.min(span.to, doc.length));
    host.showSourceSpan(from, to);
    // The click that follows would make Elm highlight the whole block.
    swallowNextClick = true;
});

window.addEventListener(
    "click",
    (event) => {
        if (!swallowNextClick) return;
        swallowNextClick = false;
        event.stopPropagation();
    },
    true
);

console.log("editor.js: registering custom element");
customElements.define("codemirror-editor", CodemirrorEditor);
console.log("editor.js: custom element registered successfully");

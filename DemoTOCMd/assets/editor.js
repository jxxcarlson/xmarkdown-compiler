// Minimal CodeMirror 6 custom element for DemoTOCMd.
// Imports without ?bundle so esm.sh shares one @codemirror/state instance
// (duplicate state instances cause "unrecognized extension" errors).
console.log("editor.js: starting to load dependencies");
import { basicSetup, EditorView } from "https://esm.sh/codemirror@6.0.1";
import { EditorState, StateField, StateEffect } from "https://esm.sh/@codemirror/state@6";
import { Decoration, keymap } from "https://esm.sh/@codemirror/view@6";
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
            backgroundColor: "#f0f0f0",
            color: "#d73a49",
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
                        markdownSyntax,
                        xmarkdownSyntax,
                        EditorView.lineWrapping,
                        syncHighlightField,
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
            editor.dispatch({
                effects: [
                    setSyncHighlight.of({ from, to }),
                    EditorView.scrollIntoView(from, { y: "center" }),
                ],
            });
        }
    }

    attributeChangedCallback(attr, oldVal, newVal) {
        if (this.editor) {
            this.handleAttributeChange(attr, newVal);
        } else {
            this.pendingAttributes[attr] = newVal;
        }
    }
}

console.log("editor.js: registering custom element");
customElements.define("codemirror-editor", CodemirrorEditor);
console.log("editor.js: custom element registered successfully");

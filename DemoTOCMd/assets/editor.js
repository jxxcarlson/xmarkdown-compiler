// Minimal CodeMirror 6 custom element for DemoTOCMd.
// Imports without ?bundle so esm.sh shares one @codemirror/state instance
// (duplicate state instances cause "unrecognized extension" errors).
console.log("editor.js: starting to load dependencies");
import { basicSetup, EditorView } from "https://esm.sh/codemirror@6.0.1";
import { EditorState, StateField, StateEffect } from "https://esm.sh/@codemirror/state@6";
import { Decoration, keymap, syntaxHighlighting, HighlightStyle } from "https://esm.sh/@codemirror/view@6";
import { markdown } from "https://esm.sh/@codemirror/lang-markdown@6";
import { tags } from "https://esm.sh/@lezer/highlight@1";
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

// XMarkdown syntax highlighting
const xmarkdownHighlight = HighlightStyle.define([
    { tag: tags.heading1, class: "cm-xmd-h1" },
    { tag: tags.heading2, class: "cm-xmd-h2" },
    { tag: tags.heading3, class: "cm-xmd-h3" },
    { tag: tags.emphasis, class: "cm-xmd-em" },
    { tag: tags.strong, class: "cm-xmd-strong" },
    { tag: tags.link, class: "cm-xmd-link" },
    { tag: tags.monospace, class: "cm-xmd-code" },
    { tag: tags.quote, class: "cm-xmd-quote" },
    { tag: tags.list, class: "cm-xmd-list" },
]);

// XMarkdown-specific syntax: @[...] macros, $$...$$ math blocks, and $ ... $ inline math
const xmarkdownSyntax = StateField.define({
    create() {
        return Decoration.none;
    },
    update(deco, tr) {
        const decorations = [];
        const doc = tr.state.doc.toString();

        // Highlight @[...] macros
        const macroRegex = /@\[[^\]]*\]/g;
        let match;
        while ((match = macroRegex.exec(doc)) !== null) {
            decorations.push(
                Decoration.mark({ class: "cm-xmd-macro" }).range(match.index, match.index + match[0].length)
            );
        }

        // Highlight $$...$$ math blocks (process these first to avoid matching inline math inside blocks)
        const mathBlockRegex = /\$\$[\s\S]*?\$\$/g;
        const blockMatches = [];
        while ((match = mathBlockRegex.exec(doc)) !== null) {
            blockMatches.push({ start: match.index, end: match.index + match[0].length });
            decorations.push(
                Decoration.mark({ class: "cm-xmd-math" }).range(match.index, match.index + match[0].length)
            );
        }

        // Highlight $ ... $ inline math (skip if inside a block)
        const inlineMathRegex = /\$[^\$\n]+\$/g;
        while ((match = inlineMathRegex.exec(doc)) !== null) {
            // Check if this match is inside a block math region
            const isInBlock = blockMatches.some(b => match.index >= b.start && match.index + match[0].length <= b.end);
            if (!isInBlock) {
                decorations.push(
                    Decoration.mark({ class: "cm-xmd-inline-math" }).range(match.index, match.index + match[0].length)
                );
            }
        }

        return Decoration.set(decorations);
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
        ".cm-xmd-h1, .cm-xmd-h2, .cm-xmd-h3": {
            color: "#0066cc",
            fontWeight: "bold",
        },
        ".cm-xmd-h1": { fontSize: "120%" },
        ".cm-xmd-h2": { fontSize: "110%" },
        ".cm-xmd-h3": { fontSize: "105%" },
        ".cm-xmd-strong": {
            fontWeight: "bold",
            color: "#333",
        },
        ".cm-xmd-em": {
            fontStyle: "italic",
            color: "#666",
        },
        ".cm-xmd-code": {
            backgroundColor: "#f0f0f0",
            color: "#d73a49",
            fontFamily: "monospace",
        },
        ".cm-xmd-link": {
            color: "#0066cc",
            textDecoration: "underline",
        },
        ".cm-xmd-quote": {
            color: "#6a737d",
            fontStyle: "italic",
        },
        ".cm-xmd-list": {
            color: "#6a737d",
        },
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
            backgroundColor: "#fffbea",
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
                        markdown(),
                        syntaxHighlighting(xmarkdownHighlight),
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

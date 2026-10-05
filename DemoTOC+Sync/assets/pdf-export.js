// File > Export PDF.
//
// Elm exports the document to LaTeX (LaTeX.Export) and sends it here.
// - Browser: the local server started by run.sh (serve.py) downloads the
//   images, runs pdflatex and returns the PDF, which is saved as a download.
// - Desktop (Tauri): a native save dialog picks the PDF's location, and the
//   Rust command export_pdf does the same work as serve.py and writes it there.
//   The saved PDF is then shown in the app (showPdfInApp) until closed, below
//   the header so the File menu stays usable: Elm is told on desktopResponse
//   ({ kind: "pdfShown", path } / path null when closed) and offers File >
//   Print, which desktop.js sends to the Rust command print_pdf.
//
// (The Netlify site has neither, and hides the menu item: see Main.Flags.)
//
// Ports (see src/Ports.elm):
//   exportPdf   (Elm -> JS) { name, tex, images: [[url, localPath], ...] }
//   pdfExported (JS -> Elm) null on success, otherwise a short error message
//                           for the header notice (details go to the console)

let pdfApp = null;

function initPdfExport(app) {
    if (!app.ports.exportPdf) return;
    pdfApp = app;

    app.ports.exportPdf.subscribe(async ({ name, tex, images }) => {
        if (window.__TAURI__) return exportOnDesktop(app, { name, tex, images });

        let response;
        try {
            response = await fetch("/export-pdf", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ name, tex, images }),
            });
        } catch (e) {
            app.ports.pdfExported.send("PDF export needs the local server: start the demo with ./run.sh");
            return;
        }

        if (response.status === 404 || response.status === 501) {
            app.ports.pdfExported.send("PDF export needs the local server: start the demo with ./run.sh");
            return;
        }

        if (!response.ok) {
            const body = await response.json().catch(() => ({}));
            console.error("PDF export failed. LaTeX source:\n" + tex);
            console.error("pdflatex log (tail):\n" + (body.error || response.statusText));
            app.ports.pdfExported.send("PDF export failed: " + firstLatexError(body.error) + " (details in the console)");
            return;
        }

        const blob = await response.blob();
        const url = URL.createObjectURL(blob);
        const link = document.createElement("a");
        link.href = url;
        link.download = name;
        document.body.appendChild(link);
        link.click();
        link.remove();
        setTimeout(() => URL.revokeObjectURL(url), 10000);

        const imageErrors = response.headers.get("X-Image-Errors");
        if (imageErrors) {
            console.warn("PDF export: images not downloaded: " + imageErrors);
            app.ports.pdfExported.send("PDF exported, but some images could not be downloaded (see the console)");
        } else {
            app.ports.pdfExported.send(null);
        }
    });
}

async function exportOnDesktop(app, { name, tex, images }) {
    const T = window.__TAURI__;
    const folder = window.xmDesktop && window.xmDesktop.currentFolder();
    let output;
    try {
        output = await T.dialog.save({
            defaultPath: folder ? folder + "/" + name : name,
            filters: [{ name: "PDF", extensions: ["pdf"] }],
        });
    } catch (e) {
        return app.ports.pdfExported.send("PDF export failed: " + e);
    }
    if (!output) return app.ports.pdfExported.send(null); // cancelled

    try {
        const { imageErrors } = await T.core.invoke("export_pdf", { tex, images, output });
        showPdfInApp(output);
        if (imageErrors.length > 0) {
            // No developer console in the desktop app: name the images here.
            app.ports.pdfExported.send(
                `PDF exported; ${imageErrors.length} image(s) could not be downloaded and are marked "image not available"`
            );
        } else {
            app.ports.pdfExported.send(null);
        }
    } catch (e) {
        app.ports.pdfExported.send("PDF export failed: " + firstLatexError(String(e)));
    }
}

// Show a saved PDF over the window below the header, in the web view's PDF viewer, with
// a bar holding its name and a Close button (Esc also closes). export_pdf has
// added the file to the asset protocol's scope, so convertFileSrc can load it.
function showPdfInApp(path) {
    closePdfViewer();
    const name = path.split("/").pop();

    // Below the header (File menu) and under its drop-down (z-index 10/11).
    const header = document.querySelector(".app-header");
    const top = header ? header.getBoundingClientRect().bottom : 0;
    const overlay = document.createElement("div");
    overlay.id = "pdf-viewer";
    overlay.style.cssText =
        `position:fixed;top:${top}px;left:0;right:0;bottom:0;z-index:9;display:flex;flex-direction:column;background:#525659;`;

    const bar = document.createElement("div");
    bar.style.cssText =
        "display:flex;align-items:center;gap:12px;padding:6px 12px;background:#2b2b2b;color:#eee;" +
        "font:13px -apple-system,system-ui,sans-serif;";
    const title = document.createElement("span");
    title.textContent = name;
    title.style.cssText = "flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;";
    const close = document.createElement("button");
    close.textContent = "Close";
    close.onclick = closePdfViewer;
    bar.append(title, close);

    const frame = document.createElement("iframe");
    frame.title = name;
    // The query string defeats the cache when the same file is exported again.
    frame.src = window.__TAURI__.core.convertFileSrc(path) + "?t=" + Date.now();
    frame.style.cssText = "flex:1;width:100%;border:0;background:#525659;";

    overlay.append(bar, frame);
    document.body.appendChild(overlay);
    document.addEventListener("keydown", closeOnEscape, true);
    pdfShown(path);
}

function pdfShown(path) {
    if (pdfApp && pdfApp.ports.desktopResponse) pdfApp.ports.desktopResponse.send({ kind: "pdfShown", path });
}

function closePdfViewer() {
    const overlay = document.getElementById("pdf-viewer");
    if (!overlay) return;
    overlay.remove();
    document.removeEventListener("keydown", closeOnEscape, true);
    pdfShown(null);
}

function closeOnEscape(event) {
    if (event.key === "Escape") {
        event.stopPropagation();
        closePdfViewer();
    }
}

// The first "! ..." line of a pdflatex log, e.g. "Undefined control sequence."
function firstLatexError(log) {
    if (!log) return "unknown error";
    const line = log.split("\n").find((l) => l.startsWith("!"));
    return line ? line.replace(/^!\s*/, "") : log.split("\n").filter((l) => l.trim()).slice(-1)[0] || "unknown error";
}

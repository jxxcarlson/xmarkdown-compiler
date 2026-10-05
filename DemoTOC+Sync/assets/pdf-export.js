// File > Export PDF.
//
// Elm exports the document to LaTeX (LaTeX.Export) and sends it here.
// - Browser: the local server started by run.sh (serve.py) downloads the
//   images, runs pdflatex and returns the PDF, which is saved as a download.
// - Desktop (Tauri): a native save dialog picks the PDF's location, and the
//   Rust command export_pdf does the same work as serve.py and writes it there.
//
// (The Netlify site has neither, and hides the menu item: see Main.Flags.)
//
// Ports (see src/Ports.elm):
//   exportPdf   (Elm -> JS) { name, tex, images: [[url, localPath], ...] }
//   pdfExported (JS -> Elm) null on success, otherwise a short error message
//                           for the header notice (details go to the console)

function initPdfExport(app) {
    if (!app.ports.exportPdf) return;

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

// The first "! ..." line of a pdflatex log, e.g. "Undefined control sequence."
function firstLatexError(log) {
    if (!log) return "unknown error";
    const line = log.split("\n").find((l) => l.startsWith("!"));
    return line ? line.replace(/^!\s*/, "") : log.split("\n").filter((l) => l.trim()).slice(-1)[0] || "unknown error";
}

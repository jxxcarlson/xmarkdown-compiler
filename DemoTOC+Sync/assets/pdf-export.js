// File > Export PDF.
//
// Elm exports the document to LaTeX (LaTeX.Export) and sends it here; the
// local server started by run.sh (serve.py) downloads the images, runs
// pdflatex and returns the PDF, which is saved as a download.
//
// Ports (see src/Ports.elm):
//   exportPdf   (Elm -> JS) { name, tex, images: [[url, localPath], ...] }
//   pdfExported (JS -> Elm) null on success, otherwise a short error message
//                           for the header notice (details go to the console)

function initPdfExport(app) {
    if (!app.ports.exportPdf) return;

    app.ports.exportPdf.subscribe(async ({ name, tex, images }) => {
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

// The first "! ..." line of a pdflatex log, e.g. "Undefined control sequence."
function firstLatexError(log) {
    if (!log) return "unknown error";
    const line = log.split("\n").find((l) => l.startsWith("!"));
    return line ? line.replace(/^!\s*/, "") : log.split("\n").filter((l) => l.trim()).slice(-1)[0] || "unknown error";
}

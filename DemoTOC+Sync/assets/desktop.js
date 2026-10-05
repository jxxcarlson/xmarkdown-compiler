// Desktop (Tauri) bridge. In a plain browser window.__TAURI__ is undefined and
// this does nothing; the web app keeps using the file picker and downloads.
//
// In the Tauri app (desktop/), File menu actions arrive from Elm on the
// `desktopRequest` port as { op, ... } and are answered on `desktopResponse`
// with { kind, ... } (see Main.desktopEventDecoder):
//
//   open                          -> opened  { path, name, folder, folderName, content }
//   openFolder                    -> folder  { folder, folderName }
//   save    { path, content, token, then? } -> saved { path, ..., token }
//   saveAs  { folder, name, content, token } -> savedAs { path, ..., token }
//   create  { folder, name }      -> created { path, name, folder, folderName }
//   confirmDiscard { name, then } -> (asks; finishes or cancels the close)
//   finish  { then }              -> (closes the window / quits)
//   printPdf { path }             -> (print panel; the PDF shown by pdf-export.js)
//   printDocument { name, tex, images } -> pdfGenerated, then the print panel
//                                    | printFailed { message }
//   any                           -> error   { message } | cancelled
//
// `token` is Elm's edit counter, echoed back so Elm knows which edit a save
// covered (auto-save). Closing the window or quitting is intercepted in Rust,
// which emits "xm-close" ("close" | "quit"); that is passed to Elm as
// closeRequested { then }, Elm saves (with `then`) or asks, and `finish` lets
// the close go ahead.
//
// File I/O goes through the Rust commands read_file / write_file / file_exists
// (desktop/src-tauri/src/lib.rs); dialogs through tauri-plugin-dialog.
//
// The path of the last file opened, saved or created is kept in localStorage
// and reopened at startup (if it still exists).

function initDesktop(app) {
    const T = window.__TAURI__;
    if (!T) return;

    const invoke = T.core.invoke;
    const MARKDOWN = [{ name: "Markdown", extensions: ["md", "markdown", "txt"] }];

    // Folder that file:// links resolve against: the folder of the open file,
    // or the one chosen with Open Folder.
    let currentFolder = null;

    function locate(path) {
        const i = path.lastIndexOf("/");
        const folder = i > 0 ? path.slice(0, i) : "/";
        return {
            path,
            name: path.slice(i + 1),
            folder,
            folderName: folder.split("/").filter(Boolean).pop() || "/",
        };
    }

    // Join and normalise "a/b/../c" style paths (macOS, so "/" only).
    function resolve(folder, relative) {
        const parts = [];
        const start = relative.startsWith("/") ? relative : folder + "/" + relative;
        for (const part of start.split("/")) {
            if (part === "" || part === ".") continue;
            if (part === "..") parts.pop();
            else parts.push(part);
        }
        return "/" + parts.join("/");
    }

    const LAST_FILE = "xmarkdown.lastFile";

    function rememberFile(path) {
        try {
            localStorage.setItem(LAST_FILE, path);
        } catch (e) {}
    }

    function lastFile() {
        try {
            return localStorage.getItem(LAST_FILE);
        } catch (e) {
            return null;
        }
    }

    function reply(message) {
        if (message.folder) currentFolder = message.folder;
        if (message.path && message.kind !== "error") rememberFile(message.path);
        app.ports.desktopResponse.send(message);
    }

    async function openPath(path) {
        const content = await invoke("read_file", { path });
        reply({ kind: "opened", ...locate(path), content });
    }

    async function saveAs({ folder, name, content, token }) {
        const path = await T.dialog.save({
            defaultPath: folder ? folder + "/" + name : name,
            filters: MARKDOWN,
        });
        if (!path) return reply({ kind: "cancelled" });
        await invoke("write_file", { path, contents: content });
        reply({ kind: "savedAs", ...locate(path), token });
    }

    // Let Rust close the window / quit, once Elm has saved or the user agreed.
    async function finish(then) {
        await invoke("finish_close", { then });
    }

    const handlers = {
        async open() {
            const path = await T.dialog.open({ multiple: false, directory: false, filters: MARKDOWN });
            if (!path) return reply({ kind: "cancelled" });
            await openPath(path);
        },
        async openFolder() {
            const folder = await T.dialog.open({ directory: true, multiple: false });
            if (!folder) return reply({ kind: "cancelled" });
            reply({ kind: "folder", folder, folderName: locate(folder + "/x").folderName });
        },
        async save({ path, content, token, then }) {
            await invoke("write_file", { path, contents: content });
            reply({ kind: "saved", ...locate(path), token });
            if (then) await finish(then);
        },
        async confirmDiscard({ name, then }) {
            const discard = await T.dialog.ask(
                `"${name}" has never been saved, so its changes will be lost.`,
                { title: then === "quit" ? "Quit XMarkdown?" : "Close XMarkdown?", kind: "warning", okLabel: "Discard", cancelLabel: "Cancel" }
            );
            if (discard) await finish(then);
            else await invoke("cancel_close");
        },
        async finish({ then }) {
            await finish(then);
        },
        async printPdf({ path }) {
            await invoke("print_pdf", { path });
        },
        // File > Print with no PDF shown: generate one in the temp folder
        // (like Export PDF, see pdf-export.js), then print it.
        async printDocument({ name, tex, images }) {
            const output = (await T.path.tempDir()).replace(/\/$/, "") + "/" + name;
            try {
                await invoke("export_pdf", { tex, images, output });
            } catch (e) {
                return reply({ kind: "printFailed", message: firstLatexError(String(e)) });
            }
            reply({ kind: "pdfGenerated" });
            await invoke("print_pdf", { path: output });
        },
        saveAs,
        async create({ folder, name }) {
            const path = resolve(folder, name);
            const where = locate(path);
            if (await invoke("file_exists", { path })) {
                return reply({ kind: "error", message: `${where.name} already exists in ${where.folderName}.` });
            }
            await invoke("write_file", { path, contents: "" });
            reply({ kind: "created", ...where });
        },
    };

    app.ports.desktopRequest.subscribe(async (request) => {
        const handler = handlers[request.op];
        if (!handler) return console.warn("desktop.js: unknown op", request);
        try {
            await handler(request);
        } catch (e) {
            reply({ kind: "error", message: String(e) });
            // A failed save during close: stay open; the next close tries again.
            if (request.then) await invoke("cancel_close").catch(() => {});
        }
    });

    T.event.listen("xm-close", (event) => {
        app.ports.desktopResponse.send({ kind: "closeRequested", then: event.payload });
    });

    // Called by file-links.js for a clicked [text](file://name.md).
    async function openLink(relative) {
        if (!currentFolder) {
            return reply({
                kind: "error",
                message: `To follow links to files such as ${relative}, first open a file or use Open Folder.`,
            });
        }
        const path = resolve(currentFolder, relative);
        try {
            if (!(await invoke("file_exists", { path }))) {
                return reply({ kind: "error", message: `${relative} was not found in ${locate(currentFolder + "/x").folderName}.` });
            }
            await openPath(path);
        } catch (e) {
            reply({ kind: "error", message: String(e) });
        }
    }

    window.xmDesktop = { openLink, currentFolder: () => currentFolder };

    // Reopen the most recently used file; if it is gone, keep the default doc.
    (async () => {
        const path = lastFile();
        if (!path) return;
        try {
            if (await invoke("file_exists", { path })) await openPath(path);
        } catch (e) {
            console.warn("desktop.js: could not reopen", path, e);
        }
    })();

    // http(s) links would otherwise replace the app inside its own window;
    // open them in the default browser instead.
    document.addEventListener(
        "click",
        (event) => {
            const link = event.target.closest && event.target.closest("a[href]");
            if (!link || !/^https?:/i.test(link.getAttribute("href"))) return;
            event.preventDefault();
            T.opener.openUrl(link.href);
        },
        true
    );
}

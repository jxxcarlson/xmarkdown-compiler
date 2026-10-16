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
//   new     { folder, name }      -> created { path, name, folder, folderName }
//                                    (save dialog; the new file is empty)
//   confirmDiscard { name, then } -> (asks; finishes or cancels the close)
//   finish  { then }              -> (closes the window / quits)
//   openRecent { path }           -> opened (or error, and the path is dropped)
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
// A Markdown file opened from the Finder is opened here: at startup the page
// asks Rust for it (take_opened_file), and while running Rust sends it as
// "xm-open". Otherwise the most recent file is reopened at startup (if it
// still exists).
//
// The last 10 files opened or created (most recent first) are kept in
// localStorage and sent to Elm as recent { files: [{ path, title? }] } for the
// Recent menu: at startup and whenever the list changes. `title` is the
// document's %title line, read when the file is opened or saved.

function initDesktop(app) {
    const T = window.__TAURI__;
    if (!T) return;

    // Keep the last 20 uncaught errors (including Elm's) in localStorage as
    // xmarkdown.errorLog, to diagnose the page freezing.
    function logError(message, stack) {
        try {
            const log = JSON.parse(localStorage.getItem("xmarkdown.errorLog") || "[]");
            log.push({ time: new Date().toISOString(), message: String(message), stack: String(stack || "") });
            localStorage.setItem("xmarkdown.errorLog", JSON.stringify(log.slice(-20)));
        } catch (e) {}
    }
    window.addEventListener("error", (event) => logError(event.message, event.error && event.error.stack));
    window.addEventListener("unhandledrejection", (event) => logError(event.reason, event.reason && event.reason.stack));

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

    const RECENT_FILES = "xmarkdown.recentFiles";
    // Before the Recent menu only the last file was kept, under this key.
    const LAST_FILE = "xmarkdown.lastFile";
    const MAX_RECENT = 10;

    // [{ path, title? }]. Entries saved before titles were kept are bare paths.
    function recentFiles() {
        try {
            const files = JSON.parse(localStorage.getItem(RECENT_FILES));
            if (Array.isArray(files)) return files.map((f) => (typeof f === "string" ? { path: f } : f));
            const last = localStorage.getItem(LAST_FILE);
            return last ? [{ path: last }] : [];
        } catch (e) {
            return [];
        }
    }

    // "%title The Poem" -> "The Poem"; undefined when missing or empty.
    function titleOf(content) {
        const match = /^%title[ \t]+(.*\S)/m.exec(content || "");
        return match ? match[1].trim() : undefined;
    }

    function setRecentFiles(files) {
        try {
            localStorage.setItem(RECENT_FILES, JSON.stringify(files));
        } catch (e) {}
        app.ports.desktopResponse.send({ kind: "recent", files });
    }

    // Move `path` to the top of the list.
    function rememberFile(path, content) {
        const others = recentFiles().filter((f) => f.path !== path);
        setRecentFiles([{ path, title: titleOf(content) }, ...others].slice(0, MAX_RECENT));
    }

    // A save: keep the title up to date, without moving the file in the list.
    function retitleFile(path, content) {
        const files = recentFiles();
        const file = files.find((f) => f.path === path);
        const title = titleOf(content);
        if (!file || file.title === title) return;
        file.title = title;
        setRecentFiles(files);
    }

    function forgetFile(path) {
        setRecentFiles(recentFiles().filter((f) => f.path !== path));
    }

    // Only a document becoming the current one counts as recent: a "saved" can
    // be the auto-save of the document just left.
    function reply(message, content = message.content) {
        if (message.folder) currentFolder = message.folder;
        app.ports.desktopResponse.send(message);
        if (["opened", "created", "savedAs"].includes(message.kind)) rememberFile(message.path, content);
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
        reply({ kind: "savedAs", ...locate(path), token }, content);
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
            retitleFile(path, content);
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
        async openRecent({ path }) {
            if (!(await invoke("file_exists", { path }))) {
                forgetFile(path);
                return reply({ kind: "error", message: `${locate(path).name} is no longer in ${locate(path).folder}.` });
            }
            await openPath(path);
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
        // File > New: the save dialog picks the name and folder (it asks
        // before replacing an existing file).
        async new({ folder, name }) {
            const path = await T.dialog.save({
                defaultPath: folder ? folder + "/" + name : name,
                filters: MARKDOWN,
            });
            if (!path) return reply({ kind: "cancelled" });
            await invoke("write_file", { path, contents: "" });
            reply({ kind: "created", ...locate(path) });
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

    // A file opened from the Finder while the app is running.
    async function openFromFinder(path) {
        try {
            await openPath(path);
        } catch (e) {
            reply({ kind: "error", message: String(e) });
        }
    }

    // Open the file the app was launched with from the Finder; otherwise
    // reopen the most recently used file. If that is gone, keep the default doc.
    (async () => {
        setRecentFiles(recentFiles());
        await T.event.listen("xm-open", (event) => openFromFinder(event.payload));
        const opened = await invoke("take_opened_file");
        if (opened) return openFromFinder(opened);
        const path = recentFiles()[0]?.path;
        if (!path) return;
        try {
            if (await invoke("file_exists", { path })) await openPath(path);
        } catch (e) {
            console.warn("desktop.js: could not reopen", path, e);
        }
    })();

    // Keyboard shortcuts ⌘N, ⌘O, ⌘P and ⌘E are handled by Elm (Main.keyDecoder);
    // keep the webview from also acting on them (⌘P would print the page).
    document.addEventListener("keydown", (event) => {
        if (event.metaKey && !event.shiftKey && !event.altKey && !event.ctrlKey && ["n", "o", "p", "e"].includes(event.key.toLowerCase())) {
            event.preventDefault();
        }
    });

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

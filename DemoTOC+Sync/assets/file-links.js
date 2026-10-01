// Follow `file://` links in rendered documents.
//
// A web page can't see the directory a document came from, so the user picks
// a folder once ("Open Folder"); its files are indexed by path relative to the
// folder. Clicking [text](file://name.md) then loads that file into the app.
//
// Ports (see src/Ports.elm):
//   openFolder  (Elm -> JS)  show the folder picker
//   folderOpened (JS -> Elm) folder name, after the user picks one
//   linkedFile   (JS -> Elm) { name, content, folder } for a clicked link;
//                            content is null when the file can't be read,
//                            folder is null when no folder has been opened

function initFileLinks(app) {
    let folderName = null;
    let files = new Map(); // relative path -> File

    // Hidden directory picker, reused for every "Open Folder".
    const picker = document.createElement("input");
    picker.type = "file";
    picker.webkitdirectory = true;
    picker.multiple = true;
    picker.style.display = "none";
    document.body.appendChild(picker);

    picker.addEventListener("change", () => {
        if (picker.files.length === 0) return;
        files = new Map();
        for (const file of picker.files) {
            // webkitRelativePath is "<folder>/<sub>/<name>"; drop "<folder>/".
            const parts = file.webkitRelativePath.split("/");
            folderName = parts[0];
            files.set(parts.slice(1).join("/"), file);
        }
        picker.value = ""; // allow re-picking the same folder
        app.ports.folderOpened.send(folderName);
    });

    app.ports.openFolder.subscribe(() => picker.click());

    // "file://name.md", "file:///name.md", "file://./sub/name.md" -> "name.md", "sub/name.md"
    function linkPath(href) {
        let path = href.replace(/^file:\/*/i, "").replace(/^(\.\/)+/, "");
        try {
            path = decodeURIComponent(path);
        } catch (e) {
            // leave malformed escapes as written
        }
        return path;
    }

    // Capture phase, so the browser's own (blocked) file:// navigation never runs.
    document.addEventListener(
        "click",
        async (event) => {
            const link = event.target.closest && event.target.closest("a[href]");
            if (!link) return;
            const href = link.getAttribute("href");
            if (!/^file:/i.test(href)) return;
            event.preventDefault();

            const name = linkPath(href);
            const file = files.get(name);
            let content = null;
            if (file) {
                try {
                    content = await file.text();
                } catch (e) {
                    console.warn("file-links: could not read", name, e);
                }
            }
            app.ports.linkedFile.send({ name, content, folder: folderName });
        },
        true
    );
}

// Wait for Elm to be available (main.js loaded as regular script)
if (window.Elm) {
    initializeApp();
} else {
    document.addEventListener('DOMContentLoaded', () => {
        if (window.Elm) {
            initializeApp();
        }
    });
}

function initializeApp() {
    var root = document.getElementById('main');
    var app = window.Elm.Main.init({
        node: root,
        flags: {
            window: {
                windowWidth: window.innerWidth,
                windowHeight: window.innerHeight
            }
        }
    });
    init(app);

    // Listen for LR sync events from the editor
    document.addEventListener('lr-sync', (e) => {
        console.log("lr-sync event received:", e.detail);
        if (e.detail && e.detail.text) {
            console.log("Sending to Elm port:", e.detail.text);
            app.ports.lrSyncRequest.send(e.detail.text);
        }
    }, true);
    console.log("Port listener attached");

    // Listen for CSS injection from Elm (LR sync)
    app.ports.injectHighlightCSS.subscribe((css) => {
        console.log("Injecting CSS:", css);

        // Remove previous highlight style if it exists
        const oldStyle = document.getElementById('lr-sync-highlight-style');
        if (oldStyle) {
            oldStyle.remove();
        }

        // Create and inject new style
        const style = document.createElement('style');
        style.id = 'lr-sync-highlight-style';
        style.textContent = css;
        document.head.appendChild(style);
    });

    // Listen for editor highlight color changes from Elm (RL sync)
    app.ports.setEditorHighlightColor.subscribe((colorStr) => {
        console.log("Setting editor highlight color:", colorStr);
        document.documentElement.style.setProperty('--cm-sync-highlight-bg', colorStr);
    });
}

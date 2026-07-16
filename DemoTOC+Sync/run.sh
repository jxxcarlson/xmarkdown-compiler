#!/bin/bash

# editor.js is an ES module, and browsers refuse to load ES modules over the
# file:// protocol. So we serve assets/ over HTTP and open the http:// URL
# instead of opening index.html as a file.

# Static-server port. Kept outside 8000-8010 by request.
HTTP_PORT=8200

# Free the elm-watch web-socket port. elm-watch saves the port it was
# assigned in elm-stuff/elm-watch/stuff.json and insists on reusing it, so a
# stray elm-watch (or anything else) holding that port aborts startup with
# PORT CONFLICT. Read the saved port and kill whatever occupies it.
ELM_WATCH_STUFF="elm-stuff/elm-watch/stuff.json"
if [ -f "${ELM_WATCH_STUFF}" ]; then
    SAVED_PORT=$(sed -n 's/.*"port"[^0-9]*\([0-9][0-9]*\).*/\1/p' "${ELM_WATCH_STUFF}" | head -1)
    if [ -n "${SAVED_PORT}" ]; then
        lsof -ti:"${SAVED_PORT}" | xargs kill -9 2>/dev/null || true
    fi
fi

# Free our static-server port.
lsof -ti:${HTTP_PORT} | xargs kill -9 2>/dev/null || true

# Start elm-watch hot in the background (writes assets/main.js on change).
npx elm-watch hot &
ELM_WATCH_PID=$!

# Serve assets/ over HTTP in the background, with caching disabled.
# (Plain `python3 -m http.server` sends no Cache-Control header, so Firefox
# heuristically caches long-unmodified files like katex.js and serves stale
# copies on reload after they change.)
HTTP_PORT="${HTTP_PORT}" python3 - <<'PYEOF' &
import functools
import http.server
import os

class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

port = int(os.environ["HTTP_PORT"])
handler = functools.partial(NoCacheHandler, directory="assets")
http.server.ThreadingHTTPServer(("", port), handler).serve_forever()
PYEOF
HTTP_PID=$!

# Clean up both background processes when this script exits (Ctrl+C).
cleanup() {
    kill "${ELM_WATCH_PID}" "${HTTP_PID}" 2>/dev/null || true
}
trap cleanup EXIT

# Give elm-watch a moment to do the first compile and the server to bind.
sleep 3

# Open Firefox at the HTTP URL (NOT the file:// path).
open -a /Applications/Firefox.app "http://localhost:${HTTP_PORT}/index.html"

# Wait for elm-watch (runs until Ctrl+C).
wait "${ELM_WATCH_PID}"

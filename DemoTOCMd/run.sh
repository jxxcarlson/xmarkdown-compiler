#!/bin/bash

# editor.js is an ES module, and browsers refuse to load ES modules over the
# file:// protocol. So we serve assets/ over HTTP and open the http:// URL
# instead of opening index.html as a file.

# Static-server port. Kept outside 8000-8010 by request.
HTTP_PORT=8200

# Kill any process on the elm-watch port (56907) and our static-server port.
lsof -ti:56907 | xargs kill -9 2>/dev/null || true
lsof -ti:${HTTP_PORT} | xargs kill -9 2>/dev/null || true

# Start elm-watch hot in the background (writes assets/main.js on change).
npx elm-watch hot &
ELM_WATCH_PID=$!

# Serve assets/ over HTTP in the background.
python3 -m http.server "${HTTP_PORT}" --directory assets &
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

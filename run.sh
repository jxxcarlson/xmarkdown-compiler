#!/bin/bash
# Build the XMarkdown desktop app (XMarkdownNetlifyDemo/desktop) from its
# current sources, then open it. The build is incremental: it recompiles the
# Elm (assets/main.js) and only the Rust that changed.
#
# The desktop app is built from XMarkdownNetlifyDemo, not from this repo:
# changes made in DemoTOC+Sync reach it via
#   XMarkdownNetlifyDemo/scripts/sync-from-source.sh
# and compiler changes via a published xmarkdown-compiler release.

set -euo pipefail

DESKTOP=~/dev/elm-work/scripta/XMarkdownNetlifyDemo/desktop
APP="$DESKTOP/src-tauri/target/release/bundle/macos/XMarkdown.app"

(cd "$DESKTOP" && npm run build)

# Quit a running copy so the new build is what opens.
pgrep -xq xmarkdown && osascript -e 'quit app "XMarkdown"' && sleep 1 || true

open "$APP"

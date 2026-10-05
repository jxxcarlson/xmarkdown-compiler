#!/bin/bash
# Build the XMarkdown desktop app from its current sources (see run.sh) and
# install it as /Applications/XMarkdown.app, replacing any earlier copy.

set -euo pipefail

DESKTOP=~/dev/elm-work/scripta/XMarkdownNetlifyDemo/desktop
APP="$DESKTOP/src-tauri/target/release/bundle/macos/XMarkdown.app"
TARGET=/Applications/XMarkdown.app

(cd "$DESKTOP" && npm run build)

# Quit a running copy before replacing it.
pgrep -xq xmarkdown && osascript -e 'quit app "XMarkdown"' && sleep 1 || true

# Remove the old copy first: cp -R onto an existing bundle merges into it
# and can leave stale files behind.
rm -rf "$TARGET"
cp -R "$APP" "$TARGET"
echo "Installed $TARGET"

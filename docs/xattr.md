# Clearing the quarantine flag on Markdown files

## The problem

Double-clicking some `.md` files with XMarkdown set as the default app gives:

> Apple could not verify "stacked_high_over_summer_wheat.md" is free of malware
> that may harm your Mac or compromise your privacy.

The file has a `com.apple.quarantine` extended attribute (value
`0083;00000000;;`). A flag with no app name or timestamp is what sandboxed App
Store apps attach to every file they save, so these files were most likely
last saved by One Markdown. When a quarantined document is opened with an app
that is ad-hoc signed and not notarized, which is how XMarkdown is built,
Gatekeeper blocks it.

To check a file:

```bash
xattr -p com.apple.quarantine file.md
```

To clear one by hand:

```bash
xattr -d com.apple.quarantine file.md
```

The lasting fix is to sign XMarkdown with a Developer ID and notarize it
(paid Apple Developer account). Then macOS opens flagged documents in
XMarkdown without the warning. Until then, a launch agent removes the flag.

## The launch agent

`~/Library/LaunchAgents/com.jxxcarlson.unquarantine-md.plist` watches three
folders under `~/Dropbox/_Intellectual_Archive/Poetry`:

- `My_Poems`
- `Study_Poems`
- `Conversations`

Whenever a file in one of those folders is created or saved, including by
One Markdown, the agent runs `/usr/bin/xattr -dr com.apple.quarantine` on all
three folders, and the flag is gone within about a second. It also runs once
at login. Errors go to `/tmp/unquarantine-md.err`.

`~/Dropbox` is a symlink to `~/Library/CloudStorage/Dropbox`. The plist uses
the real path.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.jxxcarlson.unquarantine-md</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/xattr</string><string>-dr</string><string>com.apple.quarantine</string>
    <string>/Users/carlson/Library/CloudStorage/Dropbox/_Intellectual_Archive/Poetry/My_Poems</string>
    <string>/Users/carlson/Library/CloudStorage/Dropbox/_Intellectual_Archive/Poetry/Study_Poems</string>
    <string>/Users/carlson/Library/CloudStorage/Dropbox/_Intellectual_Archive/Poetry/Conversations</string>
  </array>
  <key>WatchPaths</key>
  <array>
    <string>/Users/carlson/Library/CloudStorage/Dropbox/_Intellectual_Archive/Poetry/My_Poems</string>
    <string>/Users/carlson/Library/CloudStorage/Dropbox/_Intellectual_Archive/Poetry/Study_Poems</string>
    <string>/Users/carlson/Library/CloudStorage/Dropbox/_Intellectual_Archive/Poetry/Conversations</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>StandardErrorPath</key><string>/tmp/unquarantine-md.err</string>
</dict>
</plist>
```

### Full Disk Access is required

macOS privacy protection does not let background jobs touch
`~/Library/CloudStorage` without permission. Without it, every run fails with
`Operation not permitted`. Grant it once:

1. Open System Settings → Privacy & Security → Full Disk Access.
2. Click **+**, then press ⌘⇧G and enter `/usr/bin/xattr`.
3. Make sure its switch is on.

## Maintenance

To watch more folders, add each path to **both** lists in the plist:
`ProgramArguments` (the folders it clears) and `WatchPaths` (the folders it
watches). `WatchPaths` only notices changes in the folders it lists, not in
their subfolders. Then reload:

```bash
launchctl unload ~/Library/LaunchAgents/com.jxxcarlson.unquarantine-md.plist
launchctl load ~/Library/LaunchAgents/com.jxxcarlson.unquarantine-md.plist
```

To check it is loaded (the middle column is the last exit status; 0 is good):

```bash
launchctl list | grep unquarantine
```

To turn it off:

```bash
launchctl unload ~/Library/LaunchAgents/com.jxxcarlson.unquarantine-md.plist
rm ~/Library/LaunchAgents/com.jxxcarlson.unquarantine-md.plist
```

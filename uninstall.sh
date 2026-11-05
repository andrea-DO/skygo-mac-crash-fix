#!/bin/bash
# Remove what install.sh added. Sky Go itself is not touched.
set -euo pipefail
DEST="$HOME/Library/Application Support/SkyGoFix"
WRAPPER="$HOME/Applications/Sky Go Fix.app"

if [ -e "$WRAPPER" ]; then
    exe=$(plutil -extract CFBundleExecutable raw "$WRAPPER/Contents/Info.plist" 2>/dev/null || true)
    if [ "$exe" = applet ]; then rm -rf "$WRAPPER"; echo "removed $WRAPPER"
    else echo "left $WRAPPER alone: not created by install.sh" >&2; fi
fi
[ -d "$DEST" ] && rm -rf "$DEST" && echo "removed $DEST"
rm -f "$HOME/Library/Logs/skygo-nopressure.log" "$HOME/Library/Logs/skygo-chromium.log"
echo "done; open Sky Go normally from now on"

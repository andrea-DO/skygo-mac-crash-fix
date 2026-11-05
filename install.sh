#!/bin/bash
# Build the shim, install it with the launcher in ~/Library/Application Support/SkyGoFix and create
# ~/Applications/Sky Go Fix.app, a double-clickable app that starts Sky Go with the fix.
# Nothing inside Sky Go.app is changed. Run ./uninstall.sh to remove everything this installs.
set -euo pipefail
cd "$(dirname "$0")"
DEST="$HOME/Library/Application Support/SkyGoFix"
WRAPPER="$HOME/Applications/Sky Go Fix.app"
BUNDLE_ID=com.github.skygo-mac-crash-fix.launcher

./build.sh
mkdir -p "$DEST" "$HOME/Applications"
cp build/libskygo_nopressure.dylib skygo-launch.sh "$DEST/"
chmod +x "$DEST/skygo-launch.sh"

# Only replace an existing "Sky Go Fix.app" if it is an AppleScript applet (ours or an older copy).
if [ -e "$WRAPPER" ]; then
    exe=$(plutil -extract CFBundleExecutable raw "$WRAPPER/Contents/Info.plist" 2>/dev/null || true)
    if [ "$exe" != applet ]; then
        echo "$WRAPPER exists and was not created by this installer; move it away and run again" >&2
        exit 1
    fi
    rm -rf "$WRAPPER"
fi

# If the launcher cannot start Sky Go (already open, or files removed), fall back to a plain open,
# which also brings a running Sky Go to the front.
TMP="$(mktemp -d -t skygofix)"
SCRIPT="$TMP/launcher.applescript"
cat > "$SCRIPT" <<EOF
on run
	try
		do shell script (quoted form of "$DEST/skygo-launch.sh") & " >/dev/null 2>&1 || open -b com.bskyb.skygoplayer"
	end try
end run
EOF
osacompile -o "$WRAPPER" "$SCRIPT"
rm -rf "$TMP"
plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$WRAPPER/Contents/Info.plist"

# Reuse the icon of the Sky Go copy installed on this Mac (nothing is copied into this repository).
for app in "${SKYGO_APP:-}" "$HOME/Applications/Sky Go.app" "/Applications/Sky Go.app"; do
    if [ -n "$app" ] && [ -f "$app/Contents/Resources/electron.icns" ]; then
        cp "$app/Contents/Resources/electron.icns" "$WRAPPER/Contents/Resources/applet.icns"
        break
    fi
done
codesign --force -s - "$WRAPPER" 2>/dev/null
touch "$WRAPPER"

echo
echo "Installed. Open \"Sky Go Fix\" from ~/Applications (or Spotlight) instead of the normal Sky Go icon."
echo "Check it is active: cat ~/Library/Logs/skygo-nopressure.log"

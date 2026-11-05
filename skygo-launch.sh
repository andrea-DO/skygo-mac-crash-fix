#!/bin/bash
# Start Sky Go with the crash fix. The Sky Go app itself is not modified.
#
# The shim (libskygo_nopressure.dylib) is injected with DYLD_INSERT_LIBRARIES, which Sky Go's code
# signature allows (allow-dyld-environment-variables + disable-library-validation). A Sky Go that is
# already running ignores the environment, so this refuses to start while one is open.
#
# Chromium switches passed to Sky Go (override with SKYGO_FLAGS, empty string for none):
#   --disable-layer-tree-host-memory-pressure  the compositor keeps its tiles when macOS signals memory
#                                              pressure instead of dropping them and re-rastering (grey page)
# SKYGO_FIX_CHROMIUM_LOG=1 also writes Chromium's log to ~/Library/Logs/skygo-chromium.log.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

find_app() {
    local a
    for a in "${SKYGO_APP:-}" "$HOME/Applications/Sky Go.app" "/Applications/Sky Go.app"; do
        if [ -n "$a" ] && [ -d "$a" ]; then echo "$a"; return; fi
    done
    mdfind "kMDItemCFBundleIdentifier == 'com.bskyb.skygoplayer'" 2>/dev/null | head -1
}

APP="$(find_app)"
DYLIB="$HERE/libskygo_nopressure.dylib"          # installed layout
[ -f "$DYLIB" ] || DYLIB="$HERE/build/libskygo_nopressure.dylib"   # running from the repo

[ -f "$DYLIB" ] || { echo "libskygo_nopressure.dylib not found: run ./install.sh (or ./build.sh)" >&2; exit 1; }
[ -n "$APP" ] && [ -d "$APP" ] || { echo "Sky Go not found; set SKYGO_APP=/path/to/Sky Go.app" >&2; exit 1; }
if pgrep -x "Sky Go" >/dev/null; then
    echo "Sky Go is already running; quit it first" >&2
    exit 1
fi

FLAGS="${SKYGO_FLAGS---disable-layer-tree-host-memory-pressure}"
if [ "${SKYGO_FIX_CHROMIUM_LOG:-0}" = 1 ]; then
    FLAGS="$FLAGS --enable-logging --log-file=$HOME/Library/Logs/skygo-chromium.log"
fi
ARGS=()
# shellcheck disable=SC2206  # word splitting of the flag list is intended
[ -n "$FLAGS" ] && ARGS=(--args $FLAGS)
exec open --env "DYLD_INSERT_LIBRARIES=$DYLIB" "$APP" ${ARGS[@]+"${ARGS[@]}"}

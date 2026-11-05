#!/bin/bash
# Build the x86_64 shim (Sky Go runs translated by Rosetta) and the test probe into build/.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
XCODE_SDK=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk

compile() {  # $1: SDK path, or empty for the default one
    local sys=()
    [ -n "$1" ] && sys=(-isysroot "$1")
    clang ${sys[@]+"${sys[@]}"} -arch x86_64 -dynamiclib -O2 -Wall -Wextra -mmacosx-version-min=10.13 \
        -o build/libskygo_nopressure.dylib src/nopressure.c &&
        clang ${sys[@]+"${sys[@]}"} -arch x86_64 -O1 -Wall -o build/probe test/probe.c
}

# Some Command Line Tools releases ship an SDK whose .tbd files the linker rejects
# ("tapi error ... unknown architecture"); fall back to Xcode's SDK when that happens.
if [ -n "${SDKROOT:-}" ]; then
    compile "$SDKROOT"
elif ! compile "" 2>/dev/null; then
    if [ ! -d "$XCODE_SDK" ]; then
        echo "build failed with the default SDK; errors:" >&2
        compile ""
    fi
    echo "default SDK failed, retrying with Xcode's SDK" >&2
    compile "$XCODE_SDK"
fi

codesign --force -s - build/libskygo_nopressure.dylib build/probe
lipo -info build/libskygo_nopressure.dylib

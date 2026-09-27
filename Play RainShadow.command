#!/bin/zsh
set -eu
cd "$(dirname "$0")"
build_dir=/tmp/RainShadowGameApp
build_log=/tmp/rainshadow_game_build.log
echo "Building RainShadow with the restored office and living quarters…"
if ! xcodebuild -project RainShadow.xcodeproj -scheme 'RainShadow macOS' \
    -configuration Debug -derivedDataPath "$build_dir" \
    SWIFT_OPTIMIZATION_LEVEL=-O CODE_SIGNING_ALLOWED=NO build > "$build_log" 2>&1; then
    tail -60 "$build_log"
    exit 1
fi
exec "$build_dir/Build/Products/Debug/RainShadow.app/Contents/MacOS/RainShadow"

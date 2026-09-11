#!/bin/zsh
set -eu
cd "$(dirname "$0")"
build_dir=/tmp/RainShadowSableV24App
build_log=/tmp/sable_v24_build.log
echo "Building Sable Row playtest…"
if ! xcodebuild -project RainShadow.xcodeproj -scheme 'RainShadow macOS' \
    -configuration Debug -derivedDataPath "$build_dir" \
    SWIFT_OPTIMIZATION_LEVEL=-O CODE_SIGNING_ALLOWED=NO build > "$build_log" 2>&1; then
    tail -60 "$build_log"
    exit 1
fi
echo "Click to walk. Arrows/WASD pan. Minus/equals zoom. M opens the map. N switches day/night."
echo "Click Voss's door to open it, then the opening to enter. Click the open leaf to close it."
echo "This playtest uses a separate save slot. Other building interiors are not connected yet."
exec env RAINSHADOW_START_SCENE=sable_blender \
    "$build_dir/Build/Products/Debug/RainShadow.app/Contents/MacOS/RainShadow"

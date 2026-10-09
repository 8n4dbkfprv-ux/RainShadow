#!/bin/zsh
set -eu
cd "$(dirname "$0")"
source Scripts/select_xcode.sh
build_dir=/tmp/RainShadowCombatApp
build_log=/tmp/lila_mac_build.log
echo "Building Lila's interiors…"
if ! xcodebuild -project RainShadow.xcodeproj -scheme 'RainShadow macOS' \
    -configuration Debug -derivedDataPath "$build_dir" \
    SWIFT_OPTIMIZATION_LEVEL=-O CODE_SIGNING_ALLOWED=NO build > "$build_log" 2>&1; then
    tail -60 "$build_log"
    exit 1
fi
echo "Click the stair to visit Lila's rooms. The front threshold and back door return to Lila Street."
echo "This uses the separate city playtest save."
exec env RAINSHADOW_START_SCENE=interior RAINSHADOW_START_INTERIOR=lila_hall \
    RAINSHADOW_START_ENTRANCE=from.street RAINSHADOW_CITY_PLAYTEST=1 \
    "$build_dir/Build/Products/Debug/RainShadow.app/Contents/MacOS/RainShadow"

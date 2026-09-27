#!/bin/zsh
set -eu
cd "$(dirname "$0")"
lamp_build_dir=/tmp/RainShadowLampWardApp
lamp_build_log=/tmp/lamp_ward_build.log
echo "Building Lamp Ward and the Lamphouse…"
if ! xcodebuild -project RainShadow.xcodeproj -scheme 'RainShadow macOS' \
    -configuration Debug -derivedDataPath "$lamp_build_dir" \
    SWIFT_OPTIMIZATION_LEVEL=-O CODE_SIGNING_ALLOWED=NO build > "$lamp_build_log" 2>&1; then
    tail -60 "$lamp_build_log"
    exit 1
fi
echo "Click to walk. Click the Lamphouse doorway to enter and the narrow floor strip to leave."
echo "M opens the area map; N switches the ward between day and night."
echo "This launcher uses a separate save. Both areas are also part of normal city travel."
exec env RAINSHADOW_START_SCENE=city RAINSHADOW_START_DISTRICT=lamp_ward \
    RAINSHADOW_START_ENTRANCE=from.portal.lamphouseEntrance RAINSHADOW_LAMP_WARD_PLAYTEST=1 \
    "$lamp_build_dir/Build/Products/Debug/RainShadow.app/Contents/MacOS/RainShadow"

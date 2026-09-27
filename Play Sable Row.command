#!/bin/zsh
set -eu
cd "$(dirname "$0")"
build_dir=/tmp/RainShadowCityRestoreApp
build_log=/tmp/restored_city_build.log
echo "Building restored city…"
if ! xcodebuild -project RainShadow.xcodeproj -scheme 'RainShadow macOS' \
    -configuration Debug -derivedDataPath "$build_dir" \
    SWIFT_OPTIMIZATION_LEVEL=-O CODE_SIGNING_ALLOWED=NO build > "$build_log" 2>&1; then
    tail -60 "$build_log"
    exit 1
fi
echo "Click to walk. Arrows/WASD pan. Minus/equals zoom. M opens the map. N switches day/night."
echo "Click Voss's doorway to enter. Wharf and Riverside doors open on the first click; click the opening to enter."
echo "Sable Row, Wharf Ladder, Riverside and Lamp Ward are connected through the world map."
echo "This launcher uses a separate save; normal game travel uses the same restored areas."
exec env RAINSHADOW_START_SCENE=city RAINSHADOW_START_DISTRICT=sable_row \
    RAINSHADOW_START_ENTRANCE=from.office RAINSHADOW_CITY_PLAYTEST=1 \
    "$build_dir/Build/Products/Debug/RainShadow.app/Contents/MacOS/RainShadow"

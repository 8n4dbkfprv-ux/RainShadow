#!/bin/zsh
set -eu
cd "$(dirname "$0")"
source Scripts/select_xcode.sh
combat_build_dir=/tmp/RainShadowCombatApp
combat_build_log=/tmp/rainshadow-combat-play-build.log
echo "Building playable Wharf Ladder combat…"
if ! xcodebuild -project RainShadow.xcodeproj -scheme 'RainShadow macOS' \
    -configuration Debug -derivedDataPath "$combat_build_dir" \
    CODE_SIGNING_ALLOWED=NO build > "$combat_build_log" 2>&1; then
    tail -60 "$combat_build_log"
    exit 1
fi
echo "Click the shipping-office door, then its opening, and choose a dialogue reply."
echo "In combat: click ground to move; click a rival to strike; 1 defends; Enter ends turn; 3 yields."
echo "4 activates Bear Form or reverts. Transformation needs a standard action and open ground."
echo "5 selects Fire arrow: click a rival or oil barrel. Orange circles preview the blast; everyone inside can be hit."
echo "Ready the Lantern shortsword in inventory before combat to use the player sword animation."
echo "The gate lookout shoots from range and switches to a shortsword when engaged."
echo "Space pauses. All strikes are nonlethal. This launcher uses a separate persistent save."
exec env RAINSHADOW_START_SCENE=city RAINSHADOW_START_DISTRICT=wharf_ladder \
    RAINSHADOW_START_ENTRANCE=from.portal.shippingOffice RAINSHADOW_COMBAT_PLAYTEST=1 \
    "$combat_build_dir/Build/Products/Debug/RainShadow.app/Contents/MacOS/RainShadow"

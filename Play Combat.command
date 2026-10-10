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
echo "In combat: click ground to move; use the sword icon then click a rival for Melee Attack."
echo "1 casts Blade Ward; Space / Enter ends your turn; 3 flees when all enemies are at least 60 ft away."
echo "4 activates Bear Form or reverts. Transformation needs a standard action and open ground."
echo "5 selects Ranged Attack: click a rival or oil barrel. Equip a bow in inventory first."
echo "Use the ammunition icon to switch Normal / Fire arrows. Fire arrows consume inventory."
echo "Orange circles preview barrel explosions; everyone inside can be hit."
echo "Hover over the parchment action icons for names and descriptions; select an attack, then its target."
echo "I opens inventory, including during combat; the encounter pauses until you close it."
echo "Ready the Lantern shortsword in inventory to use the player sword animation."
echo "The gate lookout shoots from range and switches to a shortsword when engaged."
echo "Shift+Space pauses. C hides, V shoves, R selects Sneak Attack, G dashes, F switches weapon targeting. T examines the hovered rival. All strikes are nonlethal. This launcher uses a separate persistent save."
exec env RAINSHADOW_START_SCENE=city RAINSHADOW_START_DISTRICT=wharf_ladder \
    RAINSHADOW_START_ENTRANCE=from.portal.shippingOffice RAINSHADOW_COMBAT_PLAYTEST=1 \
    "$combat_build_dir/Build/Products/Debug/RainShadow.app/Contents/MacOS/RainShadow"

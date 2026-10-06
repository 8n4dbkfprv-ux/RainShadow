#!/bin/zsh
set -eu
cd "$(dirname "$0")"
echo "Bear Form: move onto open ground, then press 4 or click Bear Form."
echo "One use per encounter; 8 temporary endurance; three full turns after activation."
echo "This launcher keeps a separate Bear Form playtest save."
export RAINSHADOW_BEAR_PLAYTEST=1
exec ./Play\ Combat.command

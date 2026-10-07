#!/bin/zsh
set -eu
cd "$(dirname "$0")"
export RAINSHADOW_BARREL_PLAYTEST=1
echo "Using a separate explosive-barrel demo save. Your main game and earlier combat saves are preserved."
exec /bin/zsh "Play Combat.command"

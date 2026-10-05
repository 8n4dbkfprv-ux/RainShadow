#!/bin/zsh
# Sourced by the play launchers. Prefer the user's selection; fall back to an
# installed Xcode when xcode-select points only to Command Line Tools.
if [[ -z "${DEVELOPER_DIR:-}" ]]; then
    rainshadow_developer_dir="$(xcode-select -p 2>/dev/null || true)"
    if [[ ! -d "$rainshadow_developer_dir/Platforms/MacOSX.platform" ]]; then
        for rainshadow_xcode in /Applications/Xcode.app /Applications/Xcode-beta.app; do
            if [[ -d "$rainshadow_xcode/Contents/Developer/Platforms/MacOSX.platform" ]]; then
                export DEVELOPER_DIR="$rainshadow_xcode/Contents/Developer"
                break
            fi
        done
    fi
fi

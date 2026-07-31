#!/bin/bash
# Renders a review frame from the shipping macOS build.
#
#   capture_office_review.sh <mode> <output.png> [delay-seconds]
#
# The app is sandboxed and cannot write into the repo, so it base64s the PNG to
# stdout between markers and we decode it here.
set -euo pipefail

MODE="$1"
OUT="$2"
DELAY="${3:-2.5}"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BIN="$(xcodebuild -project "$ROOT/RainShadow.xcodeproj" -scheme "RainShadow macOS" \
        -configuration Debug -showBuildSettings 2>/dev/null \
        | sed -n 's/ *BUILT_PRODUCTS_DIR = //p' | head -1)/RainShadow.app/Contents/MacOS/RainShadow"

LOG="$(mktemp)"
ERRLOG="$(mktemp)"
trap 'rm -f "$LOG" "$ERRLOG"' EXIT

mkdir -p "$(dirname "$OUT")"
# Always clear the target so a prior capture cannot be mistaken for a fresh one
# when the sandboxed app fails to write the path and we fall back to stdout.
rm -f "$OUT" "${OUT%.png}_half.png"

env RAINSHADOW_SKIP_INTRO=1 \
    RAINSHADOW_START_SCENE=office \
    RAINSHADOW_CAPTURE="$OUT" \
    RAINSHADOW_CAPTURE_MODE="$MODE" \
    RAINSHADOW_CAPTURE_DELAY="$DELAY" \
    ${RAINSHADOW_FORCE_CLIENT_ENTRANCE:+RAINSHADOW_FORCE_CLIENT_ENTRANCE="$RAINSHADOW_FORCE_CLIENT_ENTRANCE"} \
    ${RAINSHADOW_CAPTURE_DUMP:+RAINSHADOW_CAPTURE_DUMP="$RAINSHADOW_CAPTURE_DUMP"} \
    ${RAINSHADOW_SCALE_RIG:+RAINSHADOW_SCALE_RIG="$RAINSHADOW_SCALE_RIG"} \
    ${RAINSHADOW_CAPTURE_FALLEN_DOOR:+RAINSHADOW_CAPTURE_FALLEN_DOOR="$RAINSHADOW_CAPTURE_FALLEN_DOOR"} \
    ${RAINSHADOW_PARTITION_MASK:+RAINSHADOW_PARTITION_MASK="$RAINSHADOW_PARTITION_MASK"} \
    "$BIN" >"$LOG" 2>"$ERRLOG" || true

if [ -n "${RAINSHADOW_CAPTURE_DUMP:-}" ]; then
    sed -n '/^capture:/p;/RAINSHADOW_DUMP_BEGIN/,/RAINSHADOW_DUMP_END/p' "$ERRLOG" >&2
fi

if [ ! -f "$OUT" ]; then
    sed -n '/RAINSHADOW_CAPTURE_BEGIN/,/RAINSHADOW_CAPTURE_END/p' "$LOG" \
        | sed '1d;$d' | tr -d '\n' | base64 -d > "$OUT"
fi

python3 - "$OUT" <<'PY'
import sys
from PIL import Image
path = sys.argv[1]
im = Image.open(path)
print(f"{path} {im.size[0]}x{im.size[1]}")
im.resize((im.width // 2, im.height // 2), Image.LANCZOS).save(path.replace(".png", "_half.png"))
PY

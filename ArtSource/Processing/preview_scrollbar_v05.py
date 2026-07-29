#!/usr/bin/env python3
"""Render the shipped scrollbar parts at true on-screen size.

SpriteKit's `centerRect` draws cap regions at texture resolution (1 texel : 1 point),
so a texture much larger than the drawn control makes the top/bottom bevels far
thicker than the stretched side bevels. This preview reproduces both the nine-sliced
and plain-stretched assemblies so the runtime `centerRect` values can be chosen by
looking at the result rather than guessing from the texture.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "RainShadow Shared/Resources/Art/UI/Dialogue"

COLUMN_WIDTH = 30
COLUMN_HEIGHT = 300
ZOOM = 4


def nine_slice(im: Image.Image, size: tuple[int, int], center: tuple[float, float, float, float]) -> Image.Image:
    """Approximate SKSpriteNode.centerRect with caps at 1 texel : 1 point."""
    tw, th = im.size
    cx, cy, cw, ch = center
    left = int(round(cx * tw))
    right = int(round((1 - cx - cw) * tw))
    # SpriteKit's centerRect y origin is bottom-left; PIL rows are top-down.
    bottom = int(round(cy * th))
    top = int(round((1 - cy - ch) * th))

    dw, dh = size
    left = min(left, dw // 2)
    right = min(right, dw // 2)
    top = min(top, dh // 2)
    bottom = min(bottom, dh // 2)

    out = Image.new("RGBA", size, (0, 0, 0, 0))
    mid_w = max(1, dw - left - right)
    mid_h = max(1, dh - top - bottom)
    src_mid_w = max(1, tw - left - right)
    src_mid_h = max(1, th - top - bottom)

    cols = [(0, left, 0, left), (left, src_mid_w, left, mid_w), (tw - right, right, dw - right, right)]
    rows = [(0, top, 0, top), (top, src_mid_h, top, mid_h), (th - bottom, bottom, dh - bottom, bottom)]
    for sy, sh, dy, dh_ in rows:
        for sx, sw, dx, dw_ in cols:
            if sw <= 0 or sh <= 0 or dw_ <= 0 or dh_ <= 0:
                continue
            patch = im.crop((sx, sy, sx + sw, sy + sh)).resize((dw_, dh_), Image.Resampling.LANCZOS)
            out.paste(patch, (dx, dy), patch)
    return out


def assemble(nine: bool) -> Image.Image:
    up = Image.open(RUNTIME / "dialogue_scroll_up_v05.png").convert("RGBA")
    down = Image.open(RUNTIME / "dialogue_scroll_down_v05.png").convert("RGBA")
    track = Image.open(RUNTIME / "dialogue_scroll_track_v05.png").convert("RGBA")
    thumb = Image.open(RUNTIME / "dialogue_scroll_thumb_v07.png").convert("RGBA")
    grip = Image.open(RUNTIME / "dialogue_scroll_thumb_grip_v09.png").convert("RGBA")

    button = COLUMN_WIDTH
    track_h = COLUMN_HEIGHT - button * 2
    thumb_h = int(track_h * 0.34)

    canvas = Image.new("RGBA", (COLUMN_WIDTH, COLUMN_HEIGHT), (26, 26, 28, 255))
    canvas.paste(up.resize((button, button), Image.Resampling.LANCZOS), (0, 0))
    canvas.paste(down.resize((button, button), Image.Resampling.LANCZOS), (0, COLUMN_HEIGHT - button))

    if nine:
        track_img = nine_slice(track, (COLUMN_WIDTH, track_h), (0.0, 0.05, 1.0, 0.90))
        thumb_img = nine_slice(thumb, (COLUMN_WIDTH, thumb_h), (0.0, 0.10, 1.0, 0.80))
    else:
        track_img = track.resize((COLUMN_WIDTH, track_h), Image.Resampling.LANCZOS)
        thumb_img = thumb.resize((COLUMN_WIDTH, thumb_h), Image.Resampling.LANCZOS)

    canvas.paste(track_img, (0, button), track_img)
    thumb_y = button + int(track_h * 0.12)
    canvas.paste(thumb_img, (0, thumb_y), thumb_img)
    gx = (COLUMN_WIDTH - grip.width) // 2
    gy = thumb_y + (thumb_h - grip.height) // 2
    canvas.paste(grip, (gx, gy), grip)
    return canvas


def main() -> None:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/tmp/scroll_v05_preview.png")
    variants = [assemble(nine=True), assemble(nine=False)]
    gap = 24
    sheet = Image.new(
        "RGBA",
        (len(variants) * (COLUMN_WIDTH + gap) + gap, COLUMN_HEIGHT + gap * 2),
        (26, 26, 28, 255),
    )
    for index, variant in enumerate(variants):
        sheet.paste(variant, (gap + index * (COLUMN_WIDTH + gap), gap))
    sheet = sheet.resize((sheet.width * ZOOM, sheet.height * ZOOM), Image.Resampling.NEAREST)
    sheet.save(out)
    print(f"wrote {out} ({sheet.size}) — left: nine-sliced, right: plain stretch")


if __name__ == "__main__":
    main()

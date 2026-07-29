#!/usr/bin/env python3
"""Composite System 7 V06 scrollbar parts at true on-screen size for QA."""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "RainShadow Shared/Resources/Art/UI/Dialogue"

COLUMN_WIDTH = 30
COLUMN_HEIGHT = 300
ZOOM = 4


def assemble(scrollable: bool) -> Image.Image:
    up = Image.open(RUNTIME / "dialogue_scroll_up_v06.png").convert("RGBA")
    down = Image.open(RUNTIME / "dialogue_scroll_down_v06.png").convert("RGBA")
    area_name = "dialogue_scroll_area_v06.png" if scrollable else "dialogue_scroll_area_solid_v06.png"
    area = Image.open(RUNTIME / area_name).convert("RGBA")
    box = Image.open(RUNTIME / "dialogue_scroll_box_v06.png").convert("RGBA")

    button = COLUMN_WIDTH
    track_h = COLUMN_HEIGHT - button * 2

    canvas = Image.new("RGBA", (COLUMN_WIDTH, COLUMN_HEIGHT), (26, 26, 28, 255))
    canvas.paste(up.resize((button, button), Image.Resampling.NEAREST), (0, 0))
    canvas.paste(down.resize((button, button), Image.Resampling.NEAREST), (0, COLUMN_HEIGHT - button))

    # Crop the pixel-exact dither rather than stretch it.
    frac = min(1.0, track_h / area.height)
    crop = area.crop((0, 0, area.width, max(1, int(round(area.height * frac)))))
    track_img = crop.resize((COLUMN_WIDTH, track_h), Image.Resampling.NEAREST)
    canvas.paste(track_img, (0, button), track_img)

    if scrollable:
        box_img = box.resize((button, button), Image.Resampling.NEAREST)
        thumb_y = button + int(track_h * 0.28)
        canvas.paste(box_img, (0, thumb_y), box_img)
    return canvas


def main() -> None:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/tmp/scroll_v06_preview.png")
    variants = [assemble(scrollable=True), assemble(scrollable=False)]
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
    print(f"wrote {out} ({sheet.size}) — left: scrollable, right: disabled solid")


if __name__ == "__main__":
    main()

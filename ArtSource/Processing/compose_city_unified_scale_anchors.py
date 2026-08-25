#!/usr/bin/env python3
"""Composite a correctly-scaled adult onto each unified-area layout reference.

Uses the current unified preview when present so the yellow door box sits on
the painting that will be regenerated. Green silhouette = 70.3 wu adult;
yellow box = 1.15× adult door at the painted portal.

    python3 ArtSource/Processing/compose_city_unified_scale_anchors.py
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import qa_area_door_scale as qa

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT / "ArtSource/Generated/CityDistrict/V2/WardRebuild"
PREVIEW = ROOT / "ArtSource/Generated/CityDistrict/V2/UnifiedPlates"
OUT = ROOT / "ArtSource/Generated/CityDistrict/V2/UnifiedScaleAnchors"
SPRITE = (
    ROOT
    / "RainShadow Shared/Resources/Art/Atlases/VossIdle.atlas/voss_standing_idle_s_00.png"
)

ADULT_WU = 70.3125
WORLD = (4096.0, 3072.0)
OPAQUE_BODY_PX = 200.0
DISTRICTS = (
    "sable_row",
    "wharf_ladder",
    "riverside",
    "harborpoint_pd",
    "lila_street",
    "civic_records",
)


def door_anchor(area: dict, door: dict) -> tuple[float, float]:
    return qa.door_anchor(area, door)


def silhouette(target_height: float) -> Image.Image:
    source = Image.open(SPRITE).convert("RGBA")
    alpha = np.asarray(source.split()[-1])
    rows = np.where(alpha.max(axis=1) > 24)[0]
    cols = np.where(alpha.max(axis=0) > 24)[0]
    cropped = source.crop((int(cols[0]), int(rows[0]), int(cols[-1]) + 1, int(rows[-1]) + 1))
    scale = target_height / cropped.height
    size = (max(1, int(round(cropped.width * scale))), max(1, int(round(cropped.height * scale))))
    figure = cropped.resize(size, Image.Resampling.LANCZOS)
    pixels = np.asarray(figure).copy()
    visible = pixels[:, :, 3] > 24
    pixels[visible, 0] = 40
    pixels[visible, 1] = 255
    pixels[visible, 2] = 90
    pixels[visible, 3] = 220
    return Image.fromarray(pixels, "RGBA")


def layout_source(slug: str) -> Path:
    """Prefer the current unified painting so the jig sits on the art we keep."""
    preview = PREVIEW / slug / f"city_{slug}_area_v02_preview.png"
    if preview.exists():
        return preview
    return REVIEW / f"{slug}_review_full.png"


def compose(slug: str, figure: Image.Image) -> Path:
    area = qa.load_area(slug)
    review = Image.open(layout_source(slug)).convert("RGBA")
    px_per_unit = review.width / WORLD[0]
    adult_px = ADULT_WU * px_per_unit
    stamp = figure.resize(
        (max(1, int(round(figure.width * adult_px / figure.height))), int(round(adult_px))),
        Image.Resampling.LANCZOS,
    )
    draw = ImageDraw.Draw(review)
    for door in area.get("doors", []):
        wx, wy = door_anchor(area, door)
        px = wx * review.width / WORLD[0]
        py = review.height - wy * review.height / WORLD[1]
        x = int(round(px - stamp.width / 2))
        y = int(round(py - stamp.height))
        review.alpha_composite(stamp, (x, y))
        door_h = adult_px * 1.15
        half_w = max(6, adult_px * 0.22)
        draw.rectangle(
            (px - half_w, py - door_h, px + half_w, py),
            outline=(255, 220, 0, 255),
            width=3,
        )
    out = OUT / f"{slug}_scale_anchor.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    review.convert("RGB").save(out, compress_level=3)
    return out


def main() -> int:
    figure = silhouette(OPAQUE_BODY_PX)
    for slug in DISTRICTS:
        path = compose(slug, figure)
        print(path.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

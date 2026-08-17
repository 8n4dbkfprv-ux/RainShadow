#!/usr/bin/env python3
"""Survey the V5 Sable Row diamond lots in world space.

Uses the same (u, v) field and period as
`generate_city_grounds_world_scale_v05.iso_street_masks`. Do not invent a
second lattice.

    python3 ArtSource/Processing/survey_sable_iso_lots.py

Writes:
  ArtSource/Generated/CityDistrict/V2/sable_iso_lots.json
  ArtSource/Generated/CityDistrict/V2/sable_iso_lots_overlay.png
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_city_grounds_world_scale_v05 import (
    AREAS,
    GEN,
    PLATE_H,
    PLATE_W,
    PX_PER_UNIT,
    SLOPE,
    WORLD_H,
    WORLD_W,
    axis_uv,
)

PERIOD = 1680.0  # px, matches iso_street_masks
HALF_ROAD = 168.0
WALK = 88.0
# Pad interior starts this far from a u/v road line.
PAD_INSET = HALF_ROAD + WALK  # 256
PAD_HALF = PERIOD / 2.0 - PAD_INSET  # 584

OUT = GEN / "sable_iso_lots.json"
OVERLAY = GEN / "sable_iso_lots_overlay.png"


def uv_to_image(u: float, v: float) -> tuple[float, float]:
    """Image pixels, origin top-left, y down."""
    return u - v, SLOPE * (u + v)


def image_to_world(ix: float, iy: float) -> tuple[float, float]:
    return ix / PX_PER_UNIT, WORLD_H - iy / PX_PER_UNIT


def world_to_image(wx: float, wy: float) -> tuple[float, float]:
    return wx * PX_PER_UNIT, (WORLD_H - wy) * PX_PER_UNIT


def lot_uv_center(i: int, j: int) -> tuple[float, float]:
    return PERIOD * (i + 0.5), PERIOD * (j + 0.5)


def lot_record(i: int, j: int) -> dict | None:
    uc, vc = lot_uv_center(i, j)
    # Four pad vertices in (u, v): ±PAD_HALF on each axis.
    verts_uv = [
        (uc + PAD_HALF, vc + PAD_HALF),  # +u +v = camera-near (max image y)
        (uc + PAD_HALF, vc - PAD_HALF),
        (uc - PAD_HALF, vc + PAD_HALF),
        (uc - PAD_HALF, vc - PAD_HALF),  # −u −v = camera-far
    ]
    verts_w = []
    for u, v in verts_uv:
        ix, iy = uv_to_image(u, v)
        wx, wy = image_to_world(ix, iy)
        verts_w.append((wx, wy))
    xs = [p[0] for p in verts_w]
    ys = [p[1] for p in verts_w]
    # Skip lots whose centroid is well outside the play plate.
    cx, cy = sum(xs) / 4.0, sum(ys) / 4.0
    if cx < -200 or cx > WORLD_W + 200 or cy < -200 or cy > WORLD_H + 200:
        return None
    near = min(verts_w, key=lambda p: p[1])  # lowest world y = camera-near
    far = max(verts_w, key=lambda p: p[1])
    # Inscribed AABB: shrink the vertex AABB so cell centres stay off the kerb.
    # 16 wu ≈ one search cell; keep a disc of radius 16 inside the lot.
    pad = 24.0
    aabb = [
        min(xs) + pad,
        min(ys) + pad,
        max(xs) - min(xs) - 2 * pad,
        max(ys) - min(ys) - 2 * pad,
    ]
    if aabb[2] < 80 or aabb[3] < 60:
        return None
    # Kerb directions in world: u=const → slope −0.75; v=const → slope +0.75
    # after the y-up flip the image slopes stay ±0.75 on screen.
    return {
        "id": f"lot_{i}_{j}",
        "i": i,
        "j": j,
        "centroid": [round(cx, 2), round(cy, 2)],
        "nearTip": [round(near[0], 2), round(near[1], 2)],
        "farTip": [round(far[0], 2), round(far[1], 2)],
        "vertices": [[round(x, 2), round(y, 2)] for x, y in verts_w],
        "inscribedAABB": [round(v, 2) for v in aabb],
        "kerbSlopes": [-0.75, 0.75],
    }


def main() -> int:
    GEN.mkdir(parents=True, exist_ok=True)
    # Cover the plate in (u, v). Image (0,0)..(8192,4608) maps to a band of u,v.
    # Sample a generous index range.
    lots = []
    for i in range(-4, 12):
        for j in range(-4, 12):
            rec = lot_record(i, j)
            if rec is None:
                continue
            lots.append(rec)
    lots.sort(key=lambda r: (r["nearTip"][1], r["nearTip"][0]))
    OUT.write_text(json.dumps({"periodPx": PERIOD, "lots": lots}, indent=2))
    print(f"wrote {OUT}  ({len(lots)} lots)")

    # Overlay on the shipped ground, downscaled.
    ground = AREAS / "city_sable_row_ground_v02.png"
    if ground.exists():
        im = Image.open(ground).convert("RGB")
        im = im.resize((2048, 1152), Image.Resampling.BILINEAR)
        sx, sy = 2048 / WORLD_W, 1152 / WORLD_H
        d = ImageDraw.Draw(im, "RGBA")
        for n, rec in enumerate(lots):
            verts = []
            for wx, wy in rec["vertices"]:
                # image y-down
                verts.append((wx * sx, (WORLD_H - wy) * sy))
            d.polygon(verts, outline=(80, 220, 255, 220), width=2)
            cx, cy = rec["centroid"]
            nx, ny = rec["nearTip"]
            d.ellipse([nx * sx - 3, (WORLD_H - ny) * sy - 3, nx * sx + 3, (WORLD_H - ny) * sy + 3], fill=(255, 80, 80, 255))
            d.text((cx * sx - 10, (WORLD_H - cy) * sy - 6), rec["id"].replace("lot_", ""), fill=(255, 230, 160, 255))
        # Seated Voss stoop (2713, 712) and Harbor Street approach (2713, 572).
        d.ellipse([2713 * sx - 5, (WORLD_H - 712) * sy - 5, 2713 * sx + 5, (WORLD_H - 712) * sy + 5], outline=(255, 220, 40, 255), width=2)
        d.ellipse([2713 * sx - 4, (WORLD_H - 572) * sy - 4, 2713 * sx + 4, (WORLD_H - 572) * sy + 4], outline=(80, 255, 120, 255), width=2)
        im.save(OVERLAY, "PNG", compress_level=4)
        print(f"wrote {OVERLAY}")

    # Rank lots by distance of near tip to the current office door.
    door = (2713.0, 712.0)
    ranked = sorted(
        lots,
        key=lambda r: (r["nearTip"][0] - door[0]) ** 2 + (r["nearTip"][1] - door[1]) ** 2,
    )
    print("lots nearest seated Voss stoop (2713, 712):")
    for rec in ranked[:8]:
        dx = rec["nearTip"][0] - door[0]
        dy = rec["nearTip"][1] - door[1]
        print(
            f"  {rec['id']:10} near={rec['nearTip']}  "
            f"centroid={rec['centroid']}  d=({dx:.0f},{dy:.0f})  "
            f"aabb={rec['inscribedAABB']}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

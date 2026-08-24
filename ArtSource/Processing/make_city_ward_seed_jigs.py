#!/usr/bin/env python3
"""On-lock geometric seed jigs for 1950s city-ward Image Generator masters.

Each jig is a 1024×1024 crop of one iso diamond: cobble lattice on slopes
±0.75, extruded terrace volumes, door stoop marks. Passed as
`reference_image_paths` so the generator cannot fall back to its ~26° prior.

    python3 ArtSource/Processing/make_city_ward_seed_jigs.py
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ie_projection as ie

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "ArtSource/Generated/CityDistrict/V2/WardRebuild/jigs"

WORLD_W, WORLD_H = 4096.0, 3072.0
PX = 2.0
PLATE_W, PLATE_H = 8192, 6144
HALF_W, HALF_H = 584.0, 438.0
PERIOD, ROW_STEP = 840.0, 630.0
SIZE = 1024
SLOPE = ie.BGEE.ground_slope
STOREY = 420.0 * ie.BGEE.height_foreshorten * PX

BLOCKS = [
    (1, 1), (2, 0), (3, -1),
    (1, 0), (2, -1), (3, -2),
    (0, 0), (1, -1), (2, -2),
    (0, -1), (1, -2), (2, -3),
    (-1, -1), (0, -2), (1, -3),
]


def block_centre(i: int, j: int) -> tuple[float, float]:
    return PERIOD * (i - j), 1674.0 - ROW_STEP * (i + j)


def world_to_plate(x: float, y: float) -> tuple[float, float]:
    return x * PX, (WORLD_H - y) * PX


def lift(pt: tuple[float, float], h: float) -> tuple[float, float]:
    return pt[0], pt[1] - h


def paint_jig(i: int, j: int) -> Image.Image:
    cx, cy = block_centre(i, j)
    canvas = Image.new("RGB", (SIZE, SIZE), (18, 20, 24))
    arr = np.asarray(canvas).astype(np.float32)
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    # Local world around the diamond, y-up.
    wx = cx + (xx - SIZE / 2) / PX
    wy = cy + (SIZE - 1 - yy - SIZE / 2) / PX
    u = 0.5 * (wx + wy / SLOPE)
    v = 0.5 * (-wx + wy / SLOPE)
    cell = 8.0
    fu = np.abs(np.mod(u, cell) - cell / 2)
    fv = np.abs(np.mod(v, cell) - cell / 2)
    joint = np.clip(1.0 - np.minimum(fu, fv) / 0.7, 0, 1)
    metric = np.abs(wx - cx) / HALF_W + np.abs(wy - cy) / HALF_H
    inside = metric <= 1.0
    road = np.array((46, 50, 56), dtype=np.float32)
    pave = np.array((78, 74, 70), dtype=np.float32)
    lot = np.array((92, 70, 62), dtype=np.float32)
    mix = np.where(inside[..., None], lot, road)
    mix = mix * (1.0 - 0.35 * joint[..., None]) + pave * (0.20 * joint[..., None])
    canvas = Image.fromarray(np.clip(mix, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(canvas, "RGBA")

    def local(x: float, y: float) -> tuple[float, float]:
        px, py = world_to_plate(x, y)
        # Crop centred on the diamond's plate position.
        pcx, pcy = world_to_plate(cx, cy)
        return px - pcx + SIZE / 2, py - pcy + SIZE / 2

    near = local(cx, cy - HALF_H)
    right = local(cx + HALF_W, cy)
    far = local(cx, cy + HALF_H)
    left = local(cx - HALF_W, cy)
    h = STOREY * 0.55
    brick_l = (120, 72, 58, 255)
    brick_r = (88, 54, 48, 255)
    roof = (64, 70, 78, 255)
    d.polygon([near, left, lift(left, h), lift(near, h)], fill=brick_l)
    d.polygon([near, right, lift(right, h), lift(near, h)], fill=brick_r)
    d.polygon([lift(near, h), lift(right, h), lift(far, h), lift(left, h)], fill=roof)
    # Door stoop on the camera-near vertex.
    stoop = [
        (near[0] - 18, near[1] + 8),
        (near[0] + 18, near[1] + 8),
        (near[0] + 14, near[1] - 22),
        (near[0] - 14, near[1] - 22),
    ]
    d.polygon(stoop, fill=(28, 24, 22, 255), outline=(220, 190, 120, 255))
    # Axis guides.
    d.line([left, right], fill=(90, 210, 120, 90), width=2)
    d.line([near, far], fill=(90, 210, 120, 90), width=2)
    return canvas


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    index = []
    for i, j in BLOCKS:
        image = paint_jig(i, j)
        name = f"ward_jig_{i}_{j}.png"
        path = OUT / name
        image.save(path)
        index.append({"i": i, "j": j, "file": name, "centre": list(block_centre(i, j))})
        print(f"  {name}")
    (OUT / "jigs.json").write_text(json.dumps({"world": [WORLD_W, WORLD_H], "jigs": index}, indent=2))
    # Whole-ward lattice card at 2048 for the 1950s prompt lock.
    card = Image.new("RGB", (2048, 1536), (16, 18, 22))
    scale = 2048 / PLATE_W
    draw = ImageDraw.Draw(card)
    yy, xx = np.mgrid[0:1536, 0:2048].astype(np.float32)
    wx = xx / scale / PX
    wy = WORLD_H - yy / scale / PX
    u = 0.5 * (wx + wy / SLOPE)
    v = 0.5 * (-wx + wy / SLOPE)
    cell = 24.0
    fu = np.abs(np.mod(u, cell) - cell / 2)
    fv = np.abs(np.mod(v, cell) - cell / 2)
    joint = np.clip(1.0 - np.minimum(fu, fv) / 1.2, 0, 1)
    base = np.array((40, 44, 50), dtype=np.float32)
    arr = base * (1.0 - 0.45 * joint[..., None])
    card = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    draw = ImageDraw.Draw(card)
    for i, j in BLOCKS:
        cx, cy = block_centre(i, j)
        pts = [
            (cx, cy - HALF_H),
            (cx + HALF_W, cy),
            (cx, cy + HALF_H),
            (cx - HALF_W, cy),
        ]
        screen = [(x * PX * scale, (WORLD_H - y) * PX * scale) for x, y in pts]
        draw.polygon(screen, outline=(90, 210, 120, 255))
    card.save(OUT / "ward_lattice_card.png")
    print(f"wrote {len(BLOCKS)} jigs + lattice card → {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

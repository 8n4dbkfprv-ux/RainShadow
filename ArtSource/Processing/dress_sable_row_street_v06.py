#!/usr/bin/env python3
"""Dress Sable Row's V5 ground so lots and Harbor Street read as a ward.

Does not invent a second lattice. Lot fills, tram, drains and the Voss stoop
pad all sit on the same (u, v) period as `generate_city_grounds_world_scale_v05`.
Kerbs stay on ±0.75. Does not bake houses into the plate.

    python3 ArtSource/Processing/dress_sable_row_street_v06.py

Writes the dressed plate over `city_sable_row_ground_v02` / `_block_v02`
and rebuilds `map_city_sable_row_v02`. Copies the near-side terrace textures.
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import qa_plate_projection as qa
from generate_city_grounds_world_scale_v05 import (
    AREAS,
    GEN,
    MAPS,
    MAP_SIZE,
    PLATE_H,
    PLATE_W,
    PX_PER_UNIT,
    SLOPE,
    WORLD_H,
    WORLD_W,
    axis_uv,
    hardlink_or_copy,
    iso_street_masks,
    world_grids,
)
from survey_sable_iso_lots import PERIOD

ROOT = Path(__file__).resolve().parents[2]
PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/CityDistrict/V2"
CITY_TOLERANCE_DEG = 1.5

# Surveyed (i, j) → lot role. Materials differ; axes do not.
LOT_ROLE = {
    (1, 0): "harborWest",
    (2, -1): "harborVoss",
    (3, -2): "harborEast",
    (2, 0): "southWest",
    (3, -1): "southEast",
    (1, 1): "southFarWest",
    (1, -1): "upperWest",
    (2, -2): "upperEast",
    (0, 0): "upperFarWest",
    (0, -1): "skylineWest",
    (1, -2): "skylineEast",
}

# RGB fills for leftover (lot interior). Darker / dirtier than the carriageway.
LOT_FILL = {
    "harborWest": np.array((38, 32, 26), np.float32),
    "harborVoss": np.array((44, 34, 30), np.float32),
    "harborEast": np.array((40, 34, 30), np.float32),
    "southWest": np.array((28, 26, 24), np.float32),
    "southEast": np.array((30, 27, 24), np.float32),
    "southFarWest": np.array((28, 26, 24), np.float32),
    "upperWest": np.array((42, 40, 38), np.float32),
    "upperEast": np.array((40, 40, 42), np.float32),
    "upperFarWest": np.array((40, 38, 36), np.float32),
    "skylineWest": np.array((34, 36, 40), np.float32),
    "skylineEast": np.array((34, 36, 40), np.float32),
    "yard": np.array((36, 34, 32), np.float32),
}

# Harbor Street road lines in image (u, v) — crossing at world (2520, 414).
HARBOR_U = 5040.0
HARBOR_V = 0.0
WEST_U = 3360.0  # crossing at world (840, 414)


def _blur(arr: np.ndarray, radius: float) -> np.ndarray:
    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "L")
    from PIL import ImageFilter

    return np.asarray(im.filter(ImageFilter.GaussianBlur(radius=radius)), dtype=np.float32)


def lot_index(u: np.ndarray, v: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    iu = np.rint(u / PERIOD - 0.5).astype(np.int16)
    iv = np.rint(v / PERIOD - 0.5).astype(np.int16)
    return iu, iv


def world_to_image(wx: np.ndarray, wy: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    return wx * PX_PER_UNIT, (WORLD_H - wy) * PX_PER_UNIT


def dress(plate: np.ndarray) -> np.ndarray:
    h, w = plate.shape[:2]
    out = plate.astype(np.float32)
    wx, wy = world_grids(h, w)
    u, v = axis_uv(h, w)
    road, pavement, lip = iso_street_masks(u, v)
    leftover = np.clip(1.0 - road - pavement, 0.0, 1.0)
    iu, iv = lot_index(u, v)

    fill = np.broadcast_to(LOT_FILL["yard"], out.shape).copy()
    for (i, j), role in LOT_ROLE.items():
        mask = (iu == i) & (iv == j)
        fill[mask] = LOT_FILL[role]
    amount = leftover[..., None] * 0.55
    out = out * (1.0 - amount) + fill * amount

    # Packed-earth grain on lots only — hashed on the same uv so joints stay locked.
    hashed = np.mod(np.sin(iu.astype(np.float32) * 127.1 + iv.astype(np.float32) * 311.7) * 43758.5, 1.0)
    grain = (_blur(hashed * 255.0, 6.0) / 255.0 - 0.5) * leftover
    out = out * (1.0 + 0.10 * grain[..., None])

    # Harbor Street tram: two rails on the u=5040 and v=0 carriageways.
    # Image-u/v units; rails sit inside the road, parallel to the kerb.
    def rails(coord: np.ndarray, centre: float) -> np.ndarray:
        d = np.abs(coord - centre)
        inner = np.exp(-((d - 11.0) ** 2) / 6.5)
        outer = np.exp(-((d - 22.0) ** 2) / 6.5)
        return np.clip(inner + outer, 0.0, 1.0)

    harbor_band = (wy > 160.0) & (wy < 780.0) & (wx > 200.0) & (wx < 3900.0)
    tram = (
        rails(u, HARBOR_U) * ((np.abs(v - HARBOR_V) < 520.0).astype(np.float32))
        + rails(v, HARBOR_V) * ((np.abs(u - HARBOR_U) < 520.0).astype(np.float32))
        + rails(u, WEST_U) * ((np.abs(v - HARBOR_V) < 360.0).astype(np.float32))
    )
    tram = np.clip(tram, 0.0, 1.0) * road * harbor_band.astype(np.float32)
    out = out * (1.0 - 0.38 * tram[..., None])
    out = out + np.array((8.0, 10.0, 12.0), np.float32) * (0.12 * tram[..., None])

    # Drains / manholes at the two Harbor Street crossings. Ground circle → 16:12 ellipse.
    def ellipse(cx: float, cy: float, rx: float, ry: float) -> np.ndarray:
        return ((wx - cx) / rx) ** 2 + ((wy - cy) / ry) ** 2

    for cx, cy in ((2520.0, 414.0), (840.0, 414.0), (1680.0, 1044.0)):
        d = ellipse(cx, cy, 18.0, 13.5)
        hole = np.clip(1.0 - d, 0.0, 1.0) ** 2 * road
        ring = np.clip(1.0 - np.abs(d - 1.0) * 4.0, 0.0, 1.0) * road
        out = out * (1.0 - 0.45 * hole[..., None])
        out = out + np.array((18.0, 16.0, 14.0), np.float32) * (0.20 * ring[..., None])

    # Voss stoop pad: a short walk from the lot near tip along the SE kerb (slope +0.75).
    # World (2520, 606) → (2680, 726).
    sx, sy = 2520.0, 606.0
    along = (wx - sx) * 0.8 + (wy - sy) * 0.6
    perp = -(wx - sx) * 0.6 + (wy - sy) * 0.8
    stoop = (
        (along > -20.0)
        & (along < 200.0)
        & (np.abs(perp) < 28.0)
        & (leftover + pavement > 0.15)
    ).astype(np.float32)
    stoop = _blur(stoop * 255.0, 3.0) / 255.0
    brick = np.array((62, 42, 36), np.float32)
    out = out * (1.0 - 0.55 * stoop[..., None]) + brick * (0.55 * stoop[..., None])

    # Unique standing water at the Voss crossing — this puddle belongs to this corner.
    puddle = np.exp(-(((wx - 2480.0) / 90.0) ** 2 + ((wy - 390.0) / 55.0) ** 2))
    puddle = puddle * road
    out = out * (1.0 - 0.22 * puddle[..., None])
    out = out + np.array((20.0, 28.0, 36.0), np.float32) * (0.30 * puddle[..., None])

    # Lamp pools on the painted crossings, not the retired axis-aligned grid.
    lamp = np.array((210.0, 150.0, 70.0), np.float32)
    for lx, ly, radius, strength in (
        (2520.0, 414.0, 200.0, 0.16),
        (840.0, 414.0, 180.0, 0.14),
        (1680.0, 1044.0, 160.0, 0.10),
        (3360.0, 1044.0, 150.0, 0.10),
        (2520.0, 606.0, 120.0, 0.08),
    ):
        d2 = (wx - lx) ** 2 + (wy - ly) ** 2
        pool = np.exp(-d2 / (2.0 * radius * radius)) * strength
        out = out + lamp * pool[..., None]

    # Keep the kerb lip readable after the fills.
    out = out * (1.0 - 0.08 * lip[..., None])
    return np.clip(out, 0, 255).astype(np.uint8)


def install_south_terraces() -> None:
    """Near-side houses reuse seated iso volumes under new names (no door pairing)."""
    pairs = (
        ("city_terrace_sable_sw.png", "city_terrace_sable_south_w.png"),
        ("city_terrace_sable_ne.png", "city_terrace_sable_south_e.png"),
    )
    dest_dir = GEN / "Terraces"
    dest_dir.mkdir(parents=True, exist_ok=True)
    for src_name, dst_name in pairs:
        src = PROPS / src_name
        if not src.exists():
            raise SystemExit(f"missing {src}")
        dst = PROPS / dst_name
        shutil.copy2(src, dst)
        shutil.copy2(src, dest_dir / dst_name)
        print(f"  copied {src_name} → {dst_name}")


def main() -> int:
    src = AREAS / "city_sable_row_ground_v02.png"
    if not src.exists():
        raise SystemExit(f"missing {src}")
    print(f"dressing {src}")
    plate = np.asarray(Image.open(src).convert("RGB"))
    if plate.shape[1] != PLATE_W or plate.shape[0] != PLATE_H:
        raise SystemExit(f"expected {PLATE_W}x{PLATE_H}, got {plate.shape[1]}x{plate.shape[0]}")
    dressed = dress(plate)
    Image.fromarray(dressed, "RGB").save(src, "PNG", compress_level=3)
    gen_dir = GEN / "SableRow"
    gen_dir.mkdir(parents=True, exist_ok=True)
    hardlink_or_copy(src, AREAS / "city_sable_row_block_v02.png")
    hardlink_or_copy(src, gen_dir / "city_sable_row_ground_v02.png")
    hardlink_or_copy(src, gen_dir / "city_sable_row_block_v02.png")
    MAPS.mkdir(parents=True, exist_ok=True)
    Image.fromarray(dressed, "RGB").resize(MAP_SIZE, Image.Resampling.LANCZOS).save(
        MAPS / "map_city_sable_row_v02.png", "PNG", compress_level=4
    )
    install_south_terraces()

    result = qa.grade(src)
    density = src.stat().st_size  # printed for the log; px/unit is the gate
    px_per_unit = PLATE_W / WORLD_W
    passes = result["worst_delta"] <= CITY_TOLERANCE_DEG and px_per_unit >= 2.0
    print(
        f"  axes {result['peak_pos']:+.2f}/{result['peak_neg']:+.2f}  "
        f"worst {result['worst_delta']:.2f}°  density {px_per_unit:.2f}  "
        f"{'PASS' if passes else 'FAIL'}"
    )
    if density:
        print(f"  wrote {src} ({src.stat().st_size // 1024} KB) and map")
    return 0 if passes else 1


if __name__ == "__main__":
    raise SystemExit(main())

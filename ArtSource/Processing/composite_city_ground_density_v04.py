#!/usr/bin/env python3
"""Composite native-resolution stonework onto a V3 city ground master.

The V3 1536×1024 grounds are on the BG:EE lock. The generator cannot emit
4096-wide plates, so a naked Lanczos to `PLATE_SIZE` would pass
`qa_plate_density.py` by adding empty pixels. This module keeps the V3 macro
(layout, kerbs, lighting, puddles) and paints a new high-frequency sett /
flag layer at the V4 pixel scale:

    granite sett     10.75 -> 12.9 px on screen  (0.12 m × 107 px/m)
    pavement flag    45    -> 54.0 px on screen  (0.50 m)
    joints           soft, worn — not engraved

V4 laid a 0.18 m lattice on top of the master's own ~0.25 m stonework and the
play-zoom A/B came out indistinguishable: the two modules are close enough that
the coarse one still won, and the ground just got busier. The dominant lattice
vector in the rendered frame did not move at all. So this pass suppresses the
master's stone band inside the carriageway first, then lays a genuinely finer
module in at full strength.

Joints follow slopes ±0.75 so the overlay reinforces the camera lock instead
of fighting it. Water and specular puddles from the master are left alone.

    python3 ArtSource/Processing/composite_city_ground_density_v04.py \\
        <v3-ground.png> <out.png>
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ie_projection as ie
import process_city_districts_v02 as proc

SLOPE = ie.BGEE.ground_slope  # 0.75
# Cell sizes are in u/v units. One u/v unit is 1/|grad v| = 1.2 screen px, so a
# 0.12 m sett (12.9 screen px at 107 px per ground metre) is 10.75 here.
SETT_PX = 10.75
FLAG_PX = 45.0
# The original V4 module, kept for masters that cannot carry the finer one.
SETT_PX_COARSE = 16.0
FLAG_PX_COARSE = 56.0
JOINT = 0.11  # fraction of a cell that is mortar

# The V3 master's own paving, measured on the installed 4096 plate: a ~27 px
# pitch, about 0.25 m. That is the module the eye actually locks onto, and no
# amount of added detail displaces it while it is still there.
MASTER_STONE_PX = 27.0
# How much of that band to remove inside road/pavement. Below ~0.6 the coarse
# stones still read through; above ~0.85 the carriageway goes flat.
SUPPRESS = 0.72
# Overlay strength. Raised from 0.42 because the new lattice now has to carry
# the surface rather than decorate it.
AMOUNT = 0.55


def _blur(arr: np.ndarray, radius: float) -> np.ndarray:
    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "L")
    return np.asarray(im.filter(ImageFilter.GaussianBlur(radius=radius)), dtype=np.float32)


def axis_uv(h: int, w: int) -> tuple[np.ndarray, np.ndarray]:
    """Screen (x, y-down) → ground-axis coordinates (NE, NW)."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    u = 0.5 * (x + y / SLOPE)
    v = 0.5 * (-x + y / SLOPE)
    return u, v


def cell_field(u: np.ndarray, v: np.ndarray, cell: float) -> tuple[np.ndarray, np.ndarray]:
    """Running-bond modules. Returns (distance-to-joint 0..0.5, per-cell hash 0..1)."""
    iu = np.floor(u / cell)
    vv = v / cell + 0.5 * np.mod(iu, 2.0)
    iv = np.floor(vv)
    fu = u / cell - iu
    fv = vv - iv
    dist = np.minimum(np.minimum(fu, 1.0 - fu), np.minimum(fv, 1.0 - fv))
    hashed = np.mod(np.sin(iu * 127.1 + iv * 311.7) * 43758.5453, 1.0)
    return dist, hashed.astype(np.float32)


def stone_detail(u: np.ndarray, v: np.ndarray, cell: float) -> np.ndarray:
    """High-frequency signed detail in roughly [-1, 1]."""
    dist, hashed = cell_field(u, v, cell)
    joint = np.clip(1.0 - dist / JOINT, 0.0, 1.0)
    joint = joint * joint
    # Soft face variation, plus a worn lip just inside the joint.
    face = (hashed - 0.5) * 0.55
    lip = np.clip((dist - JOINT) / (JOINT * 1.4), 0.0, 1.0)
    lip = (1.0 - lip) * (1.0 - joint) * 0.18
    return face + lip - joint * 0.85


def suppress_master_stone(
    base: np.ndarray, road: np.ndarray, pavement: np.ndarray
) -> np.ndarray:
    """Remove the master's own paving band from the carriageway and pavement.

    Luminance-space, so hue and the baked lighting survive. Real edges — kerb
    lines, drain rims, tram rails — swing much harder than paving grain, so the
    removal is scaled down where the local swing is large; without that the
    kerbs go soft along with the stones.
    """
    lum = base.mean(2)
    hf = lum - _blur(lum, MASTER_STONE_PX / 3.0)
    keep_edges = np.clip(1.0 - np.abs(hf) / 26.0, 0.0, 1.0)
    mask = np.clip(road + pavement, 0.0, 1.0) * SUPPRESS * keep_edges
    return base - (hf * mask)[..., None]


def segment(lum: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """water, pavement, carriageway masks in 0..1."""
    local = _blur(lum, 7.0)
    var = _blur((lum - local) ** 2, 5.0)
    water = np.clip((10.0 - lum) / 6.0, 0.0, 1.0) * np.clip((8.0 - np.sqrt(var)) / 6.0, 0.0, 1.0)
    # Raised pavement reads a bit lighter than the wet carriageway.
    pavement = np.clip((local - np.percentile(local, 58)) / 12.0, 0.0, 1.0) * (1.0 - water)
    road = np.clip(1.0 - water - pavement, 0.0, 1.0)
    return water, pavement, road


def mean_abs_vs_upscale(master: Image.Image, plate: Image.Image) -> float:
    """How far `plate` sits from a naked Lanczos of `master` to `plate.size`."""
    up = proc.fit_to_aspect(master.convert("RGB"), plate.size)
    a = np.asarray(plate.convert("RGB"), dtype=np.float32)
    b = np.asarray(up, dtype=np.float32)
    return float(np.abs(a - b).mean())


def assert_not_naked_upscale(master: Image.Image, plate: Image.Image, floor: float = 1.0) -> float:
    """Refuse a plate that would pass `qa_plate_density.py` by adding empty pixels."""
    delta = mean_abs_vs_upscale(master, plate)
    if delta < floor:
        raise SystemExit(
            f"overlay too weak ({delta:.3f} < {floor:.1f} mean-abs RGB) — "
            "would pass density as a super-resolution upscale"
        )
    return delta


# Districts whose master cannot carry the fine module. `civic_records` is the
# shallowest ground we have — it has measured at the bottom of every pass since
# the first audit — and suppressing its stone band to make room for a 0.12 m
# lattice tips it from 3.92 deg to 4.04, outside the lock. It keeps the coarse
# module until its master is regenerated; then delete this set.
COARSE_DISTRICTS = frozenset({"civic_records"})


def composite(
    master: Image.Image,
    size: tuple[int, int] = proc.PLATE_SIZE,
    *,
    fine: bool = True,
) -> Image.Image:
    base_im = proc.fit_to_aspect(master.convert("RGB"), size)
    base = np.asarray(base_im, dtype=np.float32)
    h, w = base.shape[:2]
    lum = base.mean(2)
    water, pavement, road = segment(lum)
    if fine:
        # Segment on the untouched master (its water test needs the original
        # grain), then clear the coarse stonework before laying the new module.
        base = suppress_master_stone(base, road, pavement)
    sett_px, flag_px = (SETT_PX, FLAG_PX) if fine else (SETT_PX_COARSE, FLAG_PX_COARSE)
    u, v = axis_uv(h, w)
    sett = stone_detail(u, v, sett_px)
    flag = stone_detail(u, v, flag_px)
    detail = sett * road + flag * pavement
    # Leave puddles and open water on the master — they already grade.
    wet = np.clip((14.0 - lum) / 10.0, 0.0, 1.0) * (1.0 - water)
    amount = ((AMOUNT if fine else 0.42) * (1.0 - 0.65 * wet))[..., None]
    out = base * (1.0 + detail[..., None] * amount)
    out = np.clip(out, 0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGB")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("src", type=Path)
    ap.add_argument("dst", type=Path)
    args = ap.parse_args()
    out = composite(Image.open(args.src))
    args.dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(args.dst, "PNG", optimize=True)
    print(f"wrote {args.dst} {out.size}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

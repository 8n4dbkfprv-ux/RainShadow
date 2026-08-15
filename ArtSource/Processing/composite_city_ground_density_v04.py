#!/usr/bin/env python3
"""Composite native-resolution stonework onto a V3 city ground master.

The V3 1536×1024 grounds are on the BG:EE lock. The generator cannot emit
4096-wide plates, so a naked Lanczos to `PLATE_SIZE` would pass
`qa_plate_density.py` by adding empty pixels. This module keeps the V3 macro
(layout, kerbs, lighting, puddles) and paints a new high-frequency sett /
flag layer at the V4 pixel scale:

    granite sett     16 px along the ground axes  (0.15 m × 107 px/m)
    pavement flag    56 px                         (0.52 m)
    joints           soft, worn — not engraved

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
SETT_PX = 16.0
FLAG_PX = 56.0
JOINT = 0.11  # fraction of a cell that is mortar


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


def composite(master: Image.Image, size: tuple[int, int] = proc.PLATE_SIZE) -> Image.Image:
    base_im = proc.fit_to_aspect(master.convert("RGB"), size)
    base = np.asarray(base_im, dtype=np.float32)
    h, w = base.shape[:2]
    lum = base.mean(2)
    water, pavement, road = segment(lum)
    u, v = axis_uv(h, w)
    sett = stone_detail(u, v, SETT_PX)
    flag = stone_detail(u, v, FLAG_PX)
    detail = sett * road + flag * pavement
    # Leave puddles and open water on the master — they already grade.
    wet = np.clip((14.0 - lum) / 10.0, 0.0, 1.0) * (1.0 - water)
    amount = (0.42 * (1.0 - 0.65 * wet))[..., None]
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

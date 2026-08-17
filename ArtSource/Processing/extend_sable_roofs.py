#!/usr/bin/env python3
"""Extend each hero lot's own painted roof back through the courtyard.

No Imagine, no stamped tile sheet. The near terrace already has a camera-
correct roof; this copies that roof along the lot, then locks the v01
street wall through.

    python3 ArtSource/Processing/extend_sable_roofs.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fill_sable_lot_roofs import (
    GEN, PROPS, ORIG, OPAQUE,
    diamond_fields, split_blobs, convex_hull_mask, rebuild_flatten,
)

HEROES = (
    "harborWest", "harborVoss", "upperWest", "upperEast", "southWest", "southEast"
)


def near_roof(orig: np.ndarray, near: np.ndarray) -> np.ndarray:
    rgb = orig[:, :, :3].astype(np.float32)
    luma = rgb.mean(axis=2)
    ys, _ = np.where(near)
    cut = ys.min() + 0.50 * (ys.max() - ys.min())
    top = near & (np.arange(near.shape[0])[:, None] <= cut)
    cool = rgb[:, :, 2] + 10 >= rgb[:, :, 0]
    roof = top & cool & (luma > 35) & (luma < 130)
    if roof.sum() < 300:
        roof = top
    return roof


def extend(orig: np.ndarray, lot: dict) -> np.ndarray:
    opaque = orig[:, :, 3] > OPAQUE
    near, far = split_blobs(opaque)
    roof = near_roof(orig, near)
    _, _, metric = diamond_fields(orig.shape[:2], lot)
    diamond = metric <= 1.02
    hull = convex_hull_mask(opaque, pad=12)
    gap = (~opaque) & hull & diamond
    # Keep far building; we only fill the empty courtyard.
    if not roof.any() or not gap.any():
        return orig

    rys, _ = np.where(roof)
    roof_top = int(rys.min())
    roof_bot = int(np.percentile(rys, 70))
    band = orig[roof_top:roof_bot + 1]
    band_h, width = band.shape[0], band.shape[1]
    # For each band row, nearest painted x so we can sample in numpy.
    filled_band = band.copy()
    for row in range(band_h):
        xs = np.where(band[row, :, 3] > OPAQUE)[0]
        if len(xs) == 0:
            continue
        cols = np.arange(width)
        idx = np.searchsorted(xs, cols)
        idx = np.clip(idx, 0, len(xs) - 1)
        idx_lo = np.clip(idx - 1, 0, len(xs) - 1)
        pick = np.where(np.abs(xs[idx] - cols) <= np.abs(xs[idx_lo] - cols), xs[idx], xs[idx_lo])
        filled_band[row] = band[row, pick]

    out = orig.copy()
    gy, gx = np.where(gap & (np.arange(orig.shape[0])[:, None] < roof_top))
    dist = roof_top - gy
    src_y = dist % band_h
    sample = filled_band[src_y, gx]
    fade = np.clip(1.0 - dist / 1400.0, 0.82, 1.0).astype(np.float32)
    out[gy, gx, :3] = np.clip(sample[:, :3].astype(np.float32) * fade[:, None], 0, 255)
    out[gy, gx, 3] = 255

    # Soften only the new pixels.
    soft = np.array(Image.fromarray(out).filter(ImageFilter.GaussianBlur(radius=0.45)))
    out[gap] = soft[gap]
    return out


def main() -> int:
    bake = json.loads((GEN / "sable_area_bake.json").read_text())
    lots = {lot["textureName"].removeprefix("city_sable_lot_"): lot for lot in bake["lots"]}
    for name in HEROES:
        orig = np.array(Image.open(ORIG / f"city_sable_lot_{name}.png").convert("RGBA"))
        out = extend(orig, lots[name])
        near, _ = split_blobs(orig[:, :, 3] > OPAQUE)
        hold = float(np.mean(np.abs(
            out[:, :, :3][near].astype(np.int16) - orig[:, :, :3][near].astype(np.int16)
        )))
        dest = f"city_sable_lot_{name}.png"
        Image.fromarray(out).save(GEN / dest, "PNG", compress_level=4)
        Image.fromarray(out).save(PROPS / dest, "PNG", compress_level=4)
        filled = int(((out[:, :, 3] > OPAQUE) & (orig[:, :, 3] <= OPAQUE)).sum())
        print(f"  {name:12} filled={filled:7d}  lockΔ={hold:.3f}")
        if hold > 0.01:
            print("LOCK FAILED", name)
            return 1
    rebuild_flatten(bake)
    print("LOCK HOLDS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

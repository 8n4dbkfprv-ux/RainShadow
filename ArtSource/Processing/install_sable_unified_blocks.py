#!/usr/bin/env python3
"""Seat painted one-volume blocks on the v01 street walls.

Imagine produced whole city blocks. This scales each block to the original
near facade, sits its foot on that facade's foot, then copies the v01 near
wall through so Voss's stoop and the Harbor Street kerb cannot move.

    python3 ArtSource/Processing/install_sable_unified_blocks.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fill_sable_lot_roofs import (
    GEN, PROPS, ORIG, OPAQUE, PX, WORLD_H, HALF_W, HALF_H,
    diamond_fields, split_blobs, write_png, rebuild_flatten,
)

SESSION = Path(
    "/Users/laurensvanoorschot/.grok/sessions/"
    "%2FUsers%2Flaurensvanoorschot%2FRainShadow/"
    "01a00a59-62cb-7180-b70f-62227c6a37e1/images"
)
BLOCKS = {
    "harborVoss": SESSION / "24.jpg",
    "harborWest": SESSION / "26.jpg",
    "upperWest": SESSION / "28.jpg",
    "upperEast": SESSION / "23.jpg",
    "southWest": SESSION / "25.jpg",
    "southEast": SESSION / "27.jpg",
}


def opaque_bbox(mask: np.ndarray) -> tuple[int, int, int, int]:
    ys, xs = np.where(mask)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def seat_block(orig: np.ndarray, block_path: Path, lot: dict) -> np.ndarray:
    near, far = split_blobs(orig[:, :, 3] > OPAQUE)
    nx0, ny0, nx1, ny1 = opaque_bbox(near)
    near_w = nx1 - nx0
    near_foot_y = ny1
    near_cx = (nx0 + nx1) / 2
    far_top = opaque_bbox(far)[1] if far.any() else 0

    src = Image.open(block_path).convert("RGBA")
    arr = np.array(src)
    luma = arr[:, :, :3].max(axis=2)
    arr[luma < 18, 3] = 0
    src = Image.fromarray(arr)
    bx0, by0, bx1, by1 = opaque_bbox(arr[:, :, 3] > 0)
    crop = src.crop((bx0, by0, bx1, by1))
    scale_w = near_w / crop.size[0]
    scale_h = max(1, near_foot_y - far_top) / crop.size[1]
    scale = max(scale_w, scale_h)
    new_w = max(1, int(round(crop.size[0] * scale)))
    new_h = max(1, int(round(crop.size[1] * scale)))
    seated = crop.resize((new_w, new_h), Image.Resampling.LANCZOS)

    canvas = Image.fromarray(orig).convert("RGBA")
    left = int(round(near_cx - new_w / 2))
    top = int(round(near_foot_y - new_h))
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    layer.paste(seated, (left, top), seated)
    placed = np.array(layer)

    _, _, metric = diamond_fields(orig.shape[:2], lot)
    diamond = metric <= 1.04
    yy = np.arange(orig.shape[0])[:, None]
    # New paint only behind the street wall, never beside the shop fronts.
    use = (placed[:, :, 3] > OPAQUE) & diamond & (~near) & (yy < ny0 + 12)
    out = orig.copy()
    out[use] = placed[use]
    out[near] = orig[near]
    return out


def main() -> int:
    bake = json.loads((GEN / "sable_area_bake.json").read_text())
    lots = {lot["textureName"].removeprefix("city_sable_lot_"): lot for lot in bake["lots"]}
    for name, path in BLOCKS.items():
        orig = np.array(Image.open(ORIG / f"city_sable_lot_{name}.png").convert("RGBA"))
        out = seat_block(orig, path, lots[name])
        near, _ = split_blobs(orig[:, :, 3] > OPAQUE)
        hold = float(np.mean(np.abs(
            out[:, :, :3][near].astype(np.int16) - orig[:, :, :3][near].astype(np.int16)
        )))
        dest = f"city_sable_lot_{name}.png"
        Image.fromarray(out).save(GEN / dest, "PNG", compress_level=4)
        Image.fromarray(out).save(PROPS / dest, "PNG", compress_level=4)
        print(f"  {name:12} lockΔ={hold:.3f}  opaque {(out[:,:,3]>OPAQUE).mean()*100:.1f}%")
        if hold > 0.01:
            print("LOCK FAILED", name)
            return 1
    rebuild_flatten(bake)
    print("LOCK HOLDS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

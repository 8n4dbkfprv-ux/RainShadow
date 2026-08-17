#!/usr/bin/env python3
"""Plant Imagine-painted roofs behind the v01 street walls.

The full blocks fought the terrace camera. Their roofs are real paint;
this keeps only that roof deck, seated on the near building's roof line.

    python3 ArtSource/Processing/install_sable_block_roofs.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fill_sable_lot_roofs import (
    GEN, PROPS, ORIG, OPAQUE,
    diamond_fields, split_blobs, convex_hull_mask, rebuild_flatten,
)
from install_sable_unified_blocks import BLOCKS, opaque_bbox


def plant_roof(orig: np.ndarray, block_path: Path, lot: dict) -> np.ndarray:
    near, far = split_blobs(orig[:, :, 3] > OPAQUE)
    nx0, ny0, nx1, ny1 = opaque_bbox(near)
    src = Image.open(block_path).convert("RGBA")
    arr = np.array(src)
    luma = arr[:, :, :3].max(axis=2)
    arr[luma < 18, 3] = 0
    bx0, by0, bx1, by1 = opaque_bbox(arr[:, :, 3] > 0)
    # Upper 58% of the painted block is roof + chimneys.
    roof_cut = by0 + int((by1 - by0) * 0.58)
    roof = Image.fromarray(arr).crop((bx0, by0, bx1, roof_cut))

    gap_w = nx1 - nx0
    # Roof should span the courtyard: from the near roof line up to the far foot.
    if far.any():
        _fx0, fy0, _fx1, fy1 = opaque_bbox(far)
        gap_h = max(80, ny0 - fy1)
    else:
        gap_h = max(80, ny0)
    scale = max(gap_w / roof.size[0], gap_h / max(1, roof.size[1]))
    new_w = max(1, int(round(roof.size[0] * scale)))
    new_h = max(1, int(round(roof.size[1] * scale)))
    roof = roof.resize((new_w, new_h), Image.Resampling.LANCZOS)

    layer = Image.new("RGBA", (orig.shape[1], orig.shape[0]), (0, 0, 0, 0))
    left = int(round((nx0 + nx1) / 2 - new_w / 2))
    # Sit the roof's near edge on the near building's roof line.
    top = int(ny0 - new_h + new_h * 0.18)
    layer.paste(roof, (left, top), roof)
    placed = np.array(layer)

    _, _, metric = diamond_fields(orig.shape[:2], lot)
    hull = convex_hull_mask(orig[:, :, 3] > OPAQUE, pad=10)
    yy = np.arange(orig.shape[0])[:, None]
    use = (
        (placed[:, :, 3] > OPAQUE)
        & (metric <= 1.03)
        & hull
        & (~near)
        & (yy < ny0 + 6)
    )
    out = orig.copy()
    out[use] = placed[use]
    out[near] = orig[near]
    return out


def main() -> int:
    bake = json.loads((GEN / "sable_area_bake.json").read_text())
    lots = {lot["textureName"].removeprefix("city_sable_lot_"): lot for lot in bake["lots"]}
    for name, path in BLOCKS.items():
        orig = np.array(Image.open(ORIG / f"city_sable_lot_{name}.png").convert("RGBA"))
        out = plant_roof(orig, path, lots[name])
        near, _ = split_blobs(orig[:, :, 3] > OPAQUE)
        hold = float(np.mean(np.abs(
            out[:, :, :3][near].astype(np.int16) - orig[:, :, :3][near].astype(np.int16)
        )))
        dest = f"city_sable_lot_{name}.png"
        Image.fromarray(out).save(GEN / dest, "PNG", compress_level=4)
        Image.fromarray(out).save(PROPS / dest, "PNG", compress_level=4)
        print(f"  {name:12} lockΔ={hold:.3f}")
        if hold > 0.01:
            print("LOCK FAILED", name)
            return 1
    rebuild_flatten(bake)
    print("LOCK HOLDS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

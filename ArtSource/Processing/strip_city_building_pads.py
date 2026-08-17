#!/usr/bin/env python3
"""Remove the baked cobble diamond under city building sprites.

Each facade shipped with its own ground pad. On the new street tiles that pad
reads as a floating island. This keeps the building pixels (and stoop stairs)
in place so door apertures stay valid, and erases the pad wings.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PROPS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Props" / "CityDistrict" / "V2"


def strip_pad(im: Image.Image) -> Image.Image:
    rgba = np.array(im.convert("RGBA"))
    a = rgba[:, :, 3]
    h, w = a.shape
    painted = a > 36
    rows = np.where(painted.any(1))[0]
    cols = np.where(painted.any(0))[0]
    if rows.size < 8 or cols.size < 8:
        return im
    y0, y1 = int(rows[0]), int(rows[-1])
    body_y0 = y0 + int((y1 - y0) * 0.22)
    body_y1 = y0 + int((y1 - y0) * 0.62)
    body = painted[body_y0:body_y1]
    if not body.any():
        return im
    xs = np.where(body.any(0))[0]
    left, right = int(xs[0]), int(xs[-1])
    pad = 10
    left = max(0, left - pad)
    right = min(w - 1, right + pad)
    # Below the wall foot: keep only the building column (stairs sit in-column).
    foot = y0 + int((y1 - y0) * 0.70)
    kill = painted.copy()
    kill[:foot] = False
    kill[:, left : right + 1] = False
    # The camera-near pad in front of the walls: drop the lowest 12% outside
    # a narrower stair band.
    near = y0 + int((y1 - y0) * 0.88)
    stair_l = left + int((right - left) * 0.28)
    stair_r = left + int((right - left) * 0.72)
    front = painted.copy()
    front[:near] = False
    front[:, stair_l : stair_r + 1] = False
    erase = kill | front
    rgba[erase, 3] = 0
    rgba[erase, :3] = 0
    return Image.fromarray(rgba, "RGBA")


def main() -> int:
    slugs = sys.argv[1:]
    paths = (
        [PROPS / f"city_building_{s}.png" for s in slugs]
        if slugs
        else sorted(p for p in PROPS.glob("city_building_*.png") if " 2.png" not in p.name)
    )
    n = 0
    for path in paths:
        if not path.exists():
            print("missing", path.name)
            continue
        out = strip_pad(Image.open(path))
        out.save(path, "PNG", compress_level=4)
        n += 1
        print("stripped", path.name)
    print(f"updated {n}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

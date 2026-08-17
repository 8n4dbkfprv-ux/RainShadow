#!/usr/bin/env python3
"""Key, flatten and fit a pad-removed building edit onto the 512x640 canvas."""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_city_grounds_world_scale_v05 import flatten_interior_alpha
from process_city_districts_v02 import fit_canvas, trim_alpha

PROPS = Path(__file__).resolve().parents[2] / "RainShadow Shared/Resources/Art/Props/CityDistrict/V2"


def key_black(im: Image.Image, lum: float = 16.0) -> Image.Image:
    rgba = np.array(im.convert("RGBA"), dtype=np.float32)
    L = rgba[:, :, :3].mean(2)
    # Also kill the faint green registration specks some edits leave.
    g = rgba[:, :, 1]
    r = rgba[:, :, 0]
    b = rgba[:, :, 2]
    green_dot = (g > r + 30) & (g > b + 30) & (g > 40) & (g < 90)
    rgba[:, :, 3] = np.where((L < lum) | green_dot, 0, 255)
    rgba[:, :, :3] = np.where(rgba[:, :, 3:4] < 8, 0, rgba[:, :, :3])
    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")


def install(src: Path, dest_name: str) -> Path:
    dest = PROPS / dest_name
    im = key_black(Image.open(src))
    im = flatten_interior_alpha(trim_alpha(im, threshold=20, pad=2), floor=24)
    im = fit_canvas(im, (512, 640))
    dest.parent.mkdir(parents=True, exist_ok=True)
    im.save(dest, "PNG", compress_level=4)
    print(f"wrote {dest.name} {im.size}")
    return dest


def main() -> int:
    args = sys.argv[1:]
    if len(args) % 2:
        raise SystemExit("usage: install_edited_city_building.py src dest_name [src dest_name ...]")
    for src, name in zip(args[0::2], args[1::2]):
        install(Path(src), name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

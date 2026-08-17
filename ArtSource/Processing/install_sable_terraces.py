#!/usr/bin/env python3
"""Install Sable Row terrace masters at authored 2.00 px/unit canvas size.

Centre-crops to the target aspect, scales uniformly, chroma/black-keys, flattens
interior alpha, and punches the registered door holes so leaf derivation matches
`CityDistrictLayout.SourceDoorAperture.terraceSable*`.

    python3 ArtSource/Processing/install_sable_terraces.py
    python3 ArtSource/Processing/install_sable_terraces.py --from-masters

Do not call process_city_districts_v02.main().
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_city_grounds_world_scale_v05 import flatten_interior_alpha
from generate_sable_terraces_v01 import HOLES, TERRACES, punch_holes
from process_city_districts_v02 import fit_to_aspect, trim_alpha

ROOT = Path(__file__).resolve().parents[2]
PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/CityDistrict/V2"
MASTERS = ROOT / "ArtSource/Generated/CityDistrict/V2/Terraces"


def key_black(im: Image.Image, lum: float = 16.0) -> Image.Image:
    rgba = np.array(im.convert("RGBA"), dtype=np.float32)
    L = rgba[:, :, :3].mean(2)
    g, r, b = rgba[:, :, 1], rgba[:, :, 0], rgba[:, :, 2]
    green_dot = (g > r + 30) & (g > b + 30) & (g > 40) & (g < 90)
    rgba[:, :, 3] = np.where((L < lum) | green_dot, 0, 255)
    rgba[:, :, :3] = np.where(rgba[:, :, 3:4] < 8, 0, rgba[:, :, :3])
    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")


def install_master(src: Path, dest_name: str, size: tuple[int, int], holes: list[dict]) -> Path:
    dest = PROPS / dest_name
    im = key_black(Image.open(src))
    im = flatten_interior_alpha(trim_alpha(im, threshold=20, pad=2), floor=24)
    im = fit_to_aspect(im, size)
    im = punch_holes(im, holes)
    dest.parent.mkdir(parents=True, exist_ok=True)
    im.save(dest, "PNG", compress_level=4)
    print(f"wrote {dest.name} {im.size}")
    return dest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--from-masters",
        action="store_true",
        help="Install from ArtSource/Generated/CityDistrict/V2/Terraces instead of painting.",
    )
    args = parser.parse_args()
    if args.from_masters:
        for face, spec in TERRACES.items():
            src = MASTERS / spec["name"]
            if not src.exists():
                raise SystemExit(f"missing master {src}")
            install_master(src, spec["name"], spec["size"], HOLES[face])
        return 0
    from install_sable_terraces_iso import main as install_iso
    return install_iso()


if __name__ == "__main__":
    raise SystemExit(main())

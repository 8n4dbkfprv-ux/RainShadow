#!/usr/bin/env python3
"""Install Sable Row's opposite row, north skyline, and corner shops.

These close the south street into a canyon, put city beyond the north street,
and give the map-edge corners a face — so the ward reads as a crossroads, not
one terrace on empty paving.

    python3 ArtSource/Processing/install_sable_district_structure.py
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_city_grounds_world_scale_v05 import flatten_interior_alpha
from install_sable_terraces_iso import key_black, trim, scale_fit

ROOT = Path(__file__).resolve().parents[2]
PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/CityDistrict/V2"
OUT = ROOT / "ArtSource/Generated/CityDistrict/V2/Terraces"
SESSION = Path(
    "/Users/laurensvanoorschot/.grok/sessions/"
    "%2FUsers%2Flaurensvanoorschot%2FRainShadow/01a006e5-c905-7fc2-876c-6898424b5f92/images"
)

# 2.00 px/unit. South row stays short so Voss on Harbor Street (y≈220–360)
# does not y-overlap the sprite.
JOBS = {
    "city_district_sable_north_skyline.png": {
        "src": SESSION / "31.jpg",
        "canvas": (2240, 840),
    },
}


def install(src: Path, canvas: tuple[int, int]) -> Image.Image:
    im = flatten_interior_alpha(trim(key_black(Image.open(src))), floor=24)
    fitted = scale_fit(im, (canvas[0], canvas[1] - 6))
    dest = Image.new("RGBA", canvas, (0, 0, 0, 0))
    x = (canvas[0] - fitted.width) // 2
    dest.alpha_composite(fitted, (x, canvas[1] - fitted.height - 2))
    rgb = dest.convert("RGB").filter(ImageFilter.SMOOTH)
    return flatten_interior_alpha(
        Image.merge("RGBA", (*rgb.split(), dest.split()[-1])), floor=24
    )


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, job in JOBS.items():
        im = install(job["src"], job["canvas"])
        assert im.size == job["canvas"], (name, im.size)
        (OUT / name).parent.mkdir(parents=True, exist_ok=True)
        im.save(OUT / name, "PNG", compress_level=4)
        im.save(PROPS / name, "PNG", compress_level=4)
        print(f"wrote {name} {im.size}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

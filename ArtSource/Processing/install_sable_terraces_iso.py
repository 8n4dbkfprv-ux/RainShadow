#!/usr/bin/env python3
"""Install the isometric Sable terrace gens onto authored canvases.

The flat front-elevations read as cardboard on the BG:EE street. These masters
are complete iso blocks (roof deck, two walls, chimneys). We trim, key, scale
uniformly, bottom-align, and fill leftover width with the shipped iso cubes so
the south face still spans the WardBlock.

    python3 ArtSource/Processing/install_sable_terraces_iso.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_city_grounds_world_scale_v05 import flatten_interior_alpha
from generate_sable_terraces_v01 import TERRACES

ROOT = Path(__file__).resolve().parents[2]
PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/CityDistrict/V2"
OUT = ROOT / "ArtSource/Generated/CityDistrict/V2/Terraces"
SESSION = Path(
    "/Users/laurensvanoorschot/.grok/sessions/"
    "%2FUsers%2Flaurensvanoorschot%2FRainShadow/01a006e5-c905-7fc2-876c-6898424b5f92/images"
)

# 2.00 px/unit. World 1120×420 matches one surveyed lot's inscribed size
# (6.0 adults tall). Uniform scale 0.5.
CANVAS = {
    "sw": (2240, 840),
    "se": (2240, 840),
    "nw": (2240, 840),
    "ne": (2240, 840),
}

MASTERS = {
    "sw": SESSION / "34.jpg",  # iso tenement+shop volume (replaces front-elevation 28.jpg)
    "se": SESSION / "27.jpg",
    "nw": SESSION / "25.jpg",
    "ne": SESSION / "26.jpg",
}

FILLERS = {
    "sw": ["city_building_tenement.png", "city_building_shop.png"],
    "se": ["city_building_tenement.png", "city_building_voss_stoop.png"],
    "nw": ["city_building_storefront.png"],
    "ne": ["city_building_rowhouse.png"],
}


def key_black(im: Image.Image, lum: float = 18.0) -> Image.Image:
    rgba = np.array(im.convert("RGBA"), dtype=np.float32)
    L = rgba[:, :, :3].mean(2)
    rgba[:, :, 3] = np.where(L < lum, 0, 255)
    rgba[:, :, :3] = np.where(rgba[:, :, 3:4] < 8, 0, rgba[:, :, :3])
    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")


def trim(im: Image.Image, pad: int = 2) -> Image.Image:
    a = np.array(im.split()[-1])
    ys, xs = np.where(a > 28)
    if len(xs) == 0:
        return im
    return im.crop((
        max(0, int(xs.min()) - pad),
        max(0, int(ys.min()) - pad),
        min(im.width, int(xs.max()) + 1 + pad),
        min(im.height, int(ys.max()) + 1 + pad),
    ))


def scale_fit(im: Image.Image, box: tuple[int, int]) -> Image.Image:
    """Uniform scale to fit inside box (no aspect shear)."""
    bw, bh = box
    scale = min(bw / im.width, bh / im.height)
    nw = max(1, int(round(im.width * scale)))
    nh = max(1, int(round(im.height * scale)))
    return im.resize((nw, nh), Image.Resampling.LANCZOS)


def load_cube(name: str, target_h: int) -> Image.Image:
    im = key_black(Image.open(PROPS / name), lum=16)
    im = flatten_interior_alpha(trim(im), floor=24)
    return scale_fit(im, (int(target_h * 1.15), target_h))


def stamp(dest: Image.Image, src: Image.Image, x: int, foot: int) -> None:
    dest.alpha_composite(src, (int(x), int(foot - src.height)))


def fill_sides(dest: Image.Image, left: int, right: int, fillers: list[str], foot: int) -> None:
    if right - left < 80 or not fillers:
        return
    cubes = [load_cube(n, int(dest.height * 0.78)) for n in fillers]
    x = left
    i = 0
    while x < right - 40:
        cube = cubes[i % len(cubes)]
        stamp(dest, cube, x - cube.width // 5, foot)  # overlap the iso left wall
        x += int(cube.width * 0.62)
        i += 1


def compose(face: str) -> Image.Image:
    cw, ch = CANVAS[face]
    dest = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    src_path = MASTERS[face]
    wide = SESSION / "28.jpg"
    if face == "sw" and wide.exists():
        src_path = wide
    master = flatten_interior_alpha(trim(key_black(Image.open(src_path))), floor=24)
    fitted = scale_fit(master, (cw, ch - 8))
    x = (cw - fitted.width) // 2
    foot = ch - 4
    stamp(dest, fitted, x, foot)
    rgb = dest.convert("RGB").filter(ImageFilter.SMOOTH)
    dest = Image.merge("RGBA", (*rgb.split(), dest.split()[-1]))
    return flatten_interior_alpha(dest, floor=24)


def measure_openings(im: Image.Image) -> list[dict]:
    arr = np.array(im)
    lum = arr[:, :, :3].mean(2)
    alpha = arr[:, :, 3]
    hole = (alpha < 20) | ((lum < 22) & (alpha < 80))
    H, W = hole.shape
    y0, y1 = int(H * 0.35), int(H * 0.98)
    col = hole[y0:y1].mean(0)
    holey = col > 0.28
    out = []
    start = None
    for i, v in enumerate(holey):
        if v and start is None:
            start = i
        if (not v or i == W - 1) and start is not None:
            end = i if not v else i + 1
            if end - start >= 36:
                sl = hole[y0:y1, start:end]
                rows = np.where(sl.mean(1) > 0.35)[0]
                if len(rows) and rows[-1] - rows[0] >= 70:
                    yy0, yy1 = y0 + int(rows[0]), y0 + int(rows[-1])
                    # Prefer the lintel (first solid row above) as top.
                    out.append({
                        "cx": (start + end) // 2,
                        "ty": yy1,
                        "w": end - start,
                        "h": yy1 - yy0,
                    })
            start = None
    return out


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    report = {}
    for face, spec in TERRACES.items():
        im = compose(face)
        assert im.size == CANVAS[face], (face, im.size, CANVAS[face])
        holes = measure_openings(im)
        report[face] = {"size": list(im.size), "openings": holes}
        gen = OUT / spec["name"]
        runtime = PROPS / spec["name"]
        im.save(gen, "PNG", compress_level=4)
        im.save(runtime, "PNG", compress_level=4)
        print(f"wrote {spec['name']} {im.size}  openings={len(holes)}")
        for h in holes:
            print(f"    cx={h['cx']} ty={h['ty']} {h['w']}x{h['h']}")
    (OUT / "iso_openings.json").write_text(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Composite painted street-wall bays into Sable Row's four terrace canvases.

Bays are the image_edit elevations (tenement, shop, stoop, storefront, gatehouse,
rowhouse). They are keyed, bottom-aligned, and placed so each registered door
hole lands on a painted opening; then `punch_holes` cuts the exact
`CityDistrictLayout` apertures.

    python3 ArtSource/Processing/composite_sable_terraces.py
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_city_grounds_world_scale_v05 import flatten_interior_alpha
from generate_sable_terraces_v01 import HOLES, TERRACES, punch_holes


def key_black(im: Image.Image, lum: float = 16.0) -> Image.Image:
    rgba = np.array(im.convert("RGBA"), dtype=np.float32)
    L = rgba[:, :, :3].mean(2)
    g, r, b = rgba[:, :, 1], rgba[:, :, 0], rgba[:, :, 2]
    green_dot = (g > r + 30) & (g > b + 30) & (g > 40) & (g < 90)
    rgba[:, :, 3] = np.where((L < lum) | green_dot, 0, 255)
    rgba[:, :, :3] = np.where(rgba[:, :, 3:4] < 8, 0, rgba[:, :, :3])
    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")

ROOT = Path(__file__).resolve().parents[2]
PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/CityDistrict/V2"
OUT = ROOT / "ArtSource/Generated/CityDistrict/V2/Terraces"
SESSION = Path(
    "/Users/laurensvanoorschot/.grok/sessions/"
    "%2FUsers%2Flaurensvanoorschot%2FRainShadow/01a006e5-c905-7fc2-876c-6898424b5f92/images"
)

BAYS = {
    "tenement": SESSION / "16.jpg",
    "tenement_blank": SESSION / "22.jpg",
    "shop": SESSION / "18.jpg",
    "storefront": SESSION / "20.jpg",
    "rowhouse": SESSION / "23.jpg",
    "gatehouse": SESSION / "17.jpg",
    "voss": SESSION / "21.jpg",
}

WALL_FOOT = 718
TARGET_H = 680


def load_bay(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    # JPEGs have no alpha; key the generator black field.
    if path.suffix.lower() in {".jpg", ".jpeg"}:
        im = key_black(im, lum=18)
    else:
        im = key_black(im, lum=16)
    return im


def trim(im: Image.Image, pad: int = 2) -> Image.Image:
    a = np.array(im.split()[-1])
    ys, xs = np.where(a > 28)
    if len(xs) == 0:
        return im
    x0 = max(0, int(xs.min()) - pad)
    y0 = max(0, int(ys.min()) - pad)
    x1 = min(im.width, int(xs.max()) + 1 + pad)
    y1 = min(im.height, int(ys.max()) + 1 + pad)
    return im.crop((x0, y0, x1, y1))


def largest_opening_cx(im: Image.Image) -> int | None:
    """Horizontal centre of the largest dark opening in the lower half."""
    arr = np.array(im.convert("RGBA"))
    lum = arr[:, :, :3].mean(2)
    a = arr[:, :, 3]
    dark = (lum < 28) & (a > 20)
    h, w = dark.shape
    band = dark[int(h * 0.45) : int(h * 0.95), :]
    if not band.any():
        return None
    col = band.mean(0)
    holey = col > 0.45
    best = None
    start = None
    for i, v in enumerate(holey):
        if v and start is None:
            start = i
        if not v and start is not None:
            if best is None or (i - start) > (best[1] - best[0]):
                best = (start, i)
            start = None
    if start is not None and (best is None or (len(holey) - start) > (best[1] - best[0])):
        best = (start, len(holey))
    if best is None or best[1] - best[0] < 20:
        return None
    return (best[0] + best[1]) // 2


def stamp_opening_at(dest: Image.Image, src: Image.Image, target_cx: int, foot_y: int) -> None:
    cx = largest_opening_cx(src)
    if cx is None:
        stamp(dest, src, target_cx - src.width // 2, foot_y)
        return
    stamp(dest, src, target_cx - cx, foot_y)


def scale_to_height(im: Image.Image, height: int) -> Image.Image:
    if im.height == height:
        return im
    scale = height / im.height
    nw = max(1, int(round(im.width * scale)))
    return im.resize((nw, height), Image.Resampling.LANCZOS)


def scale_xy(im: Image.Image, width: int, height: int) -> Image.Image:
    return im.resize((width, height), Image.Resampling.LANCZOS)


def stamp(dest: Image.Image, src: Image.Image, x: int, foot_y: int) -> None:
    """Bottom-align `src` so its last opaque row sits on foot_y."""
    y = foot_y - src.height
    dest.alpha_composite(src, (int(x), int(y)))


def paint_frame(dest: Image.Image, hole: dict, wide: bool = False) -> None:
    arr = np.array(dest)
    cx, ty, hw, hh = hole["cx"], hole["ty"], hole["w"], hole["h"]
    x0, y0 = cx - hw // 2, ty - hh
    pad = 16 if wide else 11
    stone = (82, 78, 72, 255)
    dark = (34, 32, 28, 255)
    arr[max(0, y0 - 14) : y0, max(0, x0 - pad) : x0 + hw + pad] = stone
    arr[y0 : ty + 2, max(0, x0 - pad) : x0] = stone
    arr[y0 : ty + 2, x0 + hw : x0 + hw + pad] = stone
    arr[ty : min(arr.shape[0], ty + 5), max(0, x0 - pad) : x0 + hw + pad] = dark
    dest.paste(Image.fromarray(arr))


def paint_stoop(dest: Image.Image, hole: dict, steps: int = 3) -> None:
    arr = np.array(dest)
    cx, ty, w = hole["cx"], hole["ty"], hole["w"]
    stone = (88, 82, 72, 255)
    dark = (46, 42, 36, 255)
    for i in range(steps):
        hw = w // 2 + 10 + i * 7
        y0 = ty + i * 10
        y1 = min(arr.shape[0], y0 + 9)
        arr[y0:y1, max(0, cx - hw) : cx + hw] = stone if i % 2 == 0 else dark
        arr[y1 - 2 : y1, max(0, cx - hw) : cx + hw] = (30, 28, 24, 255)
    dest.paste(Image.fromarray(arr))


def fill_span(dest: Image.Image, bay: Image.Image, x0: int, x1: int, foot: int, overlap: int = 28) -> None:
    x = x0
    flip = False
    while x < x1 - 8:
        tile = bay.transpose(Image.FLIP_LEFT_RIGHT) if flip else bay
        # Clip if the tile would run well past x1.
        if x + tile.width > x1 + overlap:
            crop_w = max(32, x1 + overlap - x)
            tile = tile.crop((0, 0, min(tile.width, crop_w), tile.height))
        stamp(dest, tile, x, foot)
        x += max(16, tile.width - overlap)
        flip = not flip


def compose_sw() -> Image.Image:
    w, h = TERRACES["sw"]["size"]
    dest = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    tenement = scale_to_height(trim(load_bay(BAYS["tenement"])), TARGET_H)
    blank = scale_to_height(trim(load_bay(BAYS["tenement_blank"])), TARGET_H)
    shop = scale_to_height(trim(load_bay(BAYS["shop"])), TARGET_H)

    # Filler tenement wall, then the door bay centered on the tenement hole.
    fill_span(dest, blank, 40, 1780, WALL_FOOT)
    stamp_opening_at(dest, tenement, 720, WALL_FOOT)

    fill_span(dest, shop, 1760, w - 40, WALL_FOOT, overlap=40)
    stamp_opening_at(dest, shop, 2160, WALL_FOOT)
    return dest


def compose_se() -> Image.Image:
    w, h = TERRACES["se"]["size"]
    dest = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gate = scale_to_height(trim(load_bay(BAYS["gatehouse"])), 520)
    voss = trim(load_bay(BAYS["voss"]))
    # Widen the stoop+garage bay so both openings sit on the SE face.
    voss = scale_xy(voss, 1180, TARGET_H)
    blank = scale_to_height(trim(load_bay(BAYS["tenement_blank"])), TARGET_H)

    stamp_opening_at(dest, gate, 560, WALL_FOOT)
    # Bridge the gatehouse to the stoop so the south face is one terrace.
    fill_span(dest, blank, 700, 1720, WALL_FOOT, overlap=48)
    stamp(dest, voss, 1620, WALL_FOOT)
    return dest


def compose_nw() -> Image.Image:
    w, h = TERRACES["nw"]["size"]
    dest = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    store = scale_to_height(trim(load_bay(BAYS["storefront"])), 640)
    shop = scale_to_height(trim(load_bay(BAYS["shop"])), 640)
    fill_span(dest, store, 30, w - 30, WALL_FOOT, overlap=36)
    # Alternate a shop bay so the row is not one clone.
    stamp(dest, shop, 480, WALL_FOOT)
    stamp_opening_at(dest, store, 1879, WALL_FOOT)
    stamp(dest, shop, 2200, WALL_FOOT)
    return dest


def compose_ne() -> Image.Image:
    w, h = TERRACES["ne"]["size"]
    dest = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    row = scale_to_height(trim(load_bay(BAYS["rowhouse"])), TARGET_H)
    fill_span(dest, row, 16, w - 16, WALL_FOOT, overlap=48)
    # Centre a bay so its painted door sits on the registered rowhouse hole.
    stamp_opening_at(dest, row, 1071, WALL_FOOT)
    return dest


COMPOSERS = {
    "sw": compose_sw,
    "se": compose_se,
    "nw": compose_nw,
    "ne": compose_ne,
}


def finish(face: str, im: Image.Image) -> Image.Image:
    # Soften JPEG block edges slightly before punching.
    rgb = im.convert("RGB").filter(ImageFilter.SMOOTH)
    im = Image.merge("RGBA", (*rgb.split(), im.split()[-1]))
    # Do not stamp CAD frames over the painted lintels — the bays already
    # carry stone surrounds. Only add a stoop when the hole sits on a blank wall.
    if face == "sw":
        paint_stoop(im, HOLES[face][0], steps=3)
    im = punch_holes(im, HOLES[face])
    return flatten_interior_alpha(im, floor=24)


def write_terraces() -> list[Path]:
    OUT.mkdir(parents=True, exist_ok=True)
    written = []
    for face, spec in TERRACES.items():
        im = finish(face, COMPOSERS[face]())
        assert im.size == spec["size"], (face, im.size, spec["size"])
        gen = OUT / spec["name"]
        runtime = PROPS / spec["name"]
        im.save(gen, "PNG", compress_level=4)
        im.save(runtime, "PNG", compress_level=4)
        print(f"wrote {spec['name']} {im.size}")
        written.append(runtime)
    return written


def main() -> int:
    write_terraces()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

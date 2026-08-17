#!/usr/bin/env python3
"""Install courtyard fills onto Sable lot crops without touching locked paint.

Each hero lot is two terraces with a vacant diamond interior. Imagine fills
are composited *only* into that interior. Original opaque pixels — Voss's
stoop, Harbor Street kerb, door holes, chimneys — are copied through
byte-for-byte. New paint is clipped to the lot diamond so it cannot spill
onto the street.

    python3 ArtSource/Processing/install_sable_courtyard_fills.py
"""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

try:
    from scipy import ndimage
    from scipy.spatial import ConvexHull
except ImportError:
    sys.exit("scipy is required")

sys.path.insert(0, str(Path(__file__).resolve().parent))

ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "ArtSource/Generated/CityDistrict/V2/SableRow"
PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/CityDistrict/V2"
AREAS = ROOT / "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2"
MAPS = ROOT / "RainShadow Shared/Resources/Art/UI/Map"
ORIG = GEN / "lots_v01"
FILL_DIR = GEN / "CourtyardFill"

PX = 2.0
WORLD_H = 2304.0
PLATE_W, PLATE_H = 8192, 4608
MAP_SIZE = (1847, 1040)
HALF_W, HALF_H = 584.0, 438.0
PERIOD, ROW_STEP = 840.0, 630.0
OPAQUE = 40
EDIT_LUMA = 22

# Session Imagine edits. Keys are lot suffixes.
FILLS = {
    "harborVoss": ROOT / "images/16.jpg",
    "harborWest": ROOT / "images/15.jpg",
    "upperWest": ROOT / "images/11.jpg",
    "upperEast": ROOT / "images/13.jpg",
    "southWest": ROOT / "images/12.jpg",
    "southEast": ROOT / "images/14.jpg",
}

# Resolve session-relative paths if the copies live under CourtyardFill instead.
SESSION_IMAGES = Path(
    "/Users/laurensvanoorschot/.grok/sessions/"
    "%2FUsers%2Flaurensvanoorschot%2FRainShadow/"
    "01a00a59-62cb-7180-b70f-62227c6a37e1/images"
)
SESSION_MAP = {
    "harborVoss": SESSION_IMAGES / "20.jpg",
    "harborWest": SESSION_IMAGES / "19.jpg",
    "upperWest": SESSION_IMAGES / "11.jpg",
    "upperEast": SESSION_IMAGES / "18.jpg",
    "southWest": SESSION_IMAGES / "12.jpg",
    "southEast": SESSION_IMAGES / "17.jpg",
}


def block_centre(i: int, j: int) -> tuple[float, float]:
    return PERIOD * (i - j), 1674.0 - ROW_STEP * (i + j)


def write_png(path: Path, image: Image.Image, *, rgb: bool = False, compress: int = 4) -> None:
    if path.exists() or path.is_symlink():
        path.unlink()
    payload = image.convert("RGB") if rgb else image
    payload.save(path, "PNG", compress_level=compress)


def convex_hull_mask(opaque: np.ndarray, pad: int = 8) -> np.ndarray:
    ys, xs = np.where(opaque)
    if len(xs) < 8:
        return opaque
    step = max(1, len(xs) // 4000)
    pts = np.stack([xs[::step], ys[::step]], axis=1)
    if len(pts) < 3:
        return opaque
    hull = ConvexHull(pts)
    # Rasterise hull via PIL polygon.
    poly = [(int(pts[v, 0]), int(pts[v, 1])) for v in hull.vertices]
    im = Image.new("L", (opaque.shape[1], opaque.shape[0]), 0)
    from PIL import ImageDraw
    ImageDraw.Draw(im).polygon(poly, fill=255)
    if pad:
        im = im.filter(ImageFilter.MaxFilter(pad * 2 + 1))
    return np.array(im) > 0


def diamond_mask(shape: tuple[int, int], lot: dict) -> np.ndarray:
    h, w = shape
    box = lot["cropPx"]
    i, j = lot["i"], lot["j"]
    cx, cy = block_centre(i, j)
    yy, xx = np.mgrid[0:h, 0:w]
    plate_x = box["x"] + xx
    plate_y = box["y"] + yy
    wx = plate_x / PX
    wy = WORLD_H - plate_y / PX
    return (np.abs(wx - cx) / HALF_W + np.abs(wy - cy) / HALF_H) <= 1.02


def resolve_fill(name: str) -> Path:
    for candidate in (SESSION_MAP[name], FILL_DIR / f"city_sable_lot_{name}_fill.jpg", FILLS.get(name)):
        if candidate is not None and candidate.exists():
            return candidate
    raise FileNotFoundError(name)


def install_one(name: str, lot: dict) -> dict:
    orig_path = ORIG / f"city_sable_lot_{name}.png"
    orig = np.array(Image.open(orig_path).convert("RGBA"))
    edit_im = Image.open(resolve_fill(name)).convert("RGB")
    if edit_im.size != (orig.shape[1], orig.shape[0]):
        edit_im = edit_im.resize((orig.shape[1], orig.shape[0]), Image.Resampling.LANCZOS)
    edit = np.array(edit_im)

    locked = orig[:, :, 3] > OPAQUE
    edit_paint = edit.max(axis=2) > EDIT_LUMA
    hull = convex_hull_mask(locked, pad=12)
    diamond = diamond_mask(locked.shape, lot)
    fill = (~locked) & edit_paint & hull & diamond

    out = orig.copy()
    out[fill, :3] = edit[fill]
    out[fill, 3] = 255

    dest_name = f"city_sable_lot_{name}.png"
    Image.fromarray(out).save(GEN / dest_name, "PNG", compress_level=4)
    Image.fromarray(out).save(PROPS / dest_name, "PNG", compress_level=4)

    # Hold grades: locked pixels must be identical; stoop band on harborVoss.
    hold = float(np.mean(np.abs(
        out[:, :, :3][locked].astype(np.int16) - orig[:, :, :3][locked].astype(np.int16)
    )))
    hole_before = ((~locked).mean())
    hole_after = ((out[:, :, 3] <= OPAQUE).mean())
    filled_px = int(fill.sum())
    print(
        f"  {name:12} filled={filled_px:7d}  "
        f"empty {hole_before*100:5.1f}% → {hole_after*100:5.1f}%  "
        f"lockΔ={hold:.3f}"
    )
    return {
        "name": name,
        "filledPx": filled_px,
        "emptyBefore": hole_before,
        "emptyAfter": hole_after,
        "lockDelta": hold,
    }


def rebuild_flatten(bake: dict) -> None:
    streets = Image.open(AREAS / f"{bake['streetsTexture']}.png").convert("RGBA").resize(
        (PLATE_W, PLATE_H), Image.Resampling.LANCZOS
    )
    area = streets.copy()
    for lot in bake["lots"]:
        crop = Image.open(PROPS / f"{lot['textureName']}.png").convert("RGBA")
        box = lot["cropPx"]
        if crop.size != (box["w"], box["h"]):
            crop = crop.resize((box["w"], box["h"]), Image.Resampling.LANCZOS)
        area.alpha_composite(crop, (box["x"], box["y"]))
    write_png(GEN / f"{bake['areaTexture']}.png", area)
    write_png(AREAS / "city_sable_row_block_v02.png", area, rgb=True)
    write_png(GEN / "city_sable_row_block_v02.png", area, rgb=True)
    write_png(
        MAPS / "map_city_sable_row_v02.png",
        area.resize(MAP_SIZE, Image.Resampling.LANCZOS),
        rgb=True,
        compress=4,
    )
    print(f"  rebuilt flatten {PLATE_W}x{PLATE_H}")


def main() -> int:
    bake = json.loads((GEN / "sable_area_bake.json").read_text())
    lots = {lot["textureName"].removeprefix("city_sable_lot_"): lot for lot in bake["lots"]}
    FILL_DIR.mkdir(parents=True, exist_ok=True)
    grades = []
    for name in ("harborWest", "harborVoss", "upperWest", "upperEast", "southWest", "southEast"):
        src = resolve_fill(name)
        shutil.copy2(src, FILL_DIR / f"city_sable_lot_{name}_fill.jpg")
        grades.append(install_one(name, lots[name]))
    rebuild_flatten(bake)
    failed = [g for g in grades if g["lockDelta"] > 0.01]
    if failed:
        print("LOCK FAILED", ", ".join(g["name"] for g in failed))
        return 1
    voss = next(g for g in grades if g["name"] == "harborVoss")
    if voss["emptyAfter"] >= voss["emptyBefore"] - 0.02:
        print("harborVoss courtyard did not fill")
        return 1
    print("LOCK HOLDS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

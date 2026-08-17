#!/usr/bin/env python3
"""Fill Sable hero-lot interiors with one BG:EE roof deck.

The Imagine courtyard pass put 3/4 sheds in the diamond. A continuous
Infinity Engine block's interior is roof, on the same ±0.75 axes as the
ground. This starts from the v01 lot crops (street facades locked), fills
the original courtyard with slate sampled from that lot, and rebuilds the
area flatten. Door holes stay empty.

    python3 ArtSource/Processing/fill_sable_lot_roofs.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage
from scipy.spatial import ConvexHull

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ie_projection as ie

ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "ArtSource/Generated/CityDistrict/V2/SableRow"
PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/CityDistrict/V2"
AREAS = ROOT / "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2"
MAPS = ROOT / "RainShadow Shared/Resources/Art/UI/Map"
ORIG = GEN / "lots_v01"

PX = 2.0
WORLD_H = 2304.0
PLATE_W, PLATE_H = 8192, 4608
MAP_SIZE = (1847, 1040)
HALF_W, HALF_H = 584.0, 438.0
PERIOD, ROW_STEP = 840.0, 630.0
OPAQUE = 40
SLOPE = ie.BGEE.ground_slope
SLATE_CELL = 26.0
JOINT = 0.11
HEROES = (
    "harborWest", "harborVoss", "upperWest", "upperEast", "southWest", "southEast"
)
STRIPS = (
    "skylineWest", "skylineEast",
    "edge_0_0", "edge_1_1", "edge_2_-3", "edge_3_-2",
)


def block_centre(i: int, j: int) -> tuple[float, float]:
    return PERIOD * (i - j), 1674.0 - ROW_STEP * (i + j)


def write_png(path: Path, image: Image.Image, *, rgb: bool = False, compress: int = 4) -> None:
    if path.exists() or path.is_symlink():
        path.unlink()
    payload = image.convert("RGB") if rgb else image
    payload.save(path, "PNG", compress_level=compress)


def convex_hull_mask(opaque: np.ndarray, pad: int = 10) -> np.ndarray:
    ys, xs = np.where(opaque)
    if len(xs) < 8:
        return opaque
    step = max(1, len(xs) // 4000)
    pts = np.stack([xs[::step], ys[::step]], axis=1)
    hull = ConvexHull(pts)
    poly = [(int(pts[v, 0]), int(pts[v, 1])) for v in hull.vertices]
    im = Image.new("L", (opaque.shape[1], opaque.shape[0]), 0)
    from PIL import ImageDraw
    ImageDraw.Draw(im).polygon(poly, fill=255)
    if pad:
        im = im.filter(ImageFilter.MaxFilter(pad * 2 + 1))
    return np.array(im) > 0


def diamond_fields(shape: tuple[int, int], lot: dict):
    h, w = shape
    box = lot["cropPx"]
    i, j = lot["i"], lot["j"]
    cx, cy = block_centre(i, j)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    plate_x = box["x"] + xx
    plate_y = box["y"] + yy
    wx = plate_x / PX
    wy = WORLD_H - plate_y / PX
    metric = np.abs(wx - cx) / HALF_W + np.abs(wy - cy) / HALF_H
    return plate_x, plate_y, metric


def split_blobs(opaque: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Near street wall (higher y) and far rank (lower y)."""
    lab, n = ndimage.label(opaque)
    if n == 0:
        return opaque, np.zeros_like(opaque)
    sizes = [(lab == i).sum() for i in range(1, n + 1)]
    order = np.argsort(sizes)[::-1] + 1
    blobs = []
    for i in order[:2]:
        m = lab == i
        ys, _ = np.where(m)
        blobs.append((ys.mean(), m))
    blobs.sort(key=lambda t: t[0])
    far = blobs[0][1]
    near = blobs[-1][1] if len(blobs) > 1 else np.zeros_like(opaque)
    return near, far


def far_roof_mask(orig: np.ndarray, far: np.ndarray) -> np.ndarray:
    """Keep only the far rank's roof crown; the south face goes under the deck."""
    if not far.any():
        return far
    ys, _ = np.where(far)
    cut = ys.min() + 0.28 * (ys.max() - ys.min())
    return far & (np.arange(far.shape[0])[:, None] <= cut)


def fill_mask(orig: np.ndarray, diamond: np.ndarray) -> np.ndarray:
    """Courtyard plus the far rank's camera-facing wall — one roof volume."""
    opaque = orig[:, :, 3] > OPAQUE
    near, far = split_blobs(opaque)
    far_roof = far_roof_mask(orig, far)
    hull = convex_hull_mask(opaque, pad=16)
    keep = near | far_roof
    cand = (~keep) & hull & diamond
    lab, n = ndimage.label(cand)
    if n == 0:
        return cand
    sizes = ndimage.sum(cand, lab, index=np.arange(1, n + 1))
    keep_ids = (sizes >= max(3000, 0.12 * sizes.max())).nonzero()[0] + 1
    out = np.isin(lab, keep_ids)
    out = ndimage.binary_dilation(out, iterations=2) & (~near) & (~far_roof) & diamond
    return out


def sample_slate(orig: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Slate from the actual roof decks of the two terraces, not wall brick."""
    rgb = orig[:, :, :3].astype(np.float32)
    opaque = orig[:, :, 3] > OPAQUE
    near, far = split_blobs(opaque)
    roof = np.zeros_like(opaque)
    for blob in (near, far):
        if not blob.any():
            continue
        ys, _ = np.where(blob)
        cut = ys.min() + 0.45 * (ys.max() - ys.min())
        top = blob & (np.arange(blob.shape[0])[:, None] <= cut)
        luma = rgb.max(axis=2)
        cool = rgb[:, :, 2] + 8 >= rgb[:, :, 0]
        roof |= top & cool & (luma > 32) & (luma < 125)
    if roof.sum() < 200:
        roof = opaque & (rgb.max(axis=2) < 120)
    return rgb, roof


def roof_patch(orig: np.ndarray) -> np.ndarray:
    """Clean hip-slate from the SE terrace — camera and material lock."""
    se = Image.open(PROPS / "city_terrace_sable_se.png").convert("RGB")
    # Tight crop of laid slate, no chimneys, no tar deck, no brick.
    return np.array(se.crop((960, 125, 1180, 228)), dtype=np.float32)


def paint_deck(orig: np.ndarray, lot: dict, mask: np.ndarray) -> np.ndarray:
    h, w = mask.shape
    plate_x, plate_y, metric = diamond_fields((h, w), lot)
    u = 0.5 * (plate_x + plate_y / SLOPE)
    v = 0.5 * (-plate_x + plate_y / SLOPE)
    patch = roof_patch(orig)
    ph, pw = patch.shape[:2]
    # Index the painted roof along the same ±0.75 axes so joints hold the camera.
    sx = np.mod(u.astype(np.int32), pw)
    sy = np.mod((v * 0.75).astype(np.int32), ph)
    # The SE hip is already on the BG:EE camera. Stamp it in screen space
    # so the tile slope stays; u/v remapping sheared it into herringbone.
    yy, xx = np.mgrid[0:h, 0:w]
    row = yy // ph
    sx = np.mod(xx + row * 53, pw)
    sy = np.mod(yy, ph)
    sampled = patch[sy, sx]
    sx2 = np.mod(xx + row * 53 + pw // 2, pw)
    sy2 = np.mod(yy + ph // 2, ph)
    sampled2 = patch[sy2, sx2]
    vary = np.mod(np.sin((u / 40.0) * 127.1 + (v / 40.0) * 311.7) * 43758.5453, 1.0)
    sampled = sampled * (1.0 - vary * 0.45)[..., None] + sampled2 * (vary * 0.45)[..., None]
    sampled = sampled * (0.92 + 0.12 * vary[..., None])

    iu = np.floor(u / SLATE_CELL)
    vv = v / SLATE_CELL + 0.5 * np.mod(iu, 2.0)
    iv = np.floor(vv)
    fu = u / SLATE_CELL - iu
    fv = vv - iv
    dist = np.minimum(np.minimum(fu, 1.0 - fu), np.minimum(fv, 1.0 - fv))
    joint = np.clip(1.0 - dist / JOINT, 0.0, 1.0) ** 2
    shade = 1.0 - joint * 0.22
    parapet = np.clip((metric - 0.90) / 0.10, 0.0, 1.0)
    shade = shade * (1.0 - 0.14 * parapet)
    painted = np.clip(sampled * shade[..., None], 0, 255)

    out = orig.copy()
    ys, xs = np.where(mask)
    out[ys, xs, :3] = painted[ys, xs]
    out[ys, xs, 3] = 255
    # Soften the deck so it reads as paint, not a CAD lattice.
    deck = Image.fromarray(out).filter(ImageFilter.GaussianBlur(radius=0.55))
    blurred = np.array(deck)
    out[mask] = blurred[mask]
    return out


def rebuild_flatten(bake: dict) -> None:
    streets = Image.open(AREAS / f"{bake['streetsTexture']}.png").convert("RGBA")
    if streets.size != (PLATE_W, PLATE_H):
        streets = streets.resize((PLATE_W, PLATE_H), Image.Resampling.LANCZOS)
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


def main() -> int:
    bake = json.loads((GEN / "sable_area_bake.json").read_text())
    lots = {lot["textureName"].removeprefix("city_sable_lot_"): lot for lot in bake["lots"]}
    for name in HEROES:
        orig = np.array(Image.open(ORIG / f"city_sable_lot_{name}.png").convert("RGBA"))
        lot = lots[name]
        _, _, metric = diamond_fields(orig.shape[:2], lot)
        diamond = metric <= 1.02
        mask = fill_mask(orig, diamond)
        out = paint_deck(orig, lot, mask)
        near, far = split_blobs(orig[:, :, 3] > OPAQUE)
        locked = near | far_roof_mask(orig, far)
        hold = float(np.mean(np.abs(
            out[:, :, :3][locked].astype(np.int16) - orig[:, :, :3][locked].astype(np.int16)
        )))
        dest = f"city_sable_lot_{name}.png"
        Image.fromarray(out).save(GEN / dest, "PNG", compress_level=4)
        Image.fromarray(out).save(PROPS / dest, "PNG", compress_level=4)
        print(
            f"  {name:12} deck={int(mask.sum()):7d}  "
            f"empty {((orig[:,:,3]<=OPAQUE).mean())*100:5.1f}% → "
            f"{((out[:,:,3]<=OPAQUE).mean())*100:5.1f}%  lockΔ={hold:.3f}"
        )
        if hold > 0.01:
            print("LOCK FAILED", name)
            return 1
    rebuild_flatten(bake)
    print("LOCK HOLDS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

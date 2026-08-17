#!/usr/bin/env python3
"""Stamp a painted stoop and door at every runtime leaf on a lot master.

The generator holds the camera but keeps putting doorways on the facade. The
runtime probes the pavement. This keeps the on-lock terrace and paints a
usable opaque doorway at each `city_layout.json` anchor, on the BG:EE axes.

    python3 ArtSource/Processing/stamp_sable_lot_doors.py \
        --lot harborWest \
        --src LotMasters/harborWest_master.png \
        --dest LotMasters/harborWest_master.png
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from composite_city_ground_density_v04 import axis_uv, stone_detail
from fill_sable_lot_roofs import GEN
from generate_city_grounds_world_scale_v05 import flatten_interior_alpha
from install_sable_lot_masters import (
    LOT_FRONTAGE_UNITS,
    PX,
    door_anchors,
    frontage_units,
    key_background,
    load_master,
    paste_origin,
)
from install_sable_unified_blocks import opaque_bbox
from pack_sable_lot_masters import CANVAS
import ie_projection as ie

ADULT_WU = 200.0 / 512.0 * 180.0
DOOR_BODY_MULTIPLE = 1.15
DOOR_WIDTH_WU = 42.0
WOOD = (48, 32, 26, 255)
WOOD_HI = (62, 42, 34, 255)
STONE = (118, 108, 96, 255)
STONE_DK = (78, 72, 66, 255)
COBBLE = (86, 82, 78, 255)


def _sample_brick(arr: np.ndarray, x: int, y: int) -> tuple[int, int, int]:
    h, w = arr.shape[:2]
    x0, x1 = max(0, x - 40), min(w, x + 40)
    y0, y1 = max(0, y - 80), min(h, y)
    patch = arr[y0:y1, x0:x1]
    opaque = patch[:, :, 3] > 40
    if not opaque.any():
        return (78, 52, 44)
    return tuple(int(v) for v in patch[:, :, :3][opaque].mean(0))


def stamp_one(im: Image.Image, mx: float, my: float, scale_m: float) -> Image.Image:
    """Paint an opaque stoop + recessed wood door at master pixel (mx, my)."""
    arr = np.array(im.convert("RGBA"))
    brick = _sample_brick(arr, int(mx), int(my))
    d = ImageDraw.Draw(im, "RGBA")
    half_w = DOOR_WIDTH_WU * scale_m / 2.0
    door_h = ADULT_WU * DOOR_BODY_MULTIPLE * ie.BGEE.height_foreshorten * scale_m
    pw = half_w * 1.55
    pd = pw * ie.BGEE.ground_slope
    ax, ay = mx, my

    # Stoop diamond on ±0.75, then two treads. Opaque stone so key_background
    # cannot eat a dark void connected to the canvas border.
    stoop = [
        (ax, ay + pd), (ax + pw, ay), (ax, ay - pd * 0.35), (ax - pw, ay),
    ]
    d.polygon(stoop, fill=COBBLE)
    for i in range(1, 3):
        t = i / 3.0
        y = ay + pd * (1.0 - t) * 0.55
        xw = pw * (1.0 - 0.35 * t)
        d.line([(ax - xw, y), (ax + xw, y)], fill=STONE, width=3)

    # Short brick bay so a far leaf is attached architecture, not a slab.
    bay_h = door_h * 0.55
    d.polygon(
        [(ax - half_w * 1.15, ay - pd * 0.2), (ax + half_w * 1.15, ay - pd * 0.2),
         (ax + half_w * 1.15, ay - pd * 0.2 - bay_h), (ax - half_w * 1.15, ay - pd * 0.2 - bay_h)],
        fill=(*brick, 255),
    )

    # Recessed wood door + stone frame. Luma stays above the key floor.
    x0, x1 = ax - half_w, ax + half_w
    y1, y0 = ay - pd * 0.15, ay - pd * 0.15 - door_h
    d.rectangle([x0 - 4, y0 - 6, x1 + 4, y1 + 2], fill=STONE)
    d.rectangle([x0, y0, x1, y1], fill=WOOD)
    d.line([(x0 + 6, y0 + 8), (x0 + 6, y1 - 8)], fill=WOOD_HI, width=2)
    d.ellipse([x1 - 14, (y0 + y1) / 2 - 3, x1 - 8, (y0 + y1) / 2 + 3], fill=(160, 130, 70, 255))
    d.line([(x0 - 4, y0 - 6), (x1 + 4, y0 - 6)], fill=STONE_DK, width=4)
    return im


def restamp_cobble(im: Image.Image) -> Image.Image:
    """Lay ±0.75 cobble grain on the newly painted stoop stones only."""
    arr = np.array(im.convert("RGBA")).astype(np.float32)
    rgb, a = arr[:, :, :3], arr[:, :, 3]
    h, w = a.shape
    u, v = axis_uv(h, w)
    cobble = stone_detail(u, v, 11.0)
    grey = np.abs(rgb[:, :, 0] - rgb[:, :, 2]) < 28
    luma = rgb.mean(2)
    stoop = (a > 40) & grey & (luma > 60) & (luma < 140)
    if stoop.any():
        rgb = rgb + (cobble * 10.0)[..., None] * stoop[..., None]
        arr[:, :, :3] = np.clip(rgb, 0, 255)
    return Image.fromarray(arr.astype(np.uint8))


def apply(src: Path, dest: Path, name: str) -> dict:
    bake = json.loads((GEN / "sable_area_bake.json").read_text())
    lots = {lot["textureName"].removeprefix("city_sable_lot_"): lot for lot in bake["lots"]}
    lot = lots[name]
    anchors = door_anchors(lot)
    master, _ = load_master(src)
    fr = frontage_units(name, lot)
    box = lot["cropPx"]
    x, y, scale, tw, th = paste_origin(
        lot, master.size, fr, (int(box["w"]), int(box["h"])),
        name=name, anchors=anchors,
    )
    scale_m = master.size[0] / fr
    im = master.convert("RGBA")
    stamped = 0
    for _tex, px, py, _m in anchors:
        mx = (px - x) / scale
        my = (py - y) / scale
        im = stamp_one(im, mx, my, scale_m)
        stamped += 1
    im = restamp_cobble(im)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    cx = (CANVAS - im.size[0]) // 2
    cy = CANVAS - 40 - im.size[1]
    canvas.paste(im, (cx, cy), im)
    dest.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dest, "PNG", compress_level=4)
    return {"stamped": stamped, "master": im.size, "dest": dest}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--lot", required=True)
    ap.add_argument("--src", type=Path, required=True)
    ap.add_argument("--dest", type=Path, required=True)
    args = ap.parse_args()
    info = apply(args.src, args.dest, args.lot)
    print(f"{args.lot} stamped {info['stamped']} doors  master {info['master'][0]}×{info['master'][1]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

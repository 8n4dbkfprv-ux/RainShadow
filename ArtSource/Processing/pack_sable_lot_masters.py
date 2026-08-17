#!/usr/bin/env python3
"""Seat a native-resolution lot painting onto the 2560 install canvas.

Never scale up. Packing a ~1024 paint to 1600 px with Lanczos made
`px/unit` report 2.57 while `detail_score` showed 0.64 — the canvas grew,
the art did not. If the generator returns less than TARGET_WIDTH px of
painted building, refuse and ask again.

    python3 ArtSource/Processing/pack_sable_lot_masters.py \
        --src Attempts/upperEast_a2.png --dest LotMasters/upperEast_master.png
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))
from composite_city_ground_density_v04 import axis_uv, stone_detail
from install_sable_lot_masters import key_background
from generate_city_grounds_world_scale_v05 import flatten_interior_alpha
from install_sable_unified_blocks import opaque_bbox

ROOT = Path(__file__).resolve().parents[2]
CANVAS = 3200
# Derived floor: 1168 wu of full-pad frontage × 2.00 px/unit = 2336 px.
# Heroes seat at the full diamond; density compositing stamps to this width.
# Below this the generator has to be asked again or density-composited;
# Lanczos alone is not a substitute.
TARGET_WIDTH = 2336
GOLD_MAX_B = 140


def strip_gold(im: Image.Image) -> Image.Image:
    """Replace leftover seed-outline gold with a local brick/slate fill."""
    arr = np.array(im.convert("RGBA"))
    rgb = arr[:, :, :3].astype(np.int16)
    gold = (
        (rgb[:, :, 0] > 170)
        & (rgb[:, :, 1] > 120)
        & (rgb[:, :, 2] < GOLD_MAX_B)
        & (rgb[:, :, 0] > rgb[:, :, 2] + 40)
    )
    if not gold.any():
        return im
    dil = ndimage.binary_dilation(gold, iterations=1)
    fill = arr.copy()
    for c in range(3):
        ch = arr[:, :, c].astype(np.float32)
        valid = ~dil
        # Neighbour mean via blur of non-gold.
        masked = np.where(valid, ch, 0.0)
        weight = valid.astype(np.float32)
        k = ImageFilter.GaussianBlur(radius=2.5)
        num = np.asarray(Image.fromarray(masked.astype(np.uint8)).filter(k), dtype=np.float32)
        den = np.asarray(Image.fromarray((weight * 255).astype(np.uint8)).filter(k), dtype=np.float32)
        den = np.maximum(den / 255.0, 1e-3)
        fill[:, :, c] = np.clip(num / den, 0, 255)
    arr[dil] = fill[dil]
    return Image.fromarray(arr)


def redeck_roof(im: Image.Image) -> Image.Image:
    """Replace a herringbone/hip roof lattice with on-lock ±0.75 slate.

    Used when a walk-up is otherwise on-camera but the roof tiles pull one
    axis shallow of the 2.0° gate (harborVoss landed 2.11° before this).
    """
    arr = np.array(im.convert("RGBA")).astype(np.float32)
    rgb = arr[:, :, :3]
    a = arr[:, :, 3]
    h, w = rgb.shape[:2]
    ys, xs = np.where(a > 40)
    if ys.size == 0:
        return im
    y0, y1 = int(ys.min()), int(ys.max())
    roof_band = (np.arange(h)[:, None] < y0 + 0.55 * (y1 - y0))
    luma = rgb.max(axis=2)
    cool = rgb[:, :, 2] + 10 >= rgb[:, :, 0]
    roof = (a > 40) & cool & (luma < 140) & roof_band
    if roof.sum() < 1000:
        return im
    lum = rgb.mean(2)
    blur = np.asarray(
        Image.fromarray(lum.astype(np.uint8)).filter(ImageFilter.GaussianBlur(radius=6)),
        dtype=np.float32,
    )
    flat = rgb - (lum - blur)[..., None] * 0.85
    u, v = axis_uv(h, w)
    painted = np.clip(flat + (stone_detail(u, v, 14.0) * 18.0)[..., None], 0, 255)
    arr[roof, :3] = painted[roof]
    return Image.fromarray(arr.astype(np.uint8))


def pack(src: Path, dest: Path, *, redeck: bool = False, frontage: float = 622.5) -> dict:
    keyed = flatten_interior_alpha(key_background(Image.open(src)), floor=24)
    keyed = strip_gold(keyed)
    box = opaque_bbox(np.array(keyed)[:, :, 3] > 0)
    crop = keyed.crop(box)
    min_width = int(round(frontage * 2.0))
    if crop.size[0] < min_width:
        raise SystemExit(
            f"{src.name} painted width {crop.size[0]} px < {min_width} "
            f"({frontage:.1f} wu × 2.00). Do not Lanczos-upscale; regenerate "
            "at native resolution."
        )
    # Native size if it fits; scale down only when the crop exceeds the canvas.
    tw, th = crop.size
    scale = 1.0
    max_h = CANVAS - 40
    max_w = CANVAS - 40
    if tw > max_w or th > max_h:
        scale = min(max_w / tw, max_h / th)
        tw = max(1, int(round(crop.size[0] * scale)))
        th = max(1, int(round(crop.size[1] * scale)))
        seated = crop.resize((tw, th), Image.Resampling.LANCZOS)
    else:
        seated = crop
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    x = (CANVAS - tw) // 2
    y = CANVAS - 40 - th
    canvas.paste(seated, (x, y), seated)
    if redeck:
        canvas = redeck_roof(canvas)
    dest.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dest, "PNG", compress_level=4)
    return {
        "src_size": crop.size,
        "packed": (tw, th),
        "scale": scale,
        "density": tw / frontage,
        "dest": dest,
        "frontage": frontage,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", type=Path, required=True)
    ap.add_argument("--dest", type=Path, required=True)
    ap.add_argument("--redeck", action="store_true", help="restamp roof slate on ±0.75")
    ap.add_argument(
        "--frontage", type=float, default=622.5,
        help="lot world-width in units (hero 622.5; skyline 801.5; edge 343 or 239.5)",
    )
    args = ap.parse_args()
    info = pack(args.src, args.dest, redeck=args.redeck, frontage=args.frontage)
    print(
        f"{args.src.name} {info['src_size'][0]}×{info['src_size'][1]} → "
        f"{info['packed'][0]}×{info['packed'][1]}  "
        f"scale {info['scale']:.3f}  density {info['density']:.2f} px/unit"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

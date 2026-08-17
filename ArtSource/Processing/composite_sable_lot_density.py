#!/usr/bin/env python3
"""Paint native brick, slate and sills onto a 1024 lot master at install scale.

The Cursor generator caps at 1024×1024. A naked Lanczos to the 1245 px density
floor would pass `px/unit` by adding empty pixels — the same trap the city
grounds hit (1536 cap vs 4096 plate). `composite_city_ground_density_v04.py`
kept the macro and painted setts at the output pixel scale, guarded by
`assert_not_naked_upscale`. This is the architectural equivalent: keep the
painted terrace, restamp brick courses, slate and sills on the BG:EE axes.

    python3 ArtSource/Processing/composite_sable_lot_density.py \
        --src Attempts/OnLockV08/upperWest.png \
        --dest LotMasters/upperWest_master.png
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from composite_city_ground_density_v04 import axis_uv, stone_detail
from generate_city_grounds_world_scale_v05 import flatten_interior_alpha
from install_sable_lot_masters import (
    CAMERA_TOLERANCE_DEG,
    DETAIL_FLOOR,
    LOT_FRONTAGE_UNITS,
    detail_score,
    key_background,
)
from install_sable_unified_blocks import opaque_bbox
from pack_sable_lot_masters import CANVAS, strip_gold
import qa_plate_projection as proj

ROOT = Path(__file__).resolve().parents[2]
# 1280 px of painted frontage is 2.06 px/unit — clears the 1245 / 2.00 floor
# after a second key in load_master (upperWest shrank 1245 → 1244 on that).
STAMP_WIDTH = 1280
# Signed RGB added on a 0..255 plate. Strong enough to beat a naked upscale
# (mean-abs floor 1.0) without becoming a stripe pattern that outvotes the
# architecture — that is what the awnings did. Horizontal bed-joint / sill
# grids are omitted for the same reason: they vote 0 deg and pulled the
# area flatten to +11.98 / −38.78. Brick, slate and cobble stay on ±0.75.
SLATE_CELL = 14.0
BRICK_CELL = 10.0
COBBLE_CELL = 11.0
SLATE_AMT = 16.0
BRICK_AMT = 11.0
COBBLE_AMT = 13.0
SUPPRESS = 0.50
NAKED_FLOOR = 1.0


def _blur(lum: np.ndarray, radius: float) -> np.ndarray:
    im = Image.fromarray(np.clip(lum, 0, 255).astype(np.uint8), "L")
    return np.asarray(im.filter(ImageFilter.GaussianBlur(radius=radius)), dtype=np.float32)


def mean_abs_vs_upscale(native: Image.Image, plate: Image.Image) -> float:
    """How far `plate` sits from a naked Lanczos of `native` to `plate.size`."""
    up = native.convert("RGB").resize(plate.size, Image.Resampling.LANCZOS)
    a = np.asarray(plate.convert("RGB"), dtype=np.float32)
    b = np.asarray(up, dtype=np.float32)
    return float(np.abs(a - b).mean())


def segment(rgb: np.ndarray, alpha: np.ndarray) -> dict[str, np.ndarray]:
    """Roof / wall / ground / window masks. Windows are left on the master."""
    h, w = alpha.shape
    opaque = alpha > 40
    luma = rgb.mean(2)
    amber = (
        opaque
        & (rgb[:, :, 0] > 130)
        & (rgb[:, :, 0] > rgb[:, :, 2] + 25)
        & (luma > 70)
    )
    ys, xs = np.where(opaque)
    if ys.size == 0:
        z = np.zeros_like(opaque)
        return {"roof": z, "wall": z, "ground": z, "window": z, "opaque": opaque}
    y0, y1 = int(ys.min()), int(ys.max())
    span = max(1, y1 - y0)
    yy = np.arange(h)[:, None]
    roof_band = yy < y0 + 0.55 * span
    ground_band = yy > y0 + 0.72 * span
    cool = rgb[:, :, 2] + 10 >= rgb[:, :, 0]
    grey = np.abs(rgb[:, :, 0] - rgb[:, :, 2]) < 28
    roof = opaque & cool & (luma < 150) & roof_band & ~amber
    ground = opaque & ground_band & grey & ~amber
    wall = opaque & ~roof & ~ground & ~amber
    return {"roof": roof, "wall": wall, "ground": ground, "window": amber, "opaque": opaque}


def restamp(
    crop: Image.Image,
    stamp_width: int,
    *,
    suppress: float | None = None,
    amount_scale: float = 1.0,
) -> Image.Image:
    """Resize to stamp_width and paint brick / slate / cobble at that scale.

    Skyline lots upscale ~1.6× (1024 → 1623). Hero suppress 0.50 plus full
    overlay amounts erase the native architecture on that stretch and the
    leftover mush reads as the retired 26° camera. Keep the macro: zero
    suppress and a lighter overlay when the scale exceeds 1.4, still enough
    to beat `NAKED_FLOOR`.
    """
    scale = stamp_width / crop.size[0]
    if suppress is None:
        suppress = 0.0 if scale >= 1.4 else SUPPRESS
    if scale >= 1.4 and amount_scale == 1.0:
        amount_scale = 6.0 / BRICK_AMT
    tw = stamp_width
    th = max(1, int(round(crop.size[1] * scale)))
    base = np.array(crop.resize((tw, th), Image.Resampling.LANCZOS), dtype=np.float32)
    rgb, a = base[:, :, :3], base[:, :, 3]
    masks = segment(rgb, a)
    lum = rgb.mean(2)
    hf = lum - _blur(lum, 4.0)
    restamp_mask = (masks["roof"] | masks["wall"] | masks["ground"]).astype(np.float32)
    rgb = rgb - (hf * restamp_mask * suppress)[..., None]

    u, v = axis_uv(*a.shape)
    slate = stone_detail(u, v, SLATE_CELL)
    brick = stone_detail(u, v, BRICK_CELL)
    cobble = stone_detail(u, v, COBBLE_CELL)

    rgb = rgb + (slate * SLATE_AMT * amount_scale)[..., None] * masks["roof"][..., None]
    rgb = rgb + (brick * BRICK_AMT * amount_scale)[..., None] * masks["wall"][..., None]
    rgb = rgb + (cobble * COBBLE_AMT * amount_scale)[..., None] * masks["ground"][..., None]
    base[:, :, :3] = np.clip(rgb, 0, 255)
    return Image.fromarray(base.astype(np.uint8))


def composite(src: Path, dest: Path, *, frontage: float = 1168.0) -> dict:
    keyed = flatten_interior_alpha(key_background(Image.open(src)), floor=24)
    keyed = strip_gold(keyed)
    box = opaque_bbox(np.array(keyed)[:, :, 3] > 0)
    native = keyed.crop(box)
    # 20 px of keying margin so a second key in load_master cannot drop below
    # the 2.00 px/unit floor (upperWest shrank 1245 → 1244 on that).
    stamp_width = int(round(frontage * 2.0)) + 20
    stamped = restamp(native, stamp_width)
    delta = mean_abs_vs_upscale(native.convert("RGB"), stamped.convert("RGB"))
    if delta < NAKED_FLOOR:
        raise SystemExit(
            f"{src.name} overlay too weak ({delta:.3f} < {NAKED_FLOOR:.1f} "
            "mean-abs RGB) — would pass density as a super-resolution upscale"
        )
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    x = (CANVAS - stamped.size[0]) // 2
    y = CANVAS - 40 - stamped.size[1]
    canvas.paste(stamped, (x, y), stamped)
    dest.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dest, "PNG", compress_level=4)
    master, _ = (stamped, None)
    grade = proj.grade(dest)
    return {
        "src": src,
        "dest": dest,
        "native": native.size,
        "stamped": stamped.size,
        "delta": delta,
        "detail": detail_score(master),
        "px_per_unit": stamped.size[0] / frontage,
        "peak_pos": grade["peak_pos"],
        "peak_neg": grade["peak_neg"],
        "worst_delta": grade["worst_delta"],
        "cam_ok": grade["worst_delta"] <= CAMERA_TOLERANCE_DEG,
        "detail_ok": detail_score(master) >= DETAIL_FLOOR,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", type=Path, required=True)
    ap.add_argument("--dest", type=Path, required=True)
    ap.add_argument(
        "--frontage", type=float, default=1168.0,
        help="lot world-width in units (hero 1168 full pad; strips use crop worldSize.w)",
    )
    args = ap.parse_args()
    info = composite(args.src, args.dest, frontage=args.frontage)
    flags = []
    if not info["cam_ok"]:
        flags.append(f"OFF-LOCK {info['worst_delta']:.2f}deg")
    if not info["detail_ok"]:
        flags.append(f"detail {info['detail']:.2f}")
    tag = "OK" if not flags else "FAIL " + ", ".join(flags)
    print(
        f"{args.src.name} {info['native'][0]}×{info['native'][1]} → "
        f"{info['stamped'][0]}×{info['stamped'][1]}  "
        f"vs-upscale {info['delta']:.2f}  detail {info['detail']:.2f}  "
        f"px/unit {info['px_per_unit']:.2f}  "
        f"{info['peak_pos']:+.2f}/{info['peak_neg']:+.2f} "
        f"d={info['worst_delta']:.2f}  {tag}"
    )
    return 0 if not flags else 1


if __name__ == "__main__":
    raise SystemExit(main())

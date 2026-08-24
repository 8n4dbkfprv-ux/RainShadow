#!/usr/bin/env python3
"""Rebuild Act I city districts as Infinity Engine outdoor AREs (1950s Harborpoint).

World 4096×3072 (BG 4:3 outdoor proportion). Plate 8192×6144 at 2.00 px/unit.
Streets and block volumes are drawn on the BG:EE ±0.75 lock. Optional painted
lot masters (Image Generator, affine-corrected) seat into those diamonds.
Search / light / height maps are derived from the architecture mask with
corner-extent rejection (the sealed-office lesson).

Does not call process_city_districts_v02.main().

    python3 ArtSource/Processing/generate_city_ward_rebuild_v01.py
    python3 ArtSource/Processing/generate_city_ward_rebuild_v01.py sable_row --install
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ie_projection as ie
import qa_plate_projection as qa

ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / "ArtSource/Generated/CityDistrict/V2/WardRebuild"
ART = ROOT / "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2"
MAPS = ROOT / "RainShadow Shared/Resources/Art/UI/Map"
AREAS = ROOT / "RainShadow Shared/Resources/Areas"
MASTERS = STAGE / "masters"

WORLD_W, WORLD_H = 4096.0, 3072.0
PLATE_W, PLATE_H = 8192, 6144
PX = PLATE_W / WORLD_W
SLOPE = ie.BGEE.ground_slope
HEIGHT_F = ie.BGEE.height_foreshorten
HALF_W, HALF_H = 584.0, 438.0
PERIOD, ROW_STEP = 840.0, 630.0
CELL_W, CELL_H = 16.0, 12.0
SR_W, SR_H = 256, 256
CITY_TOLERANCE = 1.5
MAP_SIZE = (1847, 1040)
STOREY_PX = 420.0 * HEIGHT_F * PX

SR_OBSTACLE = 0
SR_STONE = 7
SR_ROOF = 13
SR_WATER_IMPASS = 12
SR_EXIT = 14

BLOCKS = [
    (1, 1), (2, 0), (3, -1),
    (1, 0), (2, -1), (3, -2),
    (0, 0), (1, -1), (2, -2),
    (0, -1), (1, -2), (2, -3),
    (-1, -1), (0, -2), (1, -3),
]
CROSSINGS = [
    (840.0, 414.0), (2520.0, 414.0),
    (1680.0, 1044.0), (3360.0, 1044.0),
    (840.0, 1674.0), (2520.0, 1674.0),
    (1680.0, 2304.0), (3360.0, 2304.0),
]

DISTRICTS = {
    "sable_row": dict(
        ground="city_sable_row_ground_v02.png",
        streets="city_sable_row_area_streets_v01.png",
        block="city_sable_row_block_v02.png",
        map="map_city_sable_row_v02.png",
        area="city_sable_row",
        brick=(118, 64, 52), brick_r=(86, 48, 42), roof=(58, 62, 70),
        road=(42, 44, 48), pave=(72, 70, 66),
        water=False, neon=True,
    ),
    "wharf_ladder": dict(
        ground="city_wharf_ladder_ground_v02.png",
        streets="city_wharf_ladder_ground_v02.png",
        block="city_wharf_ladder_block_v02.png",
        map="map_city_wharf_ladder_v02.png",
        area="city_wharf_ladder",
        brick=(92, 78, 62), brick_r=(70, 60, 48), roof=(54, 58, 62),
        road=(40, 42, 44), pave=(62, 58, 52),
        water=True, neon=False,
    ),
    "riverside": dict(
        ground="city_riverside_ground_v02.png",
        streets="city_riverside_ground_v02.png",
        block="city_riverside_block_v02.png",
        map="map_city_riverside_v02.png",
        area="city_riverside",
        brick=(96, 70, 58), brick_r=(74, 54, 46), roof=(50, 58, 66),
        road=(42, 46, 50), pave=(64, 66, 68),
        water=True, neon=False,
    ),
    "harborpoint_pd": dict(
        ground="city_harborpoint_pd_ground_v02.png",
        streets="city_harborpoint_pd_ground_v02.png",
        block="city_harborpoint_pd_block_v02.png",
        map="map_city_harborpoint_pd_v02.png",
        area="city_harborpoint_pd",
        brick=(130, 124, 112), brick_r=(104, 100, 90), roof=(72, 74, 78),
        road=(44, 44, 46), pave=(70, 70, 66),
        water=False, neon=False,
    ),
    "lila_street": dict(
        ground="city_lila_street_ground_v02.png",
        streets="city_lila_street_ground_v02.png",
        block="city_lila_street_block_v02.png",
        map="map_city_lila_street_v02.png",
        area="city_lila_street",
        brick=(124, 72, 68), brick_r=(96, 54, 52), roof=(62, 58, 64),
        road=(48, 42, 44), pave=(70, 60, 58),
        water=False, neon=True,
    ),
    "civic_records": dict(
        ground="city_civic_records_ground_v02.png",
        streets="city_civic_records_ground_v02.png",
        block="city_civic_records_block_v02.png",
        map="map_city_civic_records_v02.png",
        area="city_civic_records",
        brick=(140, 136, 128), brick_r=(112, 108, 102), roof=(78, 80, 84),
        road=(56, 56, 58), pave=(80, 78, 74),
        water=False, neon=False,
    ),
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def block_centre(i: int, j: int) -> tuple[float, float]:
    return PERIOD * (i - j), 1674.0 - ROW_STEP * (i + j)


def world_grids(h: int, w: int) -> tuple[np.ndarray, np.ndarray]:
    xs = np.linspace(0.0, WORLD_W, w, dtype=np.float32, endpoint=False)
    ys = np.linspace(WORLD_H, 0.0, h, dtype=np.float32, endpoint=False)
    return np.meshgrid(xs, ys)


def axis_uv(wx: np.ndarray, wy: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    return 0.5 * (wx + wy / SLOPE), 0.5 * (-wx + wy / SLOPE)


def iso_streets(u: np.ndarray, v: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    period = 1680.0
    half_road, walk, kerb = 168.0, 88.0, 7.0
    ku = np.abs(np.mod(u + period / 2.0, period) - period / 2.0)
    kv = np.abs(np.mod(v + period / 2.0, period) - period / 2.0)
    k = 28.0
    d_road = -k * np.log(
        np.exp(np.clip(-ku / k, -40, 40)) + np.exp(np.clip(-kv / k, -40, 40))
    )
    road = np.clip(1.0 - (d_road - half_road) / 4.0, 0.0, 1.0)
    pave = np.clip(1.0 - (d_road - (half_road + walk)) / 5.0, 0.0, 1.0)
    pave = np.clip(pave - road, 0.0, 1.0)
    lip = np.clip(1.0 - np.abs(d_road - half_road) / kerb, 0.0, 1.0)
    return road, pave, lip


def stone_detail(u: np.ndarray, v: np.ndarray, cell: float) -> np.ndarray:
    iu = np.floor(u / cell)
    vv = v / cell + 0.5 * np.mod(iu, 2.0)
    iv = np.floor(vv)
    fu, fv = u / cell - iu, vv - iv
    dist = np.minimum(np.minimum(fu, 1.0 - fu), np.minimum(fv, 1.0 - fv))
    hashed = np.mod(np.sin(iu * 127.1 + iv * 311.7) * 43758.5453, 1.0)
    joint = np.clip(1.0 - dist / 0.16, 0.0, 1.0) ** 2
    return (hashed - 0.5) * 0.45 - joint * 0.80


def diamond_mask(wx, wy, cx, cy, inset: float = 0.0) -> np.ndarray:
    hw = HALF_W - inset
    hh = HALF_H - inset * (HALF_H / HALF_W)
    return (np.abs(wx - cx) / hw + np.abs(wy - cy) / hh) <= 1.0


def paint_ground(spec: dict) -> np.ndarray:
    wx, wy = world_grids(PLATE_H, PLATE_W)
    u, v = axis_uv(wx, wy)
    road, pave, lip = iso_streets(u, v)
    water = np.zeros((PLATE_H, PLATE_W), dtype=np.float32)
    if spec["water"]:
        # Shoreline follows a +0.75 ground axis so it cannot steal the histogram.
        water = np.clip((180.0 - (wy - SLOPE * (wx - WORLD_W * 0.35))) / 140.0, 0.0, 1.0)
        road = road * (1.0 - water)
        pave = pave * (1.0 - water)
        lip = lip * (1.0 - water)
    road_c = np.array(spec["road"], dtype=np.float32)
    pave_c = np.array(spec["pave"], dtype=np.float32)
    water_c = np.array((14, 26, 36), dtype=np.float32)
    leftover = np.clip(1.0 - water - road - pave, 0.0, 1.0)
    mix = (
        road[..., None] * road_c
        + pave[..., None] * pave_c
        + leftover[..., None] * (0.55 * road_c + 0.45 * pave_c)
        + water[..., None] * water_c
    )
    sett = stone_detail(u, v, 9.6)
    flag = stone_detail(u, v, 40.0)
    detail = sett * (1.0 - pave * 0.6) + flag * pave
    # Night key. The painted lot masters are dark rain-slick paintings; an
    # unlit daylight-grey street next to them reads as a different game.
    # Darken the base first, then modulate with the sett/kerb detail at a
    # higher amplitude: the structure tensor weights edges by gradient
    # magnitude squared, and a uniformly darkened street loses its on-lock
    # vote to the lots' residual tilt (Harborpoint failed 2.22° that way).
    out = mix * np.array((0.42, 0.44, 0.50), dtype=np.float32) + np.array(
        (6.0, 7.0, 11.0), dtype=np.float32
    )
    out = out * (1.0 + detail[..., None] * 0.62) * (1.0 - 0.22 * lip[..., None])
    lamp = np.array((210, 150, 70) if spec["neon"] else (186, 154, 88), dtype=np.float32)
    for lx, ly in CROSSINGS:
        r2 = (wx - lx) ** 2 + ((wy - ly) / SLOPE) ** 2
        glow = np.exp(-r2 / (140.0 ** 2))
        out = out + lamp * (0.26 * glow[..., None])
    return np.clip(out, 0, 255)


def _family_affine(family_down: float, family_up: float) -> np.ndarray:
    """Vertical-preserving 2×2 that sends measured ground families to ±0.75.

    Same construction as office V20: (1, family_down) and (1, −family_up) map
    onto (1, 0.75) and (1, −0.75) with a common scale, so painted verticals
    stay vertical. A uniform Y-stretch cannot do that — it is what left the
    generator's ~26° prior 6–10° off lock.

    NOTE: `_warp_linear` applies this matrix in *pixel* coordinates (y down),
    so `family_down` is the pixel-space downhill slope — i.e. the family the
    grader reports as `peak_neg` (y-up convention). Symmetric families hide a
    wrong pairing because the shear term cancels; asymmetric ones shear the
    wrong way and scramble the whole frame.
    """
    source = np.array([[1.0, 1.0], [family_down, -family_up]], dtype=np.float64)
    target = np.array([[1.0, 1.0], [SLOPE, -SLOPE]], dtype=np.float64)
    return target @ np.linalg.inv(source)


def _warp_linear(image: Image.Image, linear: np.ndarray) -> Image.Image:
    src = np.asarray(image.convert("RGB"), dtype=np.float32)
    h, w = src.shape[:2]
    inv = np.linalg.inv(linear)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    cx, cy = (w - 1) * 0.5, (h - 1) * 0.5
    dx, dy = xx - cx, yy - cy
    u = inv[0, 0] * dx + inv[0, 1] * dy + cx
    v = inv[1, 0] * dx + inv[1, 1] * dy + cy
    u0 = np.floor(u).astype(np.int32)
    v0 = np.floor(v).astype(np.int32)
    fu = (u - u0).astype(np.float32)
    fv = (v - v0).astype(np.float32)
    valid = (u0 >= 0) & (u0 < w - 1) & (v0 >= 0) & (v0 < h - 1)
    u0c = np.clip(u0, 0, w - 2)
    v0c = np.clip(v0, 0, h - 2)
    p00, p01 = src[v0c, u0c], src[v0c, u0c + 1]
    p10, p11 = src[v0c + 1, u0c], src[v0c + 1, u0c + 1]
    fu3, fv3 = fu[..., None], fv[..., None]
    blend = (
        p00 * (1 - fu3) * (1 - fv3)
        + p01 * fu3 * (1 - fv3)
        + p10 * (1 - fu3) * fv3
        + p11 * fu3 * fv3
    )
    out = np.where(valid[..., None], blend, 0.0)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def _grade_image(image: Image.Image) -> dict:
    tmp = STAGE / "_grade_tmp.png"
    STAGE.mkdir(parents=True, exist_ok=True)
    image.save(tmp)
    return qa.grade(tmp)


def _warp_from_grade(image: Image.Image, grade: dict) -> Image.Image:
    pos = math.tan(math.radians(abs(grade["peak_pos"])))
    neg = math.tan(math.radians(abs(grade["peak_neg"])))
    # peak_neg (y-up) is the downhill family in pixel space — see _family_affine.
    return _warp_linear(image, _family_affine(max(neg, 1e-4), max(pos, 1e-4)))


def _seated_preview(image: Image.Image, spec: dict) -> Image.Image:
    """The master as it will actually land on the plate.

    Feathered seating fades out the camera-near ground — which is the
    jig-derived, most on-lock part of every master. Grading the full square
    therefore overstates how on-lock the seated content is; Harborpoint
    passed every per-lot gate and still flattened to Δ2.2°. Composite the
    seat alpha over a flat street tone (no gradients of its own) so the
    grade measures only the pixels that survive seating.
    """
    arr = np.asarray(image.convert("RGB"), dtype=np.float32)
    h, w = arr.shape[:2]
    alpha = _seat_alpha(w, h)[..., None]
    base = np.array(spec["road"], dtype=np.float32) * 0.45 + 8.0
    comp = arr * alpha + base * (1.0 - alpha)
    return Image.fromarray(np.clip(comp, 0, 255).astype(np.uint8))


def affine_correct(image: Image.Image, spec: dict) -> Image.Image:
    """Iterative vertical-preserving family warp, scored on the seated preview.

    The generator's ~26° prior often pollutes the histogram with roofs and
    water. Each round warps from the seated-preview, full-frame, or
    ground-band families and keeps whichever candidate lands the seated
    content closest to ±0.75; a warp that makes it worse is refused.
    """
    rgb = image.convert("RGB")

    def seated_delta(img: Image.Image) -> float:
        return _grade_image(_seated_preview(img, spec))["worst_delta"]

    best, best_delta = rgb, seated_delta(rgb)
    current = rgb
    for _ in range(4):
        if best_delta <= 0.35:
            break
        w, h = current.size
        grades = [
            _grade_image(_seated_preview(current, spec)),
            _grade_image(current),
            _grade_image(current.crop((0, int(h * 0.45), w, h))),
        ]
        candidates = [_warp_from_grade(current, g) for g in grades if g["worst_delta"] > 0.2]
        if not candidates:
            break
        scored = sorted((seated_delta(c), k, c) for k, c in enumerate(candidates))
        delta, _, cand = scored[0]
        if delta >= best_delta - 0.03:
            break
        best, best_delta, current = cand, delta, cand
    return best


_ANCHOR_STATS: tuple[np.ndarray, np.ndarray] | None = None


def _anchor_stats() -> tuple[np.ndarray, np.ndarray] | None:
    """Per-channel mean/std of one anchor lot; every master is graded to it.

    Each Image Generator take ships its own exposure and palette, so twelve
    of them on one plate read as twelve different games. Tie them all to the
    Sable Row diner (the hero lot the rest of the ward was art-directed from).
    """
    global _ANCHOR_STATS
    if _ANCHOR_STATS is None:
        anchor = MASTERS / "sable_row_lot_2_-1.png"
        if not anchor.exists():
            return None
        arr = np.asarray(Image.open(anchor).convert("RGB"), dtype=np.float32).reshape(-1, 3)
        _ANCHOR_STATS = (arr.mean(axis=0), arr.std(axis=0))
    return _ANCHOR_STATS


def harmonize(image: Image.Image, strength: float = 0.65) -> Image.Image:
    stats = _anchor_stats()
    if stats is None:
        return image.convert("RGB")
    target_mean, target_std = stats
    arr = np.asarray(image.convert("RGB"), dtype=np.float32)
    flat = arr.reshape(-1, 3)
    mean, std = flat.mean(axis=0), flat.std(axis=0)
    graded = (arr - mean) / np.maximum(std, 1e-3) * target_std + target_mean
    out = arr * (1.0 - strength) + graded * strength
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def _seat_alpha(nw: int, nh: int) -> np.ndarray:
    """Alpha that melts a seated lot into the shared street.

    The master paints its own pavement on the camera-near half of its
    diamond. Seating that opaquely puts a second, differently-lit pavement
    next to the plate's street — the visible-seam bug. Keep the building
    (everything above the diamond centre line) opaque and fade the near
    ground out toward the tip, plus edge feathers so the square never
    prints a hard border.
    """
    yy, xx = np.mgrid[0:nh, 0:nw].astype(np.float32)
    y_up = (nh - 1) - yy
    # Relative to the seat box so the profile is identical at native master
    # size (grading previews) and at seated plate size.
    hh = nh * (HALF_H * PX) / (HALF_H * PX * 2 + STOREY_PX * 0.7)
    t = np.clip(y_up / max(hh, 1.0), 0.0, 1.0)
    alpha = np.where(y_up >= hh, 1.0, t * t * (3.0 - 2.0 * t))
    fx = np.clip(np.minimum(xx, (nw - 1) - xx) / (0.10 * nw), 0.0, 1.0)
    ft = np.clip(yy / (0.06 * nh), 0.0, 1.0)
    fb = np.clip(y_up / (0.05 * nh), 0.0, 1.0)
    return np.clip(alpha * fx * ft * fb, 0.0, 1.0)


def seat_master(plate: Image.Image, master: Image.Image, i: int, j: int) -> None:
    cx, cy = block_centre(i, j)
    px, py = cx * PX, (WORLD_H - cy) * PX
    bw, bh = int(HALF_W * PX * 2), int(HALF_H * PX * 2 + STOREY_PX * 0.7)
    box = (int(px - bw / 2), int(py + HALF_H * PX - bh), int(px + bw / 2), int(py + HALF_H * PX))
    src = master.convert("RGBA")
    scale = min((box[2] - box[0]) / src.width, (box[3] - box[1]) / src.height)
    nw = max(1, int(round(src.width * scale)))
    nh = max(1, int(round(src.height * scale)))
    seated = src.resize((nw, nh), Image.Resampling.LANCZOS)
    rgba = np.asarray(seated, dtype=np.float32)
    rgba[..., 3] = rgba[..., 3] * _seat_alpha(nw, nh)
    seated = Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8))
    plate.alpha_composite(seated, (box[0] + (box[2] - box[0] - nw) // 2, box[3] - nh))


def draw_kerbs(plate: Image.Image) -> None:
    """Wet stone kerb ring on every block diamond, at exactly ±0.75.

    Visually it separates each lot's pavement from the street and hides the
    feathered seam. Structurally it restores the long on-lock edges the
    plate lost when painted lots stopped receiving graybox volumes — without
    them Harborpoint's stacked per-lot residuals dragged the negative family
    to −34.7° (Δ2.2°, FAIL).
    """
    d = ImageDraw.Draw(plate, "RGBA")

    def to_px(x: float, y: float) -> tuple[float, float]:
        return x * PX, (WORLD_H - y) * PX

    for i, j in BLOCKS:
        cx, cy = block_centre(i, j)
        for inset, colour, width in (
            (10.0, (13, 13, 16, 235), 7),
            (16.0, (92, 95, 105, 150), 3),
        ):
            hw = HALF_W - inset
            hh = hw * SLOPE
            # Near edges only: the far half of the diamond is occluded by
            # the building, and a line there would cut across the facade.
            ring = [
                to_px(cx - hw, cy),
                to_px(cx, cy - hh),
                to_px(cx + hw, cy),
            ]
            d.line(ring, fill=colour, width=width, joint="curve")


def draw_blocks(
    plate: Image.Image,
    mask: Image.Image,
    spec: dict,
    painted: set[tuple[int, int]] | None = None,
) -> None:
    painted = painted or set()
    d = ImageDraw.Draw(plate, "RGBA")
    m = ImageDraw.Draw(mask, "L")
    h = STOREY_PX * 0.72

    def to_px(x: float, y: float) -> tuple[float, float]:
        return x * PX, (WORLD_H - y) * PX

    def lift(pt: tuple[float, float], height: float) -> tuple[float, float]:
        return pt[0], pt[1] - height

    def night(colour: tuple[int, int, int]) -> tuple[int, int, int]:
        # Desaturate and crush the graybox volumes so unsurveyed background
        # blocks sit in the painted lots' night key instead of reading as
        # bright daylight brick at the plate edges.
        lum = 0.30 * colour[0] + 0.55 * colour[1] + 0.15 * colour[2]
        return tuple(int(0.45 * (0.55 * c + 0.45 * lum)) + 8 for c in colour)

    for idx, (i, j) in enumerate(BLOCKS):
        cx, cy = block_centre(i, j)
        near = to_px(cx, cy - HALF_H * 0.55)
        right = to_px(cx + HALF_W * 0.55, cy)
        far = to_px(cx, cy + HALF_H * 0.55)
        left = to_px(cx - HALF_W * 0.55, cy)
        if (i, j) not in painted:
            d.polygon([near, left, lift(left, h), lift(near, h)], fill=(*night(spec["brick"]), 255))
            d.polygon([near, right, lift(right, h), lift(near, h)], fill=(*night(spec["brick_r"]), 255))
            d.polygon(
                [lift(near, h), lift(right, h), lift(far, h), lift(left, h)],
                fill=(*night(spec["roof"]), 255),
            )
            glow = (210, 150, 70, 180) if spec["neon"] and idx % 3 == 0 else (30, 36, 46, 220)
            for t in (0.22, 0.45, 0.68):
                a = (near[0] + (left[0] - near[0]) * t, near[1] + (left[1] - near[1]) * t)
                p0 = lift(a, h * 0.25)
                p1 = lift((a[0] + 10, a[1] - 8), h * 0.55)
                d.polygon(
                    [(p0[0], p0[1]), (p1[0], p0[1]), (p1[0], p1[1]), (p0[0], p1[1])],
                    fill=glow,
                )
            d.polygon(
                [
                    (near[0] - 10, near[1] + 4),
                    (near[0] + 10, near[1] + 4),
                    lift((near[0] + 10, near[1] + 4), h * 0.28),
                    lift((near[0] - 10, near[1] + 4), h * 0.28),
                ],
                fill=(12, 10, 10, 255),
            )
        m.polygon([near, right, far, left, lift(left, h), lift(far, h), lift(right, h), lift(near, h)], fill=220)
        m.polygon([near, right, far, left], fill=180)


def bake_search(mask: Image.Image, spec: dict) -> Image.Image:
    mask_arr = np.asarray(mask, dtype=np.uint8)
    sr = np.full((SR_H, SR_W), SR_STONE, dtype=np.uint8)
    for row in range(SR_H):
        y0 = row * CELL_H
        for col in range(SR_W):
            x0 = col * CELL_W
            corners = (
                (x0, y0),
                (x0 + CELL_W - 1e-3, y0),
                (x0, y0 + CELL_H - 1e-3),
                (x0 + CELL_W - 1e-3, y0 + CELL_H - 1e-3),
            )
            blocked = roof = False
            for x, y in corners:
                px = int(np.clip(x / WORLD_W * PLATE_W, 0, PLATE_W - 1))
                py = int(np.clip((1.0 - y / WORLD_H) * PLATE_H, 0, PLATE_H - 1))
                value = int(mask_arr[py, px])
                roof = roof or value >= 200
                blocked = blocked or value >= 160
            dest_row = SR_H - 1 - row
            edge = col < 2 or row < 2 or col >= SR_W - 2 or row >= SR_H - 2
            if spec["water"] and y0 < 140:
                sr[dest_row, col] = SR_WATER_IMPASS
            elif edge:
                sr[dest_row, col] = SR_EXIT
            elif roof:
                sr[dest_row, col] = SR_ROOF
            elif blocked:
                sr[dest_row, col] = SR_OBSTACLE
    return Image.fromarray(sr, "L")


def bake_height(mask: Image.Image) -> Image.Image:
    small = np.asarray(mask.resize((SR_W, SR_H), Image.Resampling.BOX), dtype=np.float32)
    return Image.fromarray(np.clip(128.0 + (small / 255.0) * 40.0, 0, 255).astype(np.uint8), "L")


def bake_light(plate: Image.Image) -> Image.Image:
    night = ImageEnhance.Brightness(ImageEnhance.Color(plate).enhance(0.55)).enhance(0.38)
    small = night.resize((SR_W, SR_H), Image.Resampling.BOX).convert("RGB")
    arr = np.asarray(small).astype(np.int16)
    arr[..., 0] = arr[..., 0] * 0.28 + 18
    arr[..., 1] = arr[..., 1] * 0.32 + 24
    arr[..., 2] = arr[..., 2] * 0.42 + 40
    glow = np.zeros_like(arr)
    for lx, ly in CROSSINGS:
        cx, cy = lx / CELL_W, SR_H - ly / CELL_H
        yy, xx = np.mgrid[0:SR_H, 0:SR_W]
        falloff = np.exp(-((xx - cx) ** 2 + (yy - cy) ** 2) / (6.0 ** 2))
        glow[..., 0] += (70 * falloff).astype(np.int16)
        glow[..., 1] += (78 * falloff).astype(np.int16)
        glow[..., 2] += (42 * falloff).astype(np.int16)
    return Image.fromarray(np.clip(arr + glow, 0, 255).astype(np.uint8), "RGB")


def hud_map(plate: Image.Image) -> Image.Image:
    w, h = plate.size
    target = MAP_SIZE[0] / MAP_SIZE[1]
    if w / h > target:
        nw = int(round(h * target))
        crop = plate.crop(((w - nw) // 2, 0, (w + nw) // 2, h))
    else:
        nh = int(round(w / target))
        crop = plate.crop((0, (h - nh) // 2, w, (h + nh) // 2))
    return crop.resize(MAP_SIZE, Image.Resampling.LANCZOS)


def wall_polygons() -> list[dict]:
    polys = []
    for i, j in BLOCKS:
        cx, cy = block_centre(i, j)
        polys.append(
            {
                "coversActors": True,
                "height": 420,
                "id": f"block.{i}.{j}",
                "polygon": [
                    {"x": cx, "y": cy - HALF_H},
                    {"x": cx + HALF_W, "y": cy},
                    {"x": cx, "y": cy + HALF_H},
                    {"x": cx - HALF_W, "y": cy},
                ],
                "shadesBothSides": False,
            }
        )
    return polys


def patch_area_json(area_id: str) -> None:
    path = AREAS / f"{area_id}.area.json"
    document = json.loads(path.read_text())
    area = document["area"] if "area" in document else document
    area["worldSize"] = {"w": WORLD_W, "h": WORLD_H}
    area["wallPolygons"] = wall_polygons()
    ids = {item.get("id") for item in area.get("ambients", [])}
    if "amb.foghorn" not in ids:
        area.setdefault("ambients", []).append(
            {
                "assetName": "amb_rain_exterior",
                "id": "amb.foghorn",
                "interval": 28,
                "intervalDeviation": 10,
                "isLooping": False,
                "point": {"x": 840, "y": 414},
                "radius": 1200,
                "schedule": 15728703,
                "selection": "random",
                "sounds": ["amb_rain_exterior"],
                "volume": 0.08,
            }
        )
    document["area"] = area
    path.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n")


def install_copy(src: Path, dst: Path) -> None:
    """Copy that never writes through a hard link.

    Some installed plates were hard-linked across paths (block == ground on
    disk). `shutil.copy2` truncates and writes the shared inode, so copying
    block then streets left every linked path holding the streets-only
    content — buildings silently erased from the block plate. Unlink first
    so each destination gets its own inode.
    """
    dst = Path(dst)
    if dst.exists() or dst.is_symlink():
        dst.unlink()
    shutil.copy2(src, dst)


def build_district(slug: str, install: bool) -> dict:
    spec = DISTRICTS[slug]
    dest = STAGE / slug
    dest.mkdir(parents=True, exist_ok=True)
    ground = paint_ground(spec)
    plate = Image.fromarray(ground.astype(np.uint8)).convert("RGBA")
    mask = Image.new("L", (PLATE_W, PLATE_H), 0)

    # Grade first: a block only skips its graybox volume if a master will
    # actually seat there. With feathered seating the graybox would otherwise
    # ghost through the lot's faded near ground as a phantom wall.
    seated_lots: list[tuple[int, int, Image.Image]] = []
    for master_path in sorted(MASTERS.glob(f"{slug}_lot_*.png")):
        parts = master_path.stem.split("_")
        try:
            i, j = int(parts[-2]), int(parts[-1])
        except (ValueError, IndexError):
            continue
        corrected = affine_correct(Image.open(master_path).convert("RGB"), spec)
        tmp = dest / f"_grade_{i}_{j}.png"
        _seated_preview(corrected, spec).save(tmp)
        grade = qa.grade(tmp)
        if grade["worst_delta"] > CITY_TOLERANCE:
            print(f"  skip {master_path.name}: {grade['worst_delta']:.2f}° off lock")
            continue
        seated_lots.append((i, j, harmonize(corrected)))
        print(f"  seated {master_path.name}  Δ{grade['worst_delta']:.2f}°")

    draw_blocks(plate, mask, spec, painted={(i, j) for i, j, _ in seated_lots})
    for i, j, lot in seated_lots:
        seat_master(plate, lot, i, j)
    draw_kerbs(plate)

    rgb = plate.convert("RGB")
    wx, wy = world_grids(PLATE_H, PLATE_W)
    g_arr = ground.astype(np.uint8)
    s_arr = np.asarray(rgb).copy()
    for i, j in BLOCKS:
        cx, cy = block_centre(i, j)
        s_arr[diamond_mask(wx, wy, cx, cy, inset=40)] = g_arr[diamond_mask(wx, wy, cx, cy, inset=40)]
    streets = Image.fromarray(s_arr)

    flatten_path = dest / f"city_{slug}_ward_flatten_v01.png"
    streets_path = dest / f"city_{slug}_ward_streets_v01.png"
    rgb.save(flatten_path, compress_level=3)
    streets.save(streets_path, compress_level=3)
    mask.save(dest / f"city_{slug}_architecture_mask_v01.png")
    grade = qa.grade(flatten_path)
    metrics = {
        "slug": slug,
        "world": [WORLD_W, WORLD_H],
        "plate": [PLATE_W, PLATE_H],
        "pxPerUnit": PX,
        "projection": {
            "peak_pos": grade["peak_pos"],
            "peak_neg": grade["peak_neg"],
            "worst_delta": grade["worst_delta"],
            "passes": grade["worst_delta"] <= CITY_TOLERANCE,
        },
        "sha256": sha256(flatten_path),
    }
    (dest / "metrics.json").write_text(json.dumps(metrics, indent=2) + "\n")
    print(
        f"{slug}: axes {grade['peak_pos']:+.2f}/{grade['peak_neg']:+.2f}  "
        f"Δ{grade['worst_delta']:.2f}°  {'PASS' if metrics['projection']['passes'] else 'FAIL'}"
    )

    bake_search(mask, spec).save(dest / f"{spec['area']}.sr.png")
    bake_light(rgb).save(dest / f"{spec['area']}.lm.png")
    bake_height(mask).save(dest / f"{spec['area']}.ht.png")
    hud_map(rgb).save(dest / spec["map"])

    if install:
        ART.mkdir(parents=True, exist_ok=True)
        MAPS.mkdir(parents=True, exist_ok=True)
        install_copy(flatten_path, ART / spec["block"])
        install_copy(streets_path, ART / spec["streets"])
        install_copy(streets_path, ART / spec["ground"])
        install_copy(dest / spec["map"], MAPS / spec["map"])
        for suffix in (".sr.png", ".lm.png", ".ht.png"):
            install_copy(dest / f"{spec['area']}{suffix}", AREAS / f"{spec['area']}{suffix}")
        print(f"  installed {slug} (area JSON is exported from Swift)")
    return metrics


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("districts", nargs="*", default=list(DISTRICTS))
    ap.add_argument("--install", action="store_true")
    args = ap.parse_args()
    STAGE.mkdir(parents=True, exist_ok=True)
    MASTERS.mkdir(parents=True, exist_ok=True)
    failures = 0
    summary = []
    for slug in args.districts:
        if slug not in DISTRICTS:
            print(f"unknown district {slug}", file=sys.stderr)
            return 1
        metrics = build_district(slug, args.install)
        summary.append(metrics)
        if not metrics["projection"]["passes"]:
            failures += 1
    (STAGE / "rebuild_metrics.json").write_text(json.dumps(summary, indent=2) + "\n")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())

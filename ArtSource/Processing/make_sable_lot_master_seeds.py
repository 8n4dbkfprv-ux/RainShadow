#!/usr/bin/env python3
"""Build geometric lot-master seeds from Sable Row's on-lock ground plate.

A finished IE block: street terraces on both near kerbs, deeper wings, and an
enclosed courtyard (painted courtyard floor + far courtyard wall) so raw
ground_v02 does not read as an empty lot. Not a warehouse deck over the whole
diamond — that was the helipad failure.

    python3 ArtSource/Processing/make_sable_lot_master_seeds.py
    python3 ArtSource/Processing/qa_plate_projection.py \
        ArtSource/Generated/CityDistrict/V2/SableRow/LotMasters/GeomSeeds/*.png \
        --tolerance 2.0
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ie_projection as ie
from fill_sable_lot_roofs import (
    GEN,
    HALF_H,
    HALF_W,
    HEROES,
    STRIPS,
    PX,
    WORLD_H,
    block_centre,
    write_png,
)

ROOT = Path(__file__).resolve().parents[2]
GROUND = ROOT / "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2/city_sable_row_ground_v02.png"
OUT = GEN / "LotMasters" / "GeomSeeds"
JIG_DIR = GEN / "LotMasters" / "AreaJig"

# Full-pad diamond at 2.00 px/unit needs 2336 px of frontage. Canvas leaves
# margin for wall extrusion above the far tip.
SIZE = 3200
DIAMOND_W = 2336  # = 2 * HALF_W * 2.00
MARGIN_BOTTOM = 80
# Three-storey terrace, same 6-adult world height as TerraceSpec (420 wu).
STOREY_WU = 420.0
# How far the terrace steps into the lot. Deeper than V5's 0.30 so the wings
# enclose a courtyard instead of leaving an empty brown diamond.
WING_DEPTH = 0.55
# Far courtyard wall sits behind the wing returns (toward the far tip).
COURTYARD_DEPTH = 0.78
# How much of each near edge is frontage (leave the side tips for the paving).
FRONTAGE = 0.90
BAYS = 4
PITCH = 0.22  # extra roof rise as a fraction of wall height

# ---------------------------------------------------------------------------
# Generator pre-compensation
# ---------------------------------------------------------------------------
# Empirical and PER-GENERATOR. Imagine shallows ~2 deg; Cursor holds the jig.
# Default (no flag) is the on-lock seed. See city_sable_lot_masters_v05.md.
GENERATOR_SHALLOWING_DEG = 2.03

LAYOUT_DUMP = ROOT / "ArtSource/Generated/CityDistrict/V2/city_layout.json"
ADULT_WU = 200.0 / 512.0 * 180.0
DOOR_BODY_MULTIPLE = 1.15
DOOR_WIDTH_WU = 42.0


def lot_door_anchors(lot: dict) -> list[tuple[str, float, float]]:
    """Runtime door leaves whose ground point falls inside this lot's crop."""
    if not LAYOUT_DUMP.exists():
        return []
    dump = json.loads(LAYOUT_DUMP.read_text())
    district = next((d for d in dump["districts"] if d["slug"] == "sable_row"), None)
    if district is None:
        return []
    box = lot["cropPx"]
    out = []
    for sprite in district["sprites"]:
        if not sprite["textureName"].startswith("city_door_"):
            continue
        g = sprite["groundPoint"]
        px = g["x"] * PX - box["x"]
        py = (WORLD_H - g["y"]) * PX - box["y"]
        if 0 <= px < box["w"] and 0 <= py < box["h"]:
            out.append((sprite["textureName"].removeprefix("city_door_"), g["x"], g["y"]))
    return out


def hero_world_to_seed(geom: dict, lot: dict, wx: float, wy: float) -> tuple[float, float]:
    """World point to hero-jig canvas pixel, inverse of `paint_paving`'s sampling."""
    cx_w, cy_w = lot_world_centre(lot)
    return (
        geom["cx"] + (wx - cx_w) * geom["scale"],
        geom["near_y"] - (wy - (cy_w - HALF_H)) * geom["scale_y"],
    )


def paint_door_stoops(canvas: np.ndarray, geom: dict, lot: dict) -> np.ndarray:
    """Stamp a stoop and a dark opening at every runtime door anchor."""
    anchors = lot_door_anchors(lot)
    if not anchors:
        return canvas
    im = Image.fromarray(canvas)
    d = ImageDraw.Draw(im, "RGBA")
    scale = geom["scale"]
    door_h = ADULT_WU * DOOR_BODY_MULTIPLE * ie.BGEE.height_foreshorten * scale
    half_w = DOOR_WIDTH_WU * scale / 2.0
    tread = max(6.0, 10.0 * scale / 1.4555)
    cx_w, cy_w = lot_world_centre(lot)
    for _name, wx, wy in anchors:
        ax, ay = hero_world_to_seed(geom, lot, wx, wy)
        metric = abs(wx - cx_w) / HALF_W + abs(wy - cy_w) / HALF_H
        if metric > 1.06:
            edge_wy = cy_w - HALF_H + abs(wx - cx_w) * (HALF_H / HALF_W)
            ex, ey = hero_world_to_seed(geom, lot, wx, edge_wy)
            bay_h = door_h * 1.35
            d.polygon(
                [(ex - half_w * 1.3, ey), (ex + half_w * 1.3, ey),
                 (ax + half_w * 1.3, ay), (ax - half_w * 1.3, ay)],
                fill=(70, 48, 42, 255),
            )
            d.polygon(
                [(ax - half_w * 1.3, ay), (ax + half_w * 1.3, ay),
                 (ax + half_w * 1.3, ay - bay_h), (ax - half_w * 1.3, ay - bay_h)],
                fill=(74, 50, 44, 255), outline=(228, 196, 120, 255),
            )
        pw, pd = half_w * 1.6, half_w * 1.6 * ie.BGEE.ground_slope
        d.polygon(
            [(ax, ay + pd), (ax + pw, ay), (ax, ay - pd), (ax - pw, ay)],
            fill=(96, 92, 88, 255), outline=(150, 140, 120, 255),
        )
        for i in range(1, 3):
            t = i / 3.0
            d.line(
                [(ax - pw * (1 - t), ay + pd * t), (ax + pw * (1 - t), ay + pd * t)],
                fill=(140, 132, 118, 255), width=2,
            )
        d.polygon(
            [(ax - half_w, ay), (ax + half_w, ay),
             (ax + half_w, ay - door_h), (ax - half_w, ay - door_h)],
            fill=(12, 10, 9, 255),
        )
        # Inner reveal + speckled gloom — breaks flatness without a door leaf.
        inset = max(2.0, half_w * 0.12)
        d.polygon(
            [(ax - half_w + inset, ay - 2), (ax + half_w - inset, ay - 2),
             (ax + half_w - inset, ay - door_h + inset),
             (ax - half_w + inset, ay - door_h + inset)],
            fill=(22, 16, 14, 255),
        )
        for k in range(18):
            t = (k + 0.5) / 18.0
            px = ax - half_w + inset + (2 * half_w - 2 * inset) * t
            for j in range(5):
                py = ay - door_h * (0.15 + 0.7 * (j / 4.0))
                shade = 8 + (k * 3 + j * 5) % 18
                d.point((px, py), fill=(shade, max(0, shade - 2), max(0, shade - 3), 255))
        d.line([(ax - half_w, ay - door_h), (ax + half_w, ay - door_h)],
               fill=(228, 196, 120, 255), width=max(3, int(tread / 2)))
        for sx in (-half_w, half_w):
            d.line([(ax + sx, ay), (ax + sx, ay - door_h)],
                   fill=(228, 196, 120, 255), width=3)
    return np.array(im.convert("RGB"))


def lot_world_centre(lot: dict) -> tuple[float, float]:
    return block_centre(lot["i"], lot["j"])


def precompensation() -> float:
    """Vertical stretch that puts the jig `GENERATOR_SHALLOWING_DEG` steeper."""
    target = ie.BGEE.ground_axis_deg
    return math.tan(math.radians(target + GENERATOR_SHALLOWING_DEG)) / ie.BGEE.ground_slope


def seed_geometry(precomp: float = 1.0) -> dict:
    scale = DIAMOND_W / (2.0 * HALF_W)
    scale_y = scale * precomp
    diamond_h = 2.0 * HALF_H * scale_y
    cx = SIZE / 2.0
    near_y = SIZE - MARGIN_BOTTOM
    height = STOREY_WU * ie.BGEE.height_foreshorten * scale
    far_roof_y = near_y - diamond_h - height
    if far_roof_y < 24:
        height = near_y - diamond_h - 24
    return {
        "scale": scale,
        "scale_y": scale_y,
        "precomp": precomp,
        "diamond_h": diamond_h,
        "cx": cx,
        "near_y": near_y,
        "height": height,
        "gnear": (cx, near_y),
        "gleft": (cx - DIAMOND_W / 2.0, near_y - diamond_h / 2.0),
        "gfar": (cx, near_y - diamond_h),
        "gright": (cx + DIAMOND_W / 2.0, near_y - diamond_h / 2.0),
    }


def lift(pt: tuple[float, float], height: float) -> tuple[float, float]:
    return (pt[0], pt[1] - height)


def lerp(a: tuple[float, float], b: tuple[float, float], t: float) -> tuple[float, float]:
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def paint_paving(ground: np.ndarray, lot: dict, geom: dict) -> np.ndarray:
    """Sample the lot diamond off the ground plate onto the seed canvas."""
    gh, gw = ground.shape[:2]
    cx_w, cy_w = lot_world_centre(lot)
    scale = geom["scale"]
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    wx = cx_w + (xx - geom["cx"]) / scale
    wy = (cy_w - HALF_H) + (geom["near_y"] - yy) / geom["scale_y"]
    metric = np.abs(wx - cx_w) / HALF_W + np.abs(wy - cy_w) / HALF_H
    inside = metric <= 1.0
    px = np.rint(wx * PX).astype(np.int32)
    py = np.rint((WORLD_H - wy) * PX).astype(np.int32)
    valid = inside & (px >= 0) & (px < gw) & (py >= 0) & (py < gh)
    canvas = np.zeros((SIZE, SIZE, 3), dtype=np.uint8)
    sampled = ground[py[valid], px[valid]].astype(np.float32)
    luma = sampled.max(axis=1, keepdims=True)
    hi = float(np.percentile(luma, 98)) if luma.size else 1.0
    gain = 160.0 / max(hi, 12.0)
    canvas[valid] = np.clip(sampled * gain + 18.0, 0, 255).astype(np.uint8)
    return canvas


def paint_volume(
    canvas: np.ndarray, geom: dict, *, strong: bool, kind: str = "hero", anchored: bool = False
) -> np.ndarray:
    """Finished IE block: deep near terraces, enclosed courtyard, pitched lids."""
    im = Image.fromarray(canvas)
    d = ImageDraw.Draw(im, "RGBA")
    h = geom["height"]
    gnear, gleft, gfar, gright = geom["gnear"], geom["gleft"], geom["gfar"], geom["gright"]

    def inward(p: tuple[float, float], depth: float) -> tuple[float, float]:
        return lerp(p, gfar, depth)

    left_end = lerp(gnear, gleft, FRONTAGE)
    right_end = lerp(gnear, gright, FRONTAGE)
    inner_near = inward(gnear, WING_DEPTH)
    inner_left = inward(left_end, WING_DEPTH)
    inner_right = inward(right_end, WING_DEPTH)
    court_left = inward(left_end, COURTYARD_DEPTH)
    court_right = inward(right_end, COURTYARD_DEPTH)
    court_near = inward(gnear, COURTYARD_DEPTH)

    if kind == "skyline":
        brick_l = (62, 58, 66, 255)
        brick_r = (52, 50, 58, 255)
        brick_far = (48, 46, 54, 255)
        slate = (48, 54, 64, 255)
        slate_hi = (58, 64, 74, 255)
        court_floor = (72, 68, 64, 255)
    else:
        brick_l = (78, 52, 44, 255)
        brick_r = (62, 44, 40, 255)
        brick_far = (58, 40, 36, 255)
        slate = (52, 58, 66, 255)
        slate_hi = (64, 70, 78, 255)
        court_floor = (88, 78, 68, 255)
    course = (38, 28, 26, 255)
    door = (16, 14, 12, 255)
    edge = (228, 196, 120, 255)
    width = 5 if strong else 3
    pitch = h * PITCH
    court_h = h * 0.55

    def wall(a, b, fill, height: float = h) -> None:
        d.polygon([a, b, lift(b, height), lift(a, height)], fill=fill)

    def roof(street_a, street_b, back_a, back_b, height: float = h) -> None:
        eave_s = (lift(street_a, height), lift(street_b, height))
        eave_b = (lift(back_a, height), lift(back_b, height))
        ridge_a = lift(lerp(street_a, back_a, 0.5), height + pitch * (height / max(h, 1)))
        ridge_b = lift(lerp(street_b, back_b, 0.5), height + pitch * (height / max(h, 1)))
        d.polygon([eave_s[0], eave_s[1], ridge_b, ridge_a], fill=slate_hi)
        d.polygon([eave_b[0], eave_b[1], ridge_b, ridge_a], fill=slate)
        d.line([ridge_a, ridge_b], fill=(88, 94, 102, 255), width=4)
        for i in range(1, BAYS):
            t = i / BAYS
            c = lerp(ridge_a, ridge_b, t)
            cap = (c[0] - 7, c[1] - 28, c[0] + 7, c[1] - 4)
            d.rectangle(cap, fill=(72, 48, 42, 255), outline=edge)

    # Courtyard floor — painted stone, not empty ground_v02.
    d.polygon(
        [inner_near, inner_left, court_left, court_near, court_right, inner_right],
        fill=court_floor,
    )
    wall(court_left, court_right, brick_far, court_h)
    wall(inner_left, court_left, brick_l, court_h)
    wall(inner_right, court_right, brick_r, court_h)
    roof(
        inner_left, court_left,
        inward(left_end, (WING_DEPTH + COURTYARD_DEPTH) / 2),
        lerp(court_left, court_near, 0.35),
        court_h,
    )
    roof(
        inner_right, court_right,
        inward(right_end, (WING_DEPTH + COURTYARD_DEPTH) / 2),
        lerp(court_right, court_near, 0.35),
        court_h,
    )

    wall(gnear, left_end, brick_l)
    wall(gnear, right_end, brick_r)
    wall(left_end, inner_left, brick_l)
    wall(right_end, inner_right, brick_r)
    roof(gnear, left_end, inner_near, inner_left)
    roof(gnear, right_end, inner_near, inner_right)

    for i in range(1, BAYS):
        t = i / BAYS
        d.line([lerp(gnear, left_end, t), lerp(lift(gnear, h), lift(left_end, h), t)], fill=course, width=2)
        d.line([lerp(gnear, right_end, t), lerp(lift(gnear, h), lift(right_end, h), t)], fill=course, width=2)
    for t in (0.33, 0.66):
        d.line([lerp(gnear, lift(gnear, h), t), lerp(left_end, lift(left_end, h), t)], fill=course, width=2)
        d.line([lerp(gnear, lift(gnear, h), t), lerp(right_end, lift(right_end, h), t)], fill=course, width=2)

    # Window bays — native structure so density clears the 1.10 detail floor.
    win = (28, 22, 18, 255)
    glow = (160, 110, 55, 255)
    for street_a, street_b in ((gnear, left_end), (gnear, right_end)):
        for bay in range(BAYS):
            t0 = (bay + 0.22) / BAYS
            t1 = (bay + 0.42) / BAYS
            for storey, (s0, s1) in enumerate(((0.12, 0.28), (0.40, 0.56), (0.68, 0.84))):
                q0 = lerp(lerp(street_a, street_b, t0), lerp(lift(street_a, h), lift(street_b, h), t0), s0)
                q1 = lerp(lerp(street_a, street_b, t1), lerp(lift(street_a, h), lift(street_b, h), t1), s0)
                q2 = lerp(lerp(street_a, street_b, t1), lerp(lift(street_a, h), lift(street_b, h), t1), s1)
                q3 = lerp(lerp(street_a, street_b, t0), lerp(lift(street_a, h), lift(street_b, h), t0), s1)
                fill = glow if (bay + storey) % 3 == 0 and kind != "skyline" else win
                d.polygon([q0, q1, q2, q3], fill=fill)
                d.line([q0, q1, q2, q3, q0], fill=course, width=1)

    for street_a, street_b in ((gnear, left_end), (gnear, right_end)):
        if kind == "skyline" or anchored:
            break
        p0 = lerp(lerp(street_a, street_b, 0.28), lerp(lift(street_a, h), lift(street_b, h), 0.28), 0.04)
        p1 = lerp(lerp(street_a, street_b, 0.40), lerp(lift(street_a, h), lift(street_b, h), 0.40), 0.04)
        p2 = lerp(lerp(street_a, street_b, 0.40), lerp(lift(street_a, h), lift(street_b, h), 0.40), 0.30)
        p3 = lerp(lerp(street_a, street_b, 0.28), lerp(lift(street_a, h), lift(street_b, h), 0.28), 0.30)
        d.polygon([p0, p1, p2, p3], fill=door)

    for a, b in (
        (gnear, left_end), (gnear, right_end),
        (left_end, inner_left), (right_end, inner_right),
        (inner_left, court_left), (inner_right, court_right),
        (court_left, court_right),
        (gnear, lift(gnear, h)), (left_end, lift(left_end, h)), (right_end, lift(right_end, h)),
        (lift(gnear, h), lift(left_end, h)), (lift(gnear, h), lift(right_end, h)),
    ):
        d.line([a, b], fill=edge, width=width)
    return np.array(im.convert("RGB"))


def paint_edge_tip(canvas: np.ndarray, geom: dict, *, strong: bool) -> np.ndarray:
    """Single kerb facade for a plate-corner tip that cannot hold a courtyard."""
    im = Image.fromarray(canvas)
    d = ImageDraw.Draw(im, "RGBA")
    h = geom["height"] * 0.85
    gnear, gleft, gright = geom["gnear"], geom["gleft"], geom["gright"]
    # Prefer the near edge that still sits inside the clip (larger |x| from centre
    # of the seed tends to be the cut). Draw both short stubs; clip removes the rest.
    left_end = lerp(gnear, gleft, 0.55)
    right_end = lerp(gnear, gright, 0.55)
    brick = (70, 48, 42, 255)
    slate = (52, 58, 66, 255)
    edge = (228, 196, 120, 255)
    course = (38, 28, 26, 255)
    width = 5 if strong else 3

    def wall(a, b, fill) -> None:
        d.polygon([a, b, lift(b, h), lift(a, h)], fill=fill)

    wall(gnear, left_end, brick)
    wall(gnear, right_end, brick)
    # Flat lid — short tip, not a courtyard.
    d.polygon(
        [lift(gnear, h), lift(left_end, h), lift(right_end, h)],
        fill=slate,
    )
    for t in (0.33, 0.66):
        d.line([lerp(gnear, lift(gnear, h), t), lerp(left_end, lift(left_end, h), t)], fill=course, width=2)
        d.line([lerp(gnear, lift(gnear, h), t), lerp(right_end, lift(right_end, h), t)], fill=course, width=2)
    for a, b in (
        (gnear, left_end), (gnear, right_end),
        (gnear, lift(gnear, h)), (left_end, lift(left_end, h)), (right_end, lift(right_end, h)),
        (lift(gnear, h), lift(left_end, h)), (lift(gnear, h), lift(right_end, h)),
    ):
        d.line([a, b], fill=edge, width=width)
    # Ground-axis guides on the paving so the tensor has ±0.75 to read.
    for t in (0.2, 0.4, 0.6, 0.8):
        d.line([lerp(gnear, gleft, t), lerp(gnear, gright, t)], fill=(140, 130, 110, 180), width=2)
    return np.array(im.convert("RGB"))


def strip_place(lot: dict) -> dict:
    """Fit the lot's plate crop onto the seed canvas, bottom-centred."""
    box = lot["cropPx"]
    cw, ch = float(box["w"]), float(box["h"])
    margin = 80
    seed_scale = min((SIZE - 2 * margin) / cw, (SIZE - 2 * margin) / ch)
    sw, sh = cw * seed_scale, ch * seed_scale
    tx = (SIZE - sw) / 2.0
    ty = SIZE - margin - sh
    return {
        "seed_scale": seed_scale,
        "tx": tx,
        "ty": ty,
        "sw": sw,
        "sh": sh,
        "crop_x": float(box["x"]),
        "crop_y": float(box["y"]),
        "clip": (tx, ty, tx + sw, ty + sh),
    }


def world_to_seed(wx: float, wy: float, place: dict) -> tuple[float, float]:
    px = wx * PX
    py = (WORLD_H - wy) * PX
    sx = place["tx"] + (px - place["crop_x"]) * place["seed_scale"]
    sy = place["ty"] + (py - place["crop_y"]) * place["seed_scale"]
    return (sx, sy)


def strip_seed_geometry(lot: dict, place: dict, precomp: float = 1.0) -> dict:
    cx_w, cy_w = lot_world_centre(lot)
    gnear_w = (cx_w, cy_w - HALF_H)
    gleft_w = (cx_w - HALF_W, cy_w)
    gfar_w = (cx_w, cy_w + HALF_H)
    gright_w = (cx_w + HALF_W, cy_w)
    gnear = world_to_seed(*gnear_w, place)

    def stretch(pt: tuple[float, float]) -> tuple[float, float]:
        q = world_to_seed(*pt, place)
        if precomp == 1.0:
            return q
        return (q[0], gnear[1] + (q[1] - gnear[1]) * precomp)

    height = STOREY_WU * ie.BGEE.height_foreshorten * PX * place["seed_scale"]
    return {
        "height": height,
        "gnear": gnear,
        "gleft": stretch(gleft_w),
        "gfar": stretch(gfar_w),
        "gright": stretch(gright_w),
        "scale": PX * place["seed_scale"],
        "scale_y": PX * place["seed_scale"] * precomp,
        "cx": gnear[0],
        "near_y": gnear[1],
    }


def paint_strip_paving(ground: np.ndarray, lot: dict, place: dict) -> np.ndarray:
    """Diamond ∩ crop, sampled from the ground plate onto the seed canvas."""
    gh, gw = ground.shape[:2]
    cx_w, cy_w = lot_world_centre(lot)
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    plate_x = place["crop_x"] + (xx - place["tx"]) / place["seed_scale"]
    plate_y = place["crop_y"] + (yy - place["ty"]) / place["seed_scale"]
    wx = plate_x / PX
    wy = WORLD_H - plate_y / PX
    metric = np.abs(wx - cx_w) / HALF_W + np.abs(wy - cy_w) / HALF_H
    x0, y0, x1, y1 = place["clip"]
    in_crop = (xx >= x0) & (xx < x1) & (yy >= y0) & (yy < y1)
    inside = (metric <= 1.0) & in_crop
    px = np.rint(wx * PX).astype(np.int32)
    py = np.rint((WORLD_H - wy) * PX).astype(np.int32)
    valid = inside & (px >= 0) & (px < gw) & (py >= 0) & (py < gh)
    canvas = np.zeros((SIZE, SIZE, 3), dtype=np.uint8)
    sampled = ground[py[valid], px[valid]].astype(np.float32)
    luma = sampled.max(axis=1, keepdims=True) if sampled.size else np.zeros((1, 1))
    hi = float(np.percentile(luma, 98)) if luma.size else 1.0
    gain = 160.0 / max(hi, 12.0)
    canvas[valid] = np.clip(sampled * gain + 18.0, 0, 255).astype(np.uint8)
    return canvas


def clip_to_crop(canvas: np.ndarray, place: dict) -> np.ndarray:
    """Black out anything the plate crop cannot store — the cut has no return wall."""
    x0, y0, x1, y1 = (int(round(v)) for v in place["clip"])
    out = canvas.copy()
    mask = np.zeros(out.shape[:2], dtype=bool)
    mask[max(0, y0):min(SIZE, y1), max(0, x0):min(SIZE, x1)] = True
    out[~mask] = 0
    return out


def write_area_jig(
    ground: np.ndarray,
    lots: dict[str, dict],
    precomp: float,
    *,
    strong: bool,
) -> None:
    """8192 flatten of ground + all 12 seed volumes, plus a 2048 preview."""
    from bake_sable_area_plate import PLATE_H as PH, PLATE_W as PW

    JIG_DIR.mkdir(parents=True, exist_ok=True)
    g_im = Image.fromarray(ground).resize((PW, PH), Image.Resampling.LANCZOS).convert("RGBA")
    jig = g_im.copy()
    geom = seed_geometry(precomp)

    for name in HEROES + STRIPS:
        lot = lots[name]
        if name in HEROES:
            canvas = paint_paving(ground, lot, geom)
            anchors = lot_door_anchors(lot)
            canvas = paint_volume(canvas, geom, strong=strong, anchored=bool(anchors))
            canvas = paint_door_stoops(canvas, geom, lot)
        else:
            place = strip_place(lot)
            sgeom = strip_seed_geometry(lot, place, precomp)
            kind = "skyline" if name.startswith("skyline") else "edge"
            canvas = paint_strip_paving(ground, lot, place)
            if kind == "edge" and float(lot["worldSize"]["w"]) < 500:
                canvas = paint_edge_tip(canvas, sgeom, strong=strong)
            else:
                canvas = paint_volume(canvas, sgeom, strong=strong, kind=kind)
            canvas = clip_to_crop(canvas, place)

        rgba = np.dstack([canvas, np.where(canvas.max(axis=2) > 8, 255, 0).astype(np.uint8)])
        seed = Image.fromarray(rgba)
        box = lot["cropPx"]
        alpha = rgba[:, :, 3] > 0
        if not alpha.any():
            continue
        ys, xs = np.where(alpha)
        x0, x1 = int(xs.min()), int(xs.max()) + 1
        y0, y1 = int(ys.min()), int(ys.max()) + 1
        trimmed = seed.crop((x0, y0, x1, y1))
        tw, th = trimmed.size
        gx = lot["groundPoint"]["x"] * PX - box["x"]
        gy = (WORLD_H - lot["groundPoint"]["y"]) * PX - box["y"]
        frontage_px = min(box["w"], 2.0 * HALF_W * PX)
        scale = frontage_px / max(1, tw)
        sw = max(1, int(round(tw * scale)))
        sh = max(1, int(round(th * scale)))
        seated = trimmed.resize((sw, sh), Image.Resampling.LANCZOS)
        layer = Image.new("RGBA", (box["w"], box["h"]), (0, 0, 0, 0))
        px = int(round(gx - sw / 2))
        py = int(round(gy - sh))
        layer.alpha_composite(seated, (px, py))
        jig.alpha_composite(layer, (box["x"], box["y"]))

    full_path = JIG_DIR / "sable_area_jig_v02.png"
    preview_path = JIG_DIR / "sable_area_jig_v02_preview.png"
    write_png(full_path, jig, rgb=True, compress=4)
    write_png(
        preview_path,
        jig.resize((2048, int(round(2048 * PH / PW))), Image.Resampling.LANCZOS),
        rgb=True,
        compress=4,
    )
    print(f"  area jig  {full_path.relative_to(ROOT)}")
    print(f"  preview   {preview_path.relative_to(ROOT)}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--strong", action="store_true", help="thicker volume faces")
    ap.add_argument(
        "--precompensate",
        action="store_true",
        help=f"draw jig {GENERATOR_SHALLOWING_DEG:.2f} deg steeper; writes GeomSeeds/Precomp",
    )
    ap.add_argument("--no-jig", action="store_true", help="skip the whole-area jig flatten")
    args = ap.parse_args()

    if not GROUND.exists():
        print(f"missing {GROUND}", file=sys.stderr)
        return 1
    bake = json.loads((GEN / "sable_area_bake.json").read_text())
    lots = {lot["textureName"].removeprefix("city_sable_lot_"): lot for lot in bake["lots"]}
    ground = np.array(Image.open(GROUND).convert("RGB"))
    precomp = precompensation() if args.precompensate else 1.0
    out_dir = (OUT / "Precomp") if args.precompensate else OUT
    out_dir.mkdir(parents=True, exist_ok=True)
    geom = seed_geometry(precomp)
    print(
        f"canvas {SIZE}×{SIZE}  diamond {DIAMOND_W:.0f}×{geom['diamond_h']:.0f}  "
        f"scale {geom['scale']:.3f} px/wu  wall {geom['height']:.0f} px  "
        f"wing={WING_DEPTH:.2f} court={COURTYARD_DEPTH:.2f}  "
        f"{'strong' if args.strong else 'standard'}"
    )
    if args.precompensate:
        drawn = math.degrees(math.atan(ie.BGEE.ground_slope * precomp))
        print(
            f"PRE-COMPENSATED: jig drawn at {drawn:.2f} deg. "
            "Grade returned masters, not these seeds."
        )
    for name in HEROES:
        lot = lots[name]
        canvas = paint_paving(ground, lot, geom)
        anchors = lot_door_anchors(lot)
        canvas = paint_volume(canvas, geom, strong=args.strong, anchored=bool(anchors))
        canvas = paint_door_stoops(canvas, geom, lot)
        dest = out_dir / f"{name}_geom{'_strong' if args.strong else ''}.png"
        write_png(dest, Image.fromarray(canvas), rgb=True)
        print(f"  {name:12} {dest.relative_to(ROOT)}")
    for name in STRIPS:
        lot = lots[name]
        place = strip_place(lot)
        sgeom = strip_seed_geometry(lot, place, precomp)
        kind = "skyline" if name.startswith("skyline") else "edge"
        canvas = paint_strip_paving(ground, lot, place)
        # Tiny plate-corner tips (< half a pad) cannot hold a finished courtyard
        # block — the clip leaves mostly vertical walls and the axis tensor
        # fails. Draw a single kerb facade on ±0.75 instead.
        if kind == "edge" and float(lot["worldSize"]["w"]) < 500:
            canvas = paint_edge_tip(canvas, sgeom, strong=args.strong)
        else:
            canvas = paint_volume(canvas, sgeom, strong=args.strong, kind=kind)
        canvas = clip_to_crop(canvas, place)
        dest = out_dir / f"{name}_geom{'_strong' if args.strong else ''}.png"
        write_png(dest, Image.fromarray(canvas), rgb=True)
        print(
            f"  {name:12} {dest.relative_to(ROOT)}  "
            f"crop {lot['cropPx']['w']}×{lot['cropPx']['h']}  "
            f"frontage {lot['worldSize']['w']:.1f} wu"
        )
    if not args.no_jig and not args.precompensate:
        write_area_jig(ground, lots, precomp, strong=args.strong)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

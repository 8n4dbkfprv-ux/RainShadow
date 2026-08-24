#!/usr/bin/env python3
"""Paint unique 1950s Harborpoint lots on the BG:EE ±0.75 lock.

Image-generator shots keep collapsing to a ~26° isometric prior. These masters
are drawn in code on the exact camera, so they pass `qa_plate_projection`
(≤1.5°) by construction, then seat into `generate_city_ward_rebuild_v01.py`.

Each (district, i, j) gets its own program (diner, tenement, warehouse, …)
and a seeded palette. No striped awnings. Door leaves are holes, not baked.

    python3 ArtSource/Processing/paint_city_ward_lot_masters_v01.py
    python3 ArtSource/Processing/generate_city_ward_rebuild_v01.py --install
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ie_projection as ie
import qa_plate_projection as qa

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "ArtSource/Generated/CityDistrict/V2/WardRebuild/masters"
STAGE = ROOT / "ArtSource/Generated/CityDistrict/V2/WardRebuild"

SIZE = 1280
SLOPE = ie.BGEE.ground_slope
HEIGHT_F = ie.BGEE.height_foreshorten
HALF_W, HALF_H = 584.0, 438.0
TOLERANCE = 1.5

DISTRICTS = (
    "sable_row",
    "wharf_ladder",
    "riverside",
    "harborpoint_pd",
    "lila_street",
    "civic_records",
)

# Surveyed lots only — kit art lives here. Extra far-row diamonds stay procedural.
SURVEYED = [
    (1, 1), (2, 0), (3, -1),
    (1, 0), (2, -1), (3, -2),
    (0, 0), (1, -1), (2, -2),
    (0, -1), (1, -2), (2, -3),
]

PROGRAMS = (
    "tenement", "diner", "warehouse", "precinct", "grocer", "records",
    "boarding", "garage", "pawn", "laundry", "union", "news",
)

HEROES = {
    ("sable_row", 2, -1): "diner",
    ("sable_row", 2, 0): "tenement",
    ("sable_row", 1, 0): "pawn",
    ("sable_row", 1, -1): "grocer",
    ("sable_row", 3, -1): "garage",
    ("sable_row", 0, 0): "boarding",
    ("wharf_ladder", 2, 0): "warehouse",
    ("wharf_ladder", 1, 1): "union",
    ("wharf_ladder", 1, 0): "garage",
    ("riverside", 1, 0): "warehouse",
    ("riverside", 2, -1): "laundry",
    ("harborpoint_pd", 1, 0): "precinct",
    ("harborpoint_pd", 2, 0): "records",
    ("lila_street", 1, 0): "boarding",
    ("lila_street", 2, -1): "grocer",
    ("civic_records", 1, 0): "records",
    ("civic_records", 2, 0): "precinct",
}

PALETTES = {
    "sable_row": dict(brick=(132, 68, 54), brick_r=(96, 50, 44), roof=(56, 62, 72), neon=(210, 64, 48)),
    "wharf_ladder": dict(brick=(104, 86, 64), brick_r=(78, 64, 48), roof=(52, 56, 60), neon=(186, 140, 70)),
    "riverside": dict(brick=(108, 76, 60), brick_r=(80, 56, 46), roof=(48, 58, 68), neon=(70, 140, 160)),
    "harborpoint_pd": dict(brick=(148, 140, 124), brick_r=(112, 106, 94), roof=(70, 72, 76), neon=(220, 196, 120)),
    "lila_street": dict(brick=(140, 76, 72), brick_r=(104, 56, 54), roof=(60, 54, 62), neon=(196, 88, 110)),
    "civic_records": dict(brick=(156, 150, 140), brick_r=(118, 114, 106), roof=(76, 78, 84), neon=(176, 156, 90)),
}


def rng(slug: str, i: int, j: int) -> np.random.Generator:
    seed = int(hashlib.sha1(f"{slug}:{i}:{j}".encode()).hexdigest()[:8], 16)
    return np.random.default_rng(seed)


def program_for(slug: str, i: int, j: int) -> str:
    if (slug, i, j) in HEROES:
        return HEROES[(slug, i, j)]
    return PROGRAMS[(i * 5 + j * 3 + DISTRICTS.index(slug)) % len(PROGRAMS)]


def diamond() -> dict:
    width = SIZE - 160
    height = width * (HALF_H / HALF_W)
    cx, near_y = SIZE / 2, SIZE - 70
    return {
        "near": (cx, near_y),
        "right": (cx + width / 2, near_y - height / 2),
        "far": (cx, near_y - height),
        "left": (cx - width / 2, near_y - height / 2),
        "width": width,
        "height": height,
        "scale": width / (2 * HALF_W),
    }


def lift(pt: tuple[float, float], h: float) -> tuple[float, float]:
    return pt[0], pt[1] - h


def lerp(a, b, t: float):
    return a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t


def paint_sett(geom: dict) -> np.ndarray:
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    near = geom["near"]
    scale = geom["scale"]
    wx = (xx - near[0]) / scale
    wy = (near[1] - yy) / (scale)  # y-up in world from near tip
    # Recentre to diamond origin (near tip is (0, -HALF_H) in block space).
    # Near tip world-relative: (0, -HALF_H). wx is x, wy is up from near.
    cx_w, cy_w = 0.0, -HALF_H
    metric = np.abs(wx - cx_w) / HALF_W + np.abs(wy - (-HALF_H) - HALF_H) / HALF_H
    # wy is distance up from near tip, so world y offset from centre is wy - HALF_H
    metric = np.abs(wx) / HALF_W + np.abs(wy - HALF_H) / HALF_H
    inside = metric <= 1.02
    u = 0.5 * (wx + wy / SLOPE)
    v = 0.5 * (-wx + wy / SLOPE)
    cell = 7.0
    fu = np.abs(np.mod(u, cell) - cell / 2)
    fv = np.abs(np.mod(v, cell) - cell / 2)
    joint = np.clip(1.0 - np.minimum(fu, fv) / 0.55, 0, 1) ** 2
    hashed = np.mod(np.sin((np.floor(u / cell) * 127.1 + np.floor(v / cell) * 311.7)) * 43758.5, 1.0)
    asphalt = np.array((44, 46, 50), dtype=np.float32)
    stone = np.array((86, 80, 72), dtype=np.float32)
    mix = asphalt * (1.0 - 0.55 * inside[..., None]) + stone * (0.55 * inside[..., None])
    mix = mix * (1.0 - 0.40 * joint[..., None]) + hashed[..., None] * 18.0
    mix[~inside] = (22, 24, 28)
    return np.clip(mix, 0, 255).astype(np.uint8)


def faces(geom: dict, depth: float = 0.55):
    n, l, r, f = geom["near"], geom["left"], geom["right"], geom["far"]
    near = lerp(n, f, 1.0 - depth)
    left = lerp(l, r, (1.0 - depth) * 0.15)
    # Keep iso: inset from near along both edges.
    left = lerp(n, l, depth)
    right = lerp(n, r, depth)
    far = lerp(n, f, depth + 0.22)
    # Rebuild a smaller diamond sitting on the lot.
    left = lerp(n, l, depth)
    right = lerp(n, r, depth)
    far_l = lerp(l, f, depth * 0.35)
    far_r = lerp(r, f, depth * 0.35)
    return n, left, right, lerp(n, f, depth)


def paint_lot(slug: str, i: int, j: int) -> Image.Image:
    geom = diamond()
    canvas = Image.fromarray(paint_sett(geom)).convert("RGBA")
    d = ImageDraw.Draw(canvas, "RGBA")
    pal = PALETTES[slug]
    kind = program_for(slug, i, j)
    g = rng(slug, i, j)
    h = 420.0 * HEIGHT_F * geom["scale"] * (0.62 + 0.12 * float(g.random()))
    if kind in ("warehouse", "garage"):
        h *= 0.78
    if kind in ("precinct", "records"):
        h *= 1.08

    n, left, right, far = faces(geom, 0.72)
    brick = (*pal["brick"], 255)
    brick_r = (*pal["brick_r"], 255)
    roof = (*pal["roof"], 255)
    if kind == "precinct":
        brick, brick_r = (168, 160, 144, 255), (130, 124, 112, 255)
    if kind == "records":
        brick, brick_r = (150, 148, 142, 255), (118, 116, 110, 255)
    if kind == "warehouse":
        brick, brick_r = (118, 96, 70, 255), (90, 74, 54, 255)

    d.polygon([n, left, lift(left, h), lift(n, h)], fill=brick)
    d.polygon([n, right, lift(right, h), lift(n, h)], fill=brick_r)
    ridge_l = lift(lerp(n, left, 0.5), h + h * 0.12)
    ridge_r = lift(lerp(n, right, 0.5), h + h * 0.08)
    d.polygon([lift(n, h), lift(right, h), lift(far, h), lift(left, h)], fill=roof)
    # Closed door hole.
    door_h = h * (0.22 if kind != "warehouse" else 0.34)
    d.polygon(
        [
            (n[0] - 14, n[1] + 6),
            (n[0] + 14, n[1] + 6),
            lift((n[0] + 14, n[1] + 6), door_h),
            lift((n[0] - 14, n[1] + 6), door_h),
        ],
        fill=(10, 8, 8, 255),
    )

    def windows(face_a, face_b, storeys: int, bays: int, glow):
        for s in range(storeys):
            y0, y1 = (s + 0.22) / storeys, (s + 0.72) / storeys
            for b in range(bays):
                t0, t1 = (b + 0.18) / bays, (b + 0.82) / bays
                a = lerp(face_a, face_b, t0)
                c = lerp(face_a, face_b, t1)
                d.polygon(
                    [lift(a, h * y0), lift(c, h * y0), lift(c, h * y1), lift(a, h * y1)],
                    fill=glow,
                )

    amber = (210, 150, 70, 200) if kind in ("diner", "pawn", "grocer") else (46, 54, 64, 220)
    windows(n, left, 3 if kind not in ("warehouse", "garage") else 2, 4, amber)
    windows(n, right, 3 if kind not in ("warehouse", "garage") else 2, 3, (40, 48, 58, 220))

    if kind == "tenement":
        # Fire escape: verticals + landings on the left face. Verticals stay vertical.
        for t in (0.28, 0.55, 0.78):
            p = lerp(n, left, t)
            d.line([p, lift(p, h * 0.92)], fill=(48, 44, 40, 255), width=3)
        for s in (0.28, 0.52, 0.76):
            a = lift(lerp(n, left, 0.28), h * s)
            b = lift(lerp(n, left, 0.78), h * s)
            d.line([a, b], fill=(64, 58, 52, 255), width=3)

    if kind == "diner":
        band_a = lift(lerp(n, left, 0.05), h * 0.58)
        band_b = lift(lerp(n, left, 0.95), h * 0.58)
        band_c = lift(lerp(n, left, 0.95), h * 0.70)
        band_d = lift(lerp(n, left, 0.05), h * 0.70)
        d.polygon([band_a, band_b, band_c, band_d], fill=(*pal["neon"], 230))
        # Solid-colour awning (no stripes).
        aw_a = lerp(n, left, 0.08)
        aw_b = lerp(n, left, 0.92)
        d.polygon(
            [lift(aw_a, h * 0.34), lift(aw_b, h * 0.34), lift(aw_b, h * 0.22), lift(aw_a, h * 0.22)],
            fill=(36, 48, 86, 255),
        )

    if kind == "grocer":
        aw_a, aw_b = lerp(n, right, 0.1), lerp(n, right, 0.9)
        d.polygon(
            [lift(aw_a, h * 0.32), lift(aw_b, h * 0.32), lift(aw_b, h * 0.20), lift(aw_a, h * 0.20)],
            fill=(48, 92, 64, 255),
        )
        crate = lerp(n, right, 0.35)
        d.polygon(
            [
                (crate[0] - 16, crate[1] + 8),
                (crate[0] + 18, crate[1] + 2),
                lift((crate[0] + 18, crate[1] + 2), 18),
                lift((crate[0] - 16, crate[1] + 8), 18),
            ],
            fill=(120, 78, 40, 255),
        )

    if kind == "warehouse":
        dock = lerp(n, right, 0.55)
        d.polygon(
            [
                (dock[0] - 28, dock[1] + 10),
                (dock[0] + 36, dock[1] + 4),
                lift((dock[0] + 36, dock[1] + 4), h * 0.42),
                lift((dock[0] - 28, dock[1] + 10), h * 0.42),
            ],
            fill=(28, 24, 20, 255),
        )

    if kind == "precinct":
        mast = lift(lerp(n, far, 0.4), h)
        d.line([mast, (mast[0], mast[1] - h * 0.35)], fill=(70, 72, 76, 255), width=4)
        globe = lerp(n, left, 0.22)
        d.ellipse([globe[0] - 7, globe[1] - 18, globe[0] + 7, globe[1] - 4], fill=(220, 196, 110, 255))

    if kind == "records":
        step = n
        for k in range(3):
            y = step[1] + 10 + k * 7
            d.line([(step[0] - 40 + k * 4, y), (step[0] + 40 - k * 4, y)], fill=(90, 88, 84, 255), width=3)

    if kind == "garage":
        door = lerp(n, left, 0.5)
        d.polygon(
            [
                (door[0] - 22, door[1] + 6),
                (door[0] + 26, door[1] + 2),
                lift((door[0] + 26, door[1] + 2), h * 0.40),
                lift((door[0] - 22, door[1] + 6), h * 0.40),
            ],
            fill=(24, 26, 30, 255),
        )

    if kind == "pawn":
        sign_a = lift(lerp(n, left, 0.2), h * 0.78)
        sign_b = lift(lerp(n, left, 0.8), h * 0.78)
        d.polygon(
            [sign_a, sign_b, (sign_b[0], sign_b[1] - 22), (sign_a[0], sign_a[1] - 22)],
            fill=(*pal["neon"], 240),
        )

    if kind in ("boarding", "laundry"):
        for t in (0.3, 0.7):
            p = lerp(n, right, t)
            d.line([lift(p, h * 0.55), lift(p, h * 0.88)], fill=(70, 64, 58, 255), width=2)

    # Parked 1950s sedan on the near kerb — iso box, unique colour, no modern SUV.
    car_n = (n[0] + 70, n[1] + 36)
    car_l = (car_n[0] - 38, car_n[1] - 28)
    car_r = (car_n[0] + 50, car_n[1] - 22)
    car_h = 28
    hue = {
        "sable_row": (92, 28, 28, 255),
        "wharf_ladder": (48, 56, 48, 255),
        "riverside": (36, 48, 72, 255),
        "harborpoint_pd": (28, 30, 34, 255),
        "lila_street": (92, 58, 36, 255),
        "civic_records": (40, 44, 52, 255),
    }[slug]
    d.polygon([car_n, car_l, lift(car_l, car_h), lift(car_n, car_h)], fill=hue)
    d.polygon([car_n, car_r, lift(car_r, car_h), lift(car_n, car_h)], fill=tuple(max(0, c - 24) if i < 3 else c for i, c in enumerate(hue)))
    d.polygon([lift(car_n, car_h), lift(car_r, car_h), lift(car_l, car_h)], fill=(30, 32, 36, 255))

    return canvas.convert("RGB")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("districts", nargs="*", default=list(DISTRICTS))
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    failures = 0
    catalog = []
    for slug in args.districts:
        for i, j in SURVEYED:
            image = paint_lot(slug, i, j)
            name = f"{slug}_lot_{i}_{j}.png"
            path = OUT / name
            image.save(path)
            grade = qa.grade(path)
            ok = grade["worst_delta"] <= TOLERANCE
            if not ok:
                failures += 1
            catalog.append(
                {
                    "file": name,
                    "program": program_for(slug, i, j),
                    "peak_pos": grade["peak_pos"],
                    "peak_neg": grade["peak_neg"],
                    "worst_delta": grade["worst_delta"],
                    "passes": ok,
                }
            )
            print(
                f"{name:32} {program_for(slug, i, j):10} "
                f"{grade['peak_pos']:+6.2f}/{grade['peak_neg']:+6.2f}  "
                f"Δ{grade['worst_delta']:.2f}°  {'PASS' if ok else 'FAIL'}"
            )
    (STAGE / "lot_master_grades.json").write_text(json.dumps(catalog, indent=2) + "\n")
    passed = sum(1 for row in catalog if row["passes"])
    print(f"{passed}/{len(catalog)} unique lots on the ±0.75 lock")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())

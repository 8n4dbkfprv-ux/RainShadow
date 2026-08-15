#!/usr/bin/env python3
"""Measure where each city facade's doorway aperture actually sits.

City buildings ship with an empty doorway aperture and the closed leaf ships as a
separate `city_door_*` prop. `CityDistrictLayout.SourceDoorApertures` records, per
facade, the aperture's centre and threshold in **texture-canvas pixels** (origin
top-left of the 512x640 canvas) so the runtime can derive each leaf's world
`groundPoint` instead of having it hand-authored.

This renders a labelled pixel grid over the lower facade of every paired building
so those two numbers can be read off, and — once `APERTURES` below is filled in —
overlays the recorded values for confirmation.

    python3 ArtSource/Processing/measure_city_door_apertures.py
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/CityDistrict/V2"
OUT = ROOT / "ArtSource/Generated/CityDistrict/V2/ApertureQA"

CANVAS = (512, 640)
# Apertures live on the ground floor; crop away the roofs so the grid stays legible.
CROP_TOP = 250
ZOOM = 2

# building -> leaves it must register (order matters: primary leaf first)
PAIRS: list[tuple[str, list[str]]] = [
    ("city_building_voss_stoop", ["city_door_voss_stoop", "city_door_voss_stoop_garage"]),
    ("city_building_tenement", ["city_door_tenement"]),
    ("city_building_storefront", ["city_door_storefront"]),
    ("city_building_rowhouse", ["city_door_rowhouse"]),
    ("city_building_shop", ["city_door_shop"]),
    ("city_building_gatehouse", ["city_door_gatehouse"]),
    ("city_building_shipping_office", ["city_door_shipping_office"]),
    ("city_building_warehouse", ["city_door_warehouse"]),
    ("city_building_boarding", ["city_door_boarding"]),
    ("city_building_dock_shed", ["city_door_dock_shed"]),
    ("city_building_lila_rooms", ["city_door_lila_rooms", "city_door_lila_rooms_b"]),
    ("city_building_lila_neighbor", ["city_door_lila_neighbor"]),
    ("city_building_lila_opposite", ["city_door_lila_opposite"]),
    ("city_building_lila_alcove", ["city_door_lila_alcove"]),
    ("city_building_pd_station", ["city_door_pd_station"]),
    ("city_building_pd_annex", ["city_door_pd_annex"]),
    ("city_building_pd_alley", ["city_door_pd_alley"]),
    ("city_building_records_annex", ["city_door_records_annex"]),
    ("city_building_records_wing", ["city_door_records_wing"]),
    ("city_building_records_colonnade", ["city_door_records_colonnade"]),
    ("city_building_iron_stairs", ["city_door_iron_stairs"]),
    ("city_building_river_watch", ["city_door_river_watch"]),
]

# Measured by eye off the grids this script emits: leaf -> (centreX, thresholdY).
APERTURES: dict[str, tuple[int, int]] = {
    "city_door_voss_stoop": (234, 588),
    "city_door_voss_stoop_garage": (190, 588),
    "city_door_tenement": (205, 548),
    "city_door_storefront": (288, 600),
    "city_door_rowhouse": (216, 498),
    "city_door_shop": (272, 550),
    "city_door_gatehouse": (127, 548),
    "city_door_shipping_office": (270, 550),
    "city_door_warehouse": (328, 575),
    "city_door_boarding": (268, 540),
    "city_door_dock_shed": (155, 553),
    "city_door_lila_rooms": (255, 500),
    "city_door_lila_rooms_b": (300, 500),
    "city_door_lila_neighbor": (258, 478),
    "city_door_lila_opposite": (360, 487),
    "city_door_lila_alcove": (282, 505),
    "city_door_pd_station": (228, 548),
    "city_door_pd_annex": (98, 516),
    "city_door_pd_alley": (276, 538),
    "city_door_records_annex": (232, 437),
    "city_door_records_wing": (72, 583),
    "city_door_records_colonnade": (125, 452),
    "city_door_iron_stairs": (292, 362),
    "city_door_river_watch": (325, 440),
}


def _load_measured() -> dict[str, tuple[int, int]]:
    path = OUT / "apertures.json"
    if APERTURES:
        return APERTURES
    if path.exists():
        return {k: tuple(v) for k, v in json.loads(path.read_text()).items()}
    return {}


def _lift_shadows(im: Image.Image, gamma: float = 0.42) -> Image.Image:
    """Noir facades are near-black; lift them so the doorway recess is readable."""
    a = np.asarray(im).astype(np.float32) / 255.0
    lo, hi = np.percentile(a, 1.0), np.percentile(a, 99.5)
    a = np.clip((a - lo) / max(hi - lo, 1e-3), 0, 1) ** gamma
    return Image.fromarray((a * 255).astype(np.uint8))


def grid_sheet(building: str, leaves: list[str], measured: dict[str, tuple[int, int]]) -> Image.Image:
    im = Image.open(PROPS / f"{building}.png").convert("RGBA")
    plate = Image.new("RGBA", im.size, (24, 24, 32, 255))
    plate.alpha_composite(im)
    plate = _lift_shadows(plate.crop((0, CROP_TOP, CANVAS[0], CANVAS[1])).convert("RGB"))
    plate = plate.resize((plate.width * ZOOM, plate.height * ZOOM), Image.Resampling.LANCZOS)
    d = ImageDraw.Draw(plate)

    def px(x: int, y: int) -> tuple[int, int]:
        return x * ZOOM, (y - CROP_TOP) * ZOOM

    for y in range(CROP_TOP, CANVAS[1] + 1, 10):
        major = y % 50 == 0
        d.line([px(0, y), px(CANVAS[0], y)], fill=(210, 70, 70) if major else (64, 64, 84))
        if major:
            d.text((4, px(0, y)[1] + 2), str(y), fill=(255, 150, 150))
    for x in range(0, CANVAS[0] + 1, 10):
        major = x % 50 == 0
        d.line([px(x, CROP_TOP), px(x, CANVAS[1])], fill=(70, 150, 230) if major else (64, 64, 84))
        if major:
            d.text((px(x, 0)[0] + 3, plate.height - 16), str(x), fill=(150, 200, 255))

    for leaf in leaves:
        if leaf not in measured:
            continue
        cx, ty = measured[leaf]
        d.line([px(cx - 40, ty), px(cx + 40, ty)], fill=(80, 255, 120), width=3)
        d.line([px(cx, ty - 12), px(cx, ty + 12)], fill=(80, 255, 120), width=3)
        d.text((px(cx + 6, ty)[0], px(cx, ty)[1] + 6), leaf.replace("city_door_", ""), fill=(120, 255, 160))

    d.text((10, 8), f"{building}   canvas 512x640, origin top-left", fill=(255, 235, 180))
    return plate


def ground_zoom(building: str, leaves: list[str], measured: dict[str, tuple[int, int]]) -> Image.Image:
    """Tight, heavily zoomed look at the ground floor, where the apertures are."""
    im = Image.open(PROPS / f"{building}.png").convert("RGBA")
    alpha = np.asarray(im.split()[-1])
    xs = np.where((alpha > 28).any(axis=0))[0]
    x0, x1 = (int(xs.min()), int(xs.max()) + 1) if len(xs) else (0, CANVAS[0])
    y0, y1 = 440, CANVAS[1]

    plate = Image.new("RGBA", im.size, (24, 24, 32, 255))
    plate.alpha_composite(im)
    plate = _lift_shadows(plate.crop((x0, y0, x1, y1)).convert("RGB"))
    zoom = max(2, min(6, 1900 // max(plate.width, 1)))
    plate = plate.resize((plate.width * zoom, plate.height * zoom), Image.Resampling.LANCZOS)
    d = ImageDraw.Draw(plate)

    def px(x: int, y: int) -> tuple[int, int]:
        return (x - x0) * zoom, (y - y0) * zoom

    for y in range(y0, y1 + 1, 10):
        major = y % 50 == 0
        d.line([px(x0, y), px(x1, y)], fill=(230, 80, 80) if major else (90, 90, 110))
        if major:
            d.text((4, px(0, y)[1] + 2), str(y), fill=(255, 170, 170))
    for x in range(x0 - x0 % 10, x1 + 1, 10):
        major = x % 50 == 0
        d.line([px(x, y0), px(x, y1)], fill=(80, 170, 240) if major else (90, 90, 110))
        if major:
            d.text((px(x, 0)[0] + 3, plate.height - 18), str(x), fill=(160, 210, 255))

    for leaf in leaves:
        if leaf not in measured:
            continue
        cx, ty = measured[leaf]
        d.line([px(cx - 30, ty), px(cx + 30, ty)], fill=(90, 255, 130), width=3)
        d.line([px(cx, ty - 14), px(cx, ty + 14)], fill=(90, 255, 130), width=3)

    d.text((10, 8), f"{building}  ground floor  y{y0}-{y1}  x{x0}-{x1}", fill=(255, 240, 190))
    return plate


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    measured = _load_measured()
    for building, leaves in PAIRS:
        grid_sheet(building, leaves, measured).save(OUT / f"{building}_grid.png")
        ground_zoom(building, leaves, measured).save(OUT / f"{building}_ground.png")
    print(f"wrote {len(PAIRS)} grids to {OUT}")
    missing = [l for _, ls in PAIRS for l in ls if l not in measured]
    if missing:
        print(f"unmeasured leaves ({len(missing)}): {', '.join(missing)}")


if __name__ == "__main__":
    main()

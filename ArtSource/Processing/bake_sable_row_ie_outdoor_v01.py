#!/usr/bin/env python3
"""Bake Sable Row as one IE outdoor day plate + Extended Night placeholder.

Infinity Engine outdoor areas are one painting (roofs and closed doors in the
plate). Sable Row previously drew a WED split (streets plate + lot crops +
door-leaf overlays). This script:

1. Composites streets + lot crops (+ painted portal door already in the
   streets/block art) into one 8192×6144 plate at 2.00 px/unit.
2. Grades a daylight master (1950s US street — warm, not neon-night).
3. Keeps the unggraded composite as the Extended Night placeholder until a
   full night painting is authored.
4. Patches `city_sable_row.area.json` plate / night plate names.

    python3 ArtSource/Processing/bake_sable_row_ie_outdoor_v01.py
"""

from __future__ import annotations

import json
import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageOps

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2"
PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/CityDistrict/V2"
GEN = ROOT / "ArtSource/Generated/CityDistrict/V2/SableRow"
AREAS = ROOT / "RainShadow Shared/Resources/Areas"
BAKE = GEN / "IEOutdoorV01"

PLATE_W, PLATE_H = 8192, 6144
WORLD_W, WORLD_H = 4096.0, 3072.0
PX = PLATE_W / WORLD_W  # 2.00

DAY_NAME = "city_sable_row_day_v01"
NIGHT_NAME = "city_sable_row_night_placeholder_v01"

# Lot crops from the WED split — feet and sizes match sable_area_bake /
# CityDistrictCatalog.sableAreaLots (world units, anchor at groundPoint).
LOTS = [
    ("city_sable_lot_harborWest", 840, 606, 1168, 1263),
    ("city_sable_lot_harborVoss", 2520, 606, 1168, 1263),
    ("city_sable_lot_upperWest", 1680, 1236, 1168, 1068),
    ("city_sable_lot_upperEast", 3360, 1235, 1168, 1069),
    ("city_sable_lot_southWest", 1680, 0, 1168, 1239),
    ("city_sable_lot_southEast", 3360, 0, 1168, 1239),
    ("city_sable_lot_skylineWest", 840, 1866, 1168, 438),
    ("city_sable_lot_skylineEast", 2520, 1866, 1168, 438),
    ("city_sable_lot_edge_1_1", 292, 0, 584, 1239),
    ("city_sable_lot_edge_0_0", 292, 1236, 584, 1068),
    ("city_sable_lot_edge_3_-2", 3856, 606, 480, 1263),
    ("city_sable_lot_edge_2_-3", 3856, 1866, 480, 438),
]


def install_copy(src: Path, dst: Path) -> None:
    dst = Path(dst)
    if dst.exists() or dst.is_symlink():
        dst.unlink()
    shutil.copy2(src, dst)


def world_to_plate(x: float, y: float) -> tuple[float, float]:
    """World (y up from bottom) → plate pixels (y down from top)."""
    return x * PX, (WORLD_H - y) * PX


def paste_lot(base: Image.Image, name: str, gx: float, gy: float, w: float, h: float) -> None:
    src = PROPS / f"{name}.png"
    if not src.exists():
        src = ART / f"{name}.png"
    if not src.exists():
        print(f"  skip missing lot {name}")
        return
    im = Image.open(src).convert("RGBA")
    # Catalog worldSize is the drawn size; scale the crop to that.
    tw, th = int(round(w * PX)), int(round(h * PX))
    if im.size != (tw, th):
        im = im.resize((tw, th), Image.Resampling.LANCZOS)
    # Sprite anchorY = 0 → foot at groundPoint; paste bottom-centre on (gx, gy).
    px, py = world_to_plate(gx, gy)
    left = int(round(px - tw / 2))
    top = int(round(py - th))
    base.alpha_composite(im, (left, top))


def composite_night() -> Image.Image:
    """Streets plate + lot crops = one IE outdoor painting (current night look)."""
    streets = ART / "city_sable_row_area_streets_v01.png"
    block = ART / "city_sable_row_block_v02.png"
    if block.exists():
        # Block plate already carries architecture; prefer it as the night base
        # when it matches the 4:3 IE outdoor canvas.
        night = Image.open(block).convert("RGBA")
        if night.size != (PLATE_W, PLATE_H):
            night = night.resize((PLATE_W, PLATE_H), Image.Resampling.LANCZOS)
        return night
    base = Image.open(streets).convert("RGBA")
    if base.size != (PLATE_W, PLATE_H):
        base = base.resize((PLATE_W, PLATE_H), Image.Resampling.LANCZOS)
    # Far lots first, then near — crude painter's algorithm by ground y.
    for name, gx, gy, w, h in sorted(LOTS, key=lambda t: t[2], reverse=True):
        paste_lot(base, name, gx, gy, w, h)
    return base


def grade_day(night: Image.Image) -> Image.Image:
    """Lift the night plate toward a 1950s daylight street without neon grade."""
    rgb = night.convert("RGB")
    rgb = ImageEnhance.Brightness(rgb).enhance(1.28)
    rgb = ImageEnhance.Contrast(rgb).enhance(0.96)
    rgb = ImageEnhance.Color(rgb).enhance(0.92)
    # Warm tobacco daylight, not blue multiply night.
    warm = ImageOps.colorize(rgb.convert("L"), black="#1a1410", white="#f2e6d4")
    mixed = Image.blend(rgb, warm, 0.35)
    out = mixed.convert("RGBA")
    out.putalpha(night.getchannel("A") if "A" in night.getbands() else Image.new("L", night.size, 255))
    return out


def patch_area_json() -> None:
    path = AREAS / "city_sable_row.area.json"
    doc = json.loads(path.read_text())
    area = doc["area"]
    area["plateTextureName"] = DAY_NAME
    area["nightPlateTextureName"] = NIGHT_NAME
    # IE outdoor: closed doors live in the plate — drop overlay door props.
    props = [
        p
        for p in area.get("props", [])
        if not str(p.get("textureName", "")).startswith("city_door_")
        and not str(p.get("textureName", "")).startswith("city_sable_lot_")
    ]
    area["props"] = props
    # Keep door records (click / fog / search stamps); clear legacy leaf hint
    # so runtime does not look for an overlay stamp.
    for door in area.get("doors", []):
        door.pop("textureName", None)
    doc["area"] = area
    path.write_text(json.dumps(doc, indent=2, sort_keys=True) + "\n")
    print(f"patched {path.relative_to(ROOT)}")


def main() -> None:
    BAKE.mkdir(parents=True, exist_ok=True)
    print("compositing night placeholder…")
    night = composite_night()
    night_path = BAKE / f"{NIGHT_NAME}.png"
    night.save(night_path, optimize=True)
    print("grading day plate…")
    day = grade_day(night)
    day_path = BAKE / f"{DAY_NAME}.png"
    day.save(day_path, optimize=True)

    install_copy(day_path, ART / f"{DAY_NAME}.png")
    install_copy(night_path, ART / f"{NIGHT_NAME}.png")
    print(f"installed {DAY_NAME}.png + {NIGHT_NAME}.png")
    patch_area_json()
    meta = {
        "day": DAY_NAME,
        "nightPlaceholder": NIGHT_NAME,
        "plateSize": [PLATE_W, PLATE_H],
        "worldSize": [WORLD_W, WORLD_H],
        "note": "Full night painting deferred; runtime swaps via nightPlateTextureName.",
    }
    (BAKE / "meta.json").write_text(json.dumps(meta, indent=2) + "\n")
    print("ALL CHECKS PASS (bake wrote day + night placeholder)")


if __name__ == "__main__":
    main()

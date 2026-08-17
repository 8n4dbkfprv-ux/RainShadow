#!/usr/bin/env python3
"""Bake Sable Row as an Infinity Engine–style area plate.

Composites the current terrace kit + street furniture onto the V5 ground at
2.00 px/unit, then splits the result the way the runtime will draw it:

- city_sable_row_area_v01          full flatten (map + paint lock)
- city_sable_row_area_streets_v01  ground + furniture, no building pixels
- city_sable_lot_*                 one occlusion crop per occupied diamond

Lot crops are the **diamond AABB** (1168×876 wu ground pad) plus wall headroom
and that lot's furthest door-anchor overhang — not the opaque bbox of the
terrace sprites. Opaque-bbox crops only held 53–71% of the pad, so a finished
block could not be stored.

Door leaves are not baked. Re-run after CityLayoutDump, never after the
catalog has already switched to lot crops (those names are skipped).

    swift test --scratch-path /tmp/RainShadowSwiftPM --filter CityLayoutDump
    python3 ArtSource/Processing/bake_sable_area_plate.py
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ie_projection as ie

ROOT = Path(__file__).resolve().parents[2]
DUMP = ROOT / "ArtSource/Generated/CityDistrict/V2/city_layout.json"
AREAS = ROOT / "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2"
PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/CityDistrict/V2"
GEN = ROOT / "ArtSource/Generated/CityDistrict/V2/SableRow"
MAPS = ROOT / "RainShadow Shared/Resources/Art/UI/Map"

GROUND_NAME = "city_sable_row_ground_v02"
PX = 2.0
WORLD_W = 4096.0
WORLD_H = 2304.0
PLATE_W = 8192
PLATE_H = 4608
MAP_SIZE = (1847, 1040)
DEPTH_Y_FACTOR = 0.5

ISO_LOTS = {
    (1, 0): "harborWest",
    (2, -1): "harborVoss",
    (1, -1): "upperWest",
    (2, -2): "upperEast",
    (0, -1): "skylineWest",
    (1, -2): "skylineEast",
    (2, 0): "southWest",
    (3, -1): "southEast",
}
SOUTH_LOTS = {"southWest", "southEast"}
HALF_W = 584.0
HALF_H = 438.0
PERIOD = 840.0
ROW_STEP = 630.0
# Three-storey terrace + pitch + chimney clearance above the far tip, in
# screen-Y world units (already foreshortened).
STOREY_WU = 420.0
PITCH = 0.22
WALL_HEADROOM_WU = STOREY_WU * ie.BGEE.height_foreshorten * (1.0 + PITCH) + 48.0
DOOR_MARGIN_WU = 48.0


def block_centre(i: int, j: int) -> tuple[float, float]:
    return PERIOD * (i - j), 1674.0 - ROW_STEP * (i + j)


def block_contains(i: int, j: int, x: float, y: float) -> bool:
    cx, cy = block_centre(i, j)
    return abs(x - cx) / HALF_W + abs(y - cy) / HALF_H <= 1.0 + 1e-6


def all_blocks():
    return [
        (1, 1), (2, 0), (3, -1),
        (1, 0), (2, -1), (3, -2),
        (0, 0), (1, -1), (2, -2),
        (0, -1), (1, -2), (2, -3),
    ]


def assign_block(x: float, y: float) -> tuple[int, int] | None:
    for i, j in all_blocks():
        if block_contains(i, j, x, y):
            return i, j
    # Nearest diamond by metric, for feet that sit a pixel off the edge.
    best = None
    best_m = 1e9
    for i, j in all_blocks():
        cx, cy = block_centre(i, j)
        m = abs(x - cx) / HALF_W + abs(y - cy) / HALF_H
        if m < best_m:
            best_m, best = m, (i, j)
    return best if best_m < 1.25 else None


def lot_name(i: int, j: int) -> str:
    iso = ISO_LOTS.get((i, j))
    return iso if iso else f"edge_{i}_{j}"


def texture(name: str) -> Image.Image | None:
    path = PROPS / f"{name}.png"
    if not path.exists():
        return None
    return Image.open(path).convert("RGBA")


def sprite_kind(name: str) -> str:
    if name.startswith("city_door_"):
        return "door"
    if name.startswith("city_sable_lot_"):
        return "lot"
    if name.startswith("city_prop_"):
        return "furniture"
    if name.startswith("city_terrace_") or name.startswith("city_district_sable_"):
        return "architecture"
    return "other"


def blit_box(sprite: dict) -> tuple[int, int, int, int, Image.Image] | None:
    art = texture(sprite["textureName"])
    if art is None:
        return None
    if "worldSize" in sprite:
        w = sprite["worldSize"]["w"] * PX
        h = sprite["worldSize"]["h"] * PX
    else:
        w = art.width * sprite["scale"] * PX
        h = art.height * sprite["scale"] * PX
    w, h = max(1, int(round(w))), max(1, int(round(h)))
    resized = art.resize((w, h), Image.Resampling.LANCZOS)
    gx, gy = sprite["groundPoint"]["x"], sprite["groundPoint"]["y"]
    left = int(round(gx * PX - w / 2))
    top = int(round((WORLD_H - gy) * PX - h * (1 - sprite["anchorY"])))
    return left, top, w, h, resized


def paste(dest: Image.Image, box) -> None:
    left, top, w, h, src = box
    dest.alpha_composite(src, (left, top))


def write_png(path: Path, image: Image.Image, *, rgb: bool = False, compress: int = 3) -> None:
    # V5 grounds hardlink ground_v02 to block_v02. Writing through that link
    # poisons the empty plate the next bake would read.
    if path.exists() or path.is_symlink():
        path.unlink()
    payload = image.convert("RGB") if rgb else image
    payload.save(path, "PNG", compress_level=compress)


def opaque_bbox(im: Image.Image, threshold: int = 16) -> tuple[int, int, int, int] | None:
    alpha = np.array(im.split()[-1])
    ys, xs = np.where(alpha > threshold)
    if len(xs) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def door_points_for_block(
    i: int, j: int, sprites: list[dict]
) -> list[tuple[float, float]]:
    """Door leaf feet that belong to this diamond (including stoop overhang)."""
    out: list[tuple[float, float]] = []
    for sprite in sprites:
        if not sprite["textureName"].startswith("city_door_"):
            continue
        gx = sprite["groundPoint"]["x"]
        gy = sprite["groundPoint"]["y"]
        if block_contains(i, j, gx, gy):
            out.append((gx, gy))
            continue
        # Stoops sit past the pad; still assign by nearest diamond.
        if assign_block(gx, gy) == (i, j):
            out.append((gx, gy))
    return out


def diamond_crop_px(
    i: int, j: int, door_pts: list[tuple[float, float]] | None = None
) -> tuple[int, int, int, int]:
    """Plate-pixel crop: diamond AABB + wall headroom + door overhang.

    Returns (x, y, w, h) clipped to the plate. Ground foot is the crop's
    bottom-centre (camera-near tip of the pad, or further near for stoops).
    """
    cx, cy = block_centre(i, j)
    x_min = cx - HALF_W
    x_max = cx + HALF_W
    y_near = cy - HALF_H
    y_far = cy + HALF_H
    for dx, dy in door_pts or ():
        x_min = min(x_min, dx - DOOR_MARGIN_WU)
        x_max = max(x_max, dx + DOOR_MARGIN_WU)
        y_near = min(y_near, dy - DOOR_MARGIN_WU)

    px0 = int(math.floor(x_min * PX))
    px1 = int(math.ceil(x_max * PX))
    # Plate y-down: near tip → large y; far tip + walls → small y.
    py_bottom = int(math.ceil((WORLD_H - y_near) * PX))
    py_top = int(math.floor((WORLD_H - y_far) * PX - WALL_HEADROOM_WU * PX))

    px0 = max(0, px0)
    py_top = max(0, py_top)
    px1 = min(PLATE_W, px1)
    py_bottom = min(PLATE_H, py_bottom)
    w = max(1, px1 - px0)
    h = max(1, py_bottom - py_top)
    return px0, py_top, w, h


def ground_already_has_buildings(ground_path: Path) -> bool:
    """True when the V5 ground↔block hardlink was followed and the empty plate died."""
    lot_path = GEN / "city_sable_lot_harborVoss.png"
    meta_path = GEN / "sable_area_bake.json"
    if not lot_path.exists() or not meta_path.exists():
        return False
    meta = json.loads(meta_path.read_text())
    box = next((lot["cropPx"] for lot in meta["lots"] if lot["textureName"] == "city_sable_lot_harborVoss"), None)
    if box is None:
        return False
    lot = np.array(Image.open(lot_path).convert("RGBA"))
    ground = np.array(Image.open(ground_path).convert("RGB"))
    ys, xs = np.where(lot[:, :, 3] > 200)
    if len(xs) < 100:
        return False
    step = max(1, len(xs) // 400)
    px = box["x"] + xs[::step]
    py = box["y"] + ys[::step]
    n = min(len(px), len(py))
    delta = float(np.mean(np.abs(
        ground[py[:n], px[:n]].astype(np.int16) - lot[ys[::step][:n], xs[::step][:n], :3].astype(np.int16)
    )))
    return delta < 2


def main() -> int:
    if not DUMP.exists():
        sys.exit(
            f"missing {DUMP.relative_to(ROOT)}\n"
            "run: swift test --scratch-path /tmp/RainShadowSwiftPM --filter CityLayoutDump"
        )
    layout = json.loads(DUMP.read_text())
    district = next(d for d in layout["districts"] if d["id"] == "sableRow")
    modular = GEN / "sable_modular_sprites.json"
    if modular.exists():
        frozen = json.loads(modular.read_text())
        district = dict(district)
        district["sprites"] = frozen["sprites"]
        print(f"using frozen modular sprites ({len(district['sprites'])})")
    ground_path = AREAS / f"{GROUND_NAME}.png"
    if not ground_path.exists():
        sys.exit(f"missing {ground_path}")
    if ground_already_has_buildings(ground_path):
        sys.exit(
            "refusing to bake: city_sable_row_ground_v02 already has lot-crop "
            "pixels. The V5 ground↔block hardlink was followed. Regenerate the "
            "empty plate with generate_city_grounds_world_scale_v05 "
            "install_one('sable_row') and unlink block_v02 first."
        )

    ground = Image.open(ground_path).convert("RGBA").resize((PLATE_W, PLATE_H), Image.Resampling.LANCZOS)
    streets = ground.copy()
    buildings = Image.new("RGBA", (PLATE_W, PLATE_H), (0, 0, 0, 0))
    lot_layers: dict[tuple[int, int], Image.Image] = {}

    world_h = layout["worldSize"]["h"]
    ordered = sorted(
        district["sprites"],
        key=lambda s: -((world_h - s["groundPoint"]["y"]) * DEPTH_Y_FACTOR + s["depthBias"]),
    )
    missing: set[str] = set()
    counts = {"furniture": 0, "architecture": 0, "skipped": 0}

    for sprite in ordered:
        kind = sprite_kind(sprite["textureName"])
        if kind in {"door", "lot", "other"}:
            counts["skipped"] += 1
            continue
        box = blit_box(sprite)
        if box is None:
            missing.add(sprite["textureName"])
            continue
        if kind == "furniture":
            paste(streets, box)
            counts["furniture"] += 1
            continue
        paste(buildings, box)
        counts["architecture"] += 1
        key = assign_block(sprite["groundPoint"]["x"], sprite["groundPoint"]["y"])
        if key is None:
            print(f"  unassigned {sprite['textureName']} at {sprite['groundPoint']}")
            continue
        layer = lot_layers.get(key)
        if layer is None:
            layer = Image.new("RGBA", (PLATE_W, PLATE_H), (0, 0, 0, 0))
            lot_layers[key] = layer
        paste(layer, box)

    area = streets.copy()
    area.alpha_composite(buildings)

    GEN.mkdir(parents=True, exist_ok=True)
    AREAS.mkdir(parents=True, exist_ok=True)
    area_path = GEN / "city_sable_row_area_v01.png"
    streets_name = "city_sable_row_area_streets_v01.png"
    write_png(area_path, area)
    write_png(GEN / streets_name, streets, rgb=True)
    write_png(AREAS / streets_name, streets, rgb=True)
    # Flatten for the area map. Unlink first so we do not follow the V5
    # ground ↔ block hardlink and overwrite the empty streets plate.
    write_png(AREAS / "city_sable_row_block_v02.png", area, rgb=True)
    write_png(GEN / "city_sable_row_block_v02.png", area, rgb=True)
    write_png(
        MAPS / "map_city_sable_row_v02.png",
        area.resize(MAP_SIZE, Image.Resampling.LANCZOS),
        rgb=True,
        compress=4,
    )

    lots_meta = []
    # Every surveyed diamond gets a crop, even if the modular terrace pass left
    # it sparse — finished-block masters seat into the full pad.
    for i, j in all_blocks():
        doors = door_points_for_block(i, j, district["sprites"])
        x0, y0, w, h = diamond_crop_px(i, j, doors)
        x1, y1 = x0 + w, y0 + h
        layer = lot_layers.get((i, j))
        if layer is None:
            layer = Image.new("RGBA", (PLATE_W, PLATE_H), (0, 0, 0, 0))
        crop = layer.crop((x0, y0, x1, y1))
        name = f"city_sable_lot_{lot_name(i, j)}"
        crop.save(GEN / f"{name}.png", "PNG", compress_level=4)
        crop.save(PROPS / f"{name}.png", "PNG", compress_level=4)
        # Crop bottom-centre in world units (SpriteKit y-up, plate y-down).
        # For a pad-aligned crop this is the camera-near tip of the diamond.
        ground_x = ((x0 + x1) / 2) / PX
        ground_y = WORLD_H - y1 / PX
        iso = ISO_LOTS.get((i, j))
        lots_meta.append({
            "textureName": name,
            "i": i,
            "j": j,
            "isoLot": iso,
            "cropPx": {"x": x0, "y": y0, "w": w, "h": h},
            "groundPoint": {"x": ground_x, "y": ground_y},
            "worldSize": {"w": w / PX, "h": h / PX},
            "anchorY": 0.0,
            "depthSliceWidth": 64 if iso in SOUTH_LOTS else None,
            "depthSortLot": iso if iso in SOUTH_LOTS else None,
            "padWorld": {"w": 2.0 * HALF_W, "h": 2.0 * HALF_H},
            "doorOverhang": len(doors),
        })
        print(
            f"  lot ({i},{j}) {name} crop {w}x{h} "
            f"foot ({ground_x:.1f},{ground_y:.1f}) doors={len(doors)}"
        )

    meta = {
        "pxPerUnit": PX,
        "worldSize": {"w": WORLD_W, "h": WORLD_H},
        "plateSize": {"w": PLATE_W, "h": PLATE_H},
        "groundSource": GROUND_NAME,
        "streetsTexture": "city_sable_row_area_streets_v01",
        "areaTexture": "city_sable_row_area_v01",
        "cropMode": "diamond_aabb",
        "lots": lots_meta,
        "counts": counts,
        "missing": sorted(missing),
    }
    (GEN / "sable_area_bake.json").write_text(json.dumps(meta, indent=2))
    print(
        f"baked area {PLATE_W}x{PLATE_H}  "
        f"architecture={counts['architecture']} furniture={counts['furniture']}  "
        f"lots={len(lots_meta)}"
    )
    if missing:
        print("missing:", ", ".join(sorted(missing)))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

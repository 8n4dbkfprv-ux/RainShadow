#!/usr/bin/env python3
"""Render a city district offline, the way CityDistrictScene composes it.

There is no way to run SpriteKit on the art pipeline's machine, so art changes
to a district used to be unreviewable until someone opened Xcode. This renders
the same scene graph with Pillow — ground plate, then modular sprites
depth-sorted by ground Y — so a plate or facade swap can be judged before it is
installed.

Mirrors, deliberately and literally:

  - `CityDistrictScene.addModularDistrictSprites`: anchor (0.5, anchorY),
    position = groundPoint, uniform `setScale`
  - `BaseGameScene.updateDepth`: sort key `(artHeight - y) * 0.5 + depthBias`
  - `CityDistrictLayout.doorLeaf` / `aperturePoint`: leaves derived from the
    facade's measured aperture rather than hand-placed

    python3 ArtSource/Processing/compose_city_district_preview.py riverside
    python3 ArtSource/Processing/compose_city_district_preview.py riverside \
        --ground <plate.png> --out /tmp/riverside_bgee.png
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass, field
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
AREAS = ROOT / "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2"
PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/CityDistrict/V2"

# CityDistrictDefinition
WORLD_W, WORLD_H = 2048, 1152
STANDING_ADULT_BODY_H = 200.0 / 512.0 * 180.0  # 70.3125
TARGET_DOOR_BODY_MULTIPLE = 1.15
BUILDING_CANVAS = (512, 640)
DOOR_CANVAS = (256, 384)


def door_anchored_scale(leaf_px: float) -> float:
    raw = (TARGET_DOOR_BODY_MULTIPLE * STANDING_ADULT_BODY_H) / leaf_px
    return round(raw * 100) / 100


def facade_anchored_scale(content_h: float, body_multiple: float = 7.0) -> float:
    raw = (body_multiple * STANDING_ADULT_BODY_H) / content_h
    return round(raw * 100) / 100


DOOR_SCALE_STANDARD = door_anchored_scale(275)


@dataclass
class Aperture:
    centre_x: float
    threshold_y: float
    leaf_height: float


@dataclass
class Sprite:
    texture: str
    ground: tuple[float, float]
    scale: float
    anchor_y: float
    depth_bias: float = 0.0
    canvas: tuple[int, int] = field(default=BUILDING_CANVAS)


def aperture_point(ap: Aperture, building: Sprite) -> tuple[float, float]:
    cw, ch = building.canvas
    canvas_bottom_y = building.ground[1] - building.anchor_y * ch * building.scale
    return (
        building.ground[0] + (ap.centre_x - cw / 2) * building.scale,
        canvas_bottom_y + (ch - ap.threshold_y) * building.scale,
    )


def door_leaf(texture: str, building: Sprite, ap: Aperture, ahead: float = 1.0) -> Sprite:
    ground = aperture_point(ap, building)
    bias = building.depth_bias + (ground[1] - building.ground[1]) * 0.5 + ahead
    return Sprite(texture, ground, DOOR_SCALE_STANDARD, 0.0, bias, DOOR_CANVAS)


# --------------------------------------------------------------------------
# Districts. Transcribed from CityDistrictCatalog; keep in step when it moves.
# --------------------------------------------------------------------------

def _bldg(name, xy, leaf, ay, bias=0.0):
    return Sprite(name, xy, door_anchored_scale(leaf), ay, bias)


# Catalog: CityDistrictCatalog (keep in step when it moves).
IRON_STAIRS = _bldg("city_building_iron_stairs", (1184, 552), 128, 0.08)
RIVER_WATCH = _bldg("city_building_river_watch", (544, 648), 100, 0.14)
SR_TENEMENT = _bldg("city_building_tenement", (232, 816), 74, 0.12)
SR_STORE = _bldg("city_building_storefront", (710, 830), 96, 0.12)
SR_ROW = _bldg("city_building_rowhouse", (1225, 820), 120, 0.12)
SR_SHOP = _bldg("city_building_shop", (392, 416), 80, 0.14)
SR_GATE = _bldg("city_building_gatehouse", (824, 392), 120, 0.16)
SR_VOSS = _bldg("city_building_voss_stoop", (1700, 260), 92, 0.10)
WH_SHIP = _bldg("city_building_shipping_office", (1096, 496), 80, 0.10)
WH_WARE = _bldg("city_building_warehouse", (560, 744), 95, 0.10)
WH_BOARD = _bldg("city_building_boarding", (1600, 680), 66, 0.12)
WH_DOCK = _bldg("city_building_dock_shed", (430, 360), 80, 0.16)
PD_ST = _bldg("city_building_pd_station", (1150, 600), 92, 0.10)
PD_AX = _bldg("city_building_pd_annex", (1650, 500), 130, 0.12)
PD_AL = _bldg("city_building_pd_alley", (550, 700), 104, 0.14)
LI_ROOMS = _bldg("city_building_lila_rooms", (1250, 550), 98, 0.10)
LI_NBR = _bldg("city_building_lila_neighbor", (700, 680), 114, 0.12)
LI_OPP = _bldg("city_building_lila_opposite", (1650, 640), 102, 0.12)
LI_ALC = _bldg("city_building_lila_alcove", (950, 350), 115, 0.16, 1)
CR_AX = _bldg("city_building_records_annex", (1200, 590), 84, 0.10)
CR_WING = _bldg("city_building_records_wing", (1650, 490), 88, 0.12)
CR_COL = _bldg("city_building_records_colonnade", (600, 680), 68, 0.12)

DISTRICTS: dict[str, dict] = {
    "riverside": {
        "ground": "city_riverside_ground_v02",
        "sprites": [
            IRON_STAIRS, RIVER_WATCH,
            Sprite("city_building_rail_lamp", (1440, 648), facade_anchored_scale(472), 0.14, 1),
            Sprite("city_building_abutment", (1632, 792), facade_anchored_scale(470), 0.16, 0),
            door_leaf("city_door_iron_stairs", IRON_STAIRS, Aperture(292, 362, 128)),
            door_leaf("city_door_river_watch", RIVER_WATCH, Aperture(325, 440, 100)),
            Sprite("city_prop_lamp", (480, 600), 0.47, 0.12, 1),
            Sprite("city_prop_lamp", (1568, 696), 0.47, 0.12, 1),
        ],
        "obstacles": [(400, 500, 420, 420), (900, 220, 620, 450), (1300, 100, 560, 400), (0, 0, 2048, 110)],
        "actor_start": (1568, 744),
    },
    "sable_row": {
        "ground": "city_sable_row_ground_v02",
        "sprites": [
            SR_TENEMENT, SR_STORE, SR_ROW, SR_SHOP, SR_GATE, SR_VOSS,
            door_leaf("city_door_tenement", SR_TENEMENT, Aperture(275, 482, 74)),
            door_leaf("city_door_storefront", SR_STORE, Aperture(210, 508, 96)),
            door_leaf("city_door_rowhouse", SR_ROW, Aperture(295, 535, 120)),
            door_leaf("city_door_shop", SR_SHOP, Aperture(280, 455, 80)),
            door_leaf("city_door_gatehouse", SR_GATE, Aperture(265, 505, 120)),
            door_leaf("city_door_voss_stoop", SR_VOSS, Aperture(212, 480, 92)),
            door_leaf("city_door_voss_stoop_garage", SR_VOSS, Aperture(375, 520, 75)),
            Sprite("city_prop_lamp", (280, 600), 0.40, 0.12, 1),
            Sprite("city_prop_lamp", (1550, 450), 0.40, 0.12, 1),
        ],
        "obstacles": [(20, 640, 460, 480), (480, 660, 480, 460), (980, 660, 520, 460), (1480, 140, 520, 420)],
        "actor_start": (1600, 90),
    },
    "wharf_ladder": {
        "ground": "city_wharf_ladder_ground_v02",
        "sprites": [
            WH_SHIP, WH_WARE, WH_BOARD, WH_DOCK,
            door_leaf("city_door_shipping_office", WH_SHIP, Aperture(120, 450, 80)),
            door_leaf("city_door_warehouse", WH_WARE, Aperture(135, 535, 95)),
            door_leaf("city_door_boarding", WH_BOARD, Aperture(197, 438, 66)),
            door_leaf("city_door_dock_shed", WH_DOCK, Aperture(140, 460, 80)),
            Sprite("city_prop_lamp", (700, 450), 0.47, 0.12, 1),
            Sprite("city_prop_lamp", (1300, 390), 0.47, 0.12, 1),
        ],
        "obstacles": [(160, 560, 780, 520), (800, 300, 620, 520), (1340, 500, 580, 520)],
        "actor_start": (1912, 440),
    },
    "harborpoint_pd": {
        "ground": "city_harborpoint_pd_ground_v02",
        "sprites": [
            PD_ST, PD_AX, PD_AL,
            Sprite("city_building_pd_plaza_wall", (808, 352), facade_anchored_scale(232), 0.18, 1),
            door_leaf("city_door_pd_station", PD_ST, Aperture(250, 532, 92)),
            door_leaf("city_door_pd_annex", PD_AX, Aperture(166, 542, 130)),
            door_leaf("city_door_pd_alley", PD_AL, Aperture(142, 486, 104)),
            Sprite("city_prop_lamp", (700, 450), 0.47, 0.12, 1),
            Sprite("city_prop_lamp", (1350, 410), 0.47, 0.12, 1),
        ],
        "obstacles": [(780, 360, 820, 680), (1400, 300, 560, 520), (300, 520, 480, 480)],
        "actor_start": (1016, 1080),
    },
    "lila_street": {
        "ground": "city_lila_street_ground_v02",
        "sprites": [
            LI_ROOMS, LI_NBR, LI_OPP, LI_ALC,
            door_leaf("city_door_lila_rooms", LI_ROOMS, Aperture(129, 525, 98)),
            door_leaf("city_door_lila_rooms_b", LI_ROOMS, Aperture(249, 560, 98)),
            door_leaf("city_door_lila_neighbor", LI_NBR, Aperture(203, 570, 114)),
            door_leaf("city_door_lila_opposite", LI_OPP, Aperture(232, 490, 102)),
            door_leaf("city_door_lila_alcove", LI_ALC, Aperture(211, 455, 115)),
            Sprite("city_prop_lamp", (600, 450), 0.47, 0.12, 1),
            Sprite("city_prop_lamp", (1400, 410), 0.47, 0.12, 1),
        ],
        "obstacles": [(450, 500, 520, 520), (960, 360, 620, 560), (1400, 460, 520, 520)],
        "actor_start": (184, 360),
    },
    "civic_records": {
        "ground": "city_civic_records_ground_v02",
        "sprites": [
            CR_AX, CR_WING, CR_COL,
            Sprite("city_building_records_plaza", (850, 350), facade_anchored_scale(284), 0.18, 1),
            door_leaf("city_door_records_annex", CR_AX, Aperture(250, 466, 84)),
            door_leaf("city_door_records_wing", CR_WING, Aperture(145, 500, 88)),
            door_leaf("city_door_records_colonnade", CR_COL, Aperture(250, 440, 68)),
            Sprite("city_prop_lamp", (675, 440), 0.47, 0.12, 1),
            Sprite("city_prop_lamp", (1350, 400), 0.47, 0.12, 1),
        ],
        "obstacles": [(860, 380, 780, 620), (1400, 300, 560, 520), (360, 500, 520, 520)],
        "actor_start": (1024, 140),
    },
}


def depth_key(s: Sprite) -> float:
    """BaseGameScene.updateDepth: nearer the camera draws later."""
    return (WORLD_H - s.ground[1]) * 0.5 + s.depth_bias


def world_to_image(x: float, y: float) -> tuple[float, float]:
    return (x, WORLD_H - y)


def load(texture: str) -> Image.Image | None:
    for base in (PROPS, AREAS):
        p = base / f"{texture}.png"
        if p.exists():
            return Image.open(p).convert("RGBA")
    return None


def compose(
    district: str,
    ground_override: Path | None = None,
    *,
    draw_obstacles: bool = False,
) -> Image.Image:
    spec = DISTRICTS[district]
    ground_path = ground_override or (AREAS / f"{spec['ground']}.png")
    ground = Image.open(ground_path).convert("RGBA")
    if ground.size != (WORLD_W, WORLD_H):
        ground = ground.resize((WORLD_W, WORLD_H), Image.Resampling.LANCZOS)
    canvas = ground

    for s in sorted(spec["sprites"], key=depth_key):
        tex = load(s.texture)
        if tex is None:
            print(f"  missing texture {s.texture}")
            continue
        w = max(1, int(round(tex.width * s.scale)))
        h = max(1, int(round(tex.height * s.scale)))
        sprite = tex.resize((w, h), Image.Resampling.LANCZOS)
        # anchorPoint (0.5, anchor_y): the anchor sits on groundPoint.
        gx, gy = world_to_image(*s.ground)
        left = int(round(gx - w * 0.5))
        top = int(round(gy - (1.0 - s.anchor_y) * h))
        canvas.alpha_composite(sprite, (left, top))

    if draw_obstacles:
        d = ImageDraw.Draw(canvas, "RGBA")
        for x, y, w, h in spec["obstacles"]:
            x0, y0 = world_to_image(x, y + h)
            d.rectangle([x0, y0, x0 + w, y0 + h], outline=(255, 60, 200, 200), width=3)
        ax, ay = world_to_image(*spec["actor_start"])
        d.ellipse([ax - 16, ay - 12, ax + 16, ay + 12], outline=(60, 240, 90, 255), width=3)

    return canvas


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("district", choices=sorted(DISTRICTS))
    ap.add_argument("--ground", type=Path, default=None, help="swap in an alternate ground plate")
    ap.add_argument("--obstacles", action="store_true", help="overlay nav obstacles and spawn")
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    img = compose(args.district, args.ground, draw_obstacles=args.obstacles)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(args.out)
    print(f"wrote {args.out} ({img.width}x{img.height})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

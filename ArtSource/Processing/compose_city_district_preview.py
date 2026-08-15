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

# Catalog: CityDistrictCatalog.riverside (keep in step when it moves).
IRON_STAIRS = Sprite(
    "city_building_iron_stairs", (1184, 552),
    door_anchored_scale(128), 0.08, 0,
)
RIVER_WATCH = Sprite(
    "city_building_river_watch", (544, 648),
    door_anchored_scale(100), 0.14, 0,
)

DISTRICTS: dict[str, dict] = {
    "riverside": {
        "ground": "city_riverside_ground_v02",
        "sprites": [
            IRON_STAIRS,
            RIVER_WATCH,
            Sprite("city_building_rail_lamp", (1440, 648), facade_anchored_scale(472), 0.14, 1),
            Sprite("city_building_abutment", (1632, 792), facade_anchored_scale(470), 0.16, 0),
            door_leaf("city_door_iron_stairs", IRON_STAIRS, Aperture(292, 362, 128)),
            door_leaf("city_door_river_watch", RIVER_WATCH, Aperture(325, 440, 100)),
            Sprite("city_prop_lamp", (480, 600), 0.47, 0.12, 1),
            Sprite("city_prop_lamp", (1568, 696), 0.47, 0.12, 1),
        ],
        "obstacles": [
            (400, 500, 420, 420),
            (900, 220, 620, 450),
            (1300, 100, 560, 400),
            (0, 0, 2048, 110),
        ],
        "actor_start": (1568, 744),
    }
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

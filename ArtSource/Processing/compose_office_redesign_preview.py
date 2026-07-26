"""Offline preview of the four-cluster office layout.

Unlike the older compose scripts, this one imports `office_layout_plan`
directly, so the preview can never drift from the Swift emit. It composites the
shell, partition, floor rug, every prop from `PROPS`, the wall art and the
foreground cutaway at plate resolution, then writes a half-size review PNG.

Usage:
    python3 ArtSource/Processing/compose_office_redesign_preview.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

import office_layout_plan as lp
import office_room_plan as rp

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "RainShadow Shared/Resources/Art/Props/Office"
AREAS = ROOT / "RainShadow Shared/Resources/Art/Areas/DetectiveOffice"
OUT = ROOT / "ArtSource/Generated/Office/review"

ENV = lp.ENV
ANCHOR = (0.5, 0.04)  # matches addDepthProp / addRearFixture in the scene

# Preview factor for the burgundy rug relative to floorDecalDisplayScale; the
# scene must use the same number (see addWornRug).
RUG_ART = "office_worn_rug_burgundy.png"
RUG_FACTOR = 1.45

WALL_ART_SCALE = 0.22 * 0.72 / ENV  # standardPropDisplayScale * 0.72 in plate px


def load(name: str) -> Image.Image:
    return Image.open(ART / name).convert("RGBA")


def content_box(im: Image.Image) -> tuple[int, int, int, int]:
    alpha = np.asarray(im)[:, :, 3]
    ys, xs = np.where(alpha > 16)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def paste_scaled(canvas: Image.Image, im: Image.Image, plate_scale: float, anchor_plate: tuple[float, float]) -> None:
    """Paste `im` so its content anchor (0.5, 0.04 from bottom) lands on `anchor_plate`."""
    x0, y0, x1, y1 = content_box(im)
    content = im.crop((x0, y0, x1, y1))
    w = max(1, int(round(content.width * plate_scale)))
    h = max(1, int(round(content.height * plate_scale)))
    content = content.resize((w, h), Image.Resampling.LANCZOS)
    px = int(round(anchor_plate[0] - w * ANCHOR[0]))
    py = int(round(anchor_plate[1] - h * (1 - ANCHOR[1])))
    canvas.alpha_composite(content, (px, py))


def plate_point(authored: tuple[float, float]) -> tuple[float, float]:
    return (authored[0], rp.ART_H - authored[1])


def main() -> None:
    for prop in lp.PROPS:
        prop.measure()

    canvas = Image.open(AREAS / "office_shell_base.png").convert("RGBA")
    if canvas.size != (rp.ART_W, rp.ART_H):
        canvas = canvas.resize((rp.ART_W, rp.ART_H), Image.Resampling.LANCZOS)

    # Rug first: floor decal under everything.
    rug = load(RUG_ART)
    rug_plate = plate_point(rp.authored(*lp.RUG))
    x0, y0, x1, y1 = content_box(rug)
    content = rug.crop((x0, y0, x1, y1))
    scale = 0.22 * RUG_FACTOR / ENV
    w, h = int(content.width * scale), int(content.height * scale)
    content = content.resize((w, h), Image.Resampling.LANCZOS)
    canvas.alpha_composite(content, (int(rug_plate[0] - w / 2), int(rug_plate[1] - h / 2)))

    # Partition (full plate, painted in place).
    canvas.alpha_composite(load("office_partition_wall.png"))

    # Wall art on the north-west wall face.
    for key, (px, py) in lp.WALL_ART.items():
        art_name = {
            "caseBoard": "office_case_board.png",
            "wallCityMap": "office_wall_city_map.png",
            "wallPhotos": "office_wall_photos.png",
        }[key]
        im = load(art_name)
        bx0, by0, bx1, by1 = content_box(im)
        content = im.crop((bx0, by0, bx1, by1))
        w = max(1, int(content.width * WALL_ART_SCALE))
        h = max(1, int(content.height * WALL_ART_SCALE))
        content = content.resize((w, h), Image.Resampling.LANCZOS)
        canvas.alpha_composite(content, (int(px - w / 2), int(py - h / 2)))

    # Radiator is a rear fixture, then all depth props sorted far-to-near on
    # their plate ground line.
    entries = []
    for prop in lp.PROPS:
        plate = plate_point(prop.authored)
        entries.append((plate[1], prop))
    for _, prop in sorted(entries, key=lambda e: e[0]):
        paste_scaled(
            canvas,
            load(f"{prop.art}.png"),
            prop.display_scale / ENV,
            plate_point(prop.authored),
        )

    # Exterior door leaf and internal door leaf.
    leaf = load("office_door_leaf.png")
    _, ly0, _, ly1 = content_box(leaf)
    leaf_scale = rp.BAKED_DOORWAY_H / (ly1 - ly0)
    paste_scaled(canvas, leaf, leaf_scale, plate_point(rp.authored(*lp.EXTERIOR_DOOR)))
    paste_scaled(
        canvas,
        load("office_internal_door_leaf.png"),
        1.0,
        plate_point(lp.internal_door_leaf_anchor()),
    )

    # Foreground cutaway always nearest.
    canvas.alpha_composite(load("office_foreground_cutaway.png"))

    OUT.mkdir(parents=True, exist_ok=True)
    canvas.save(OUT / "redesign_preview.png")
    canvas.resize((rp.ART_W // 3, rp.ART_H // 3), Image.Resampling.LANCZOS).save(
        OUT / "redesign_preview_third.png"
    )
    print(f"wrote {OUT / 'redesign_preview_third.png'}")


if __name__ == "__main__":
    main()
